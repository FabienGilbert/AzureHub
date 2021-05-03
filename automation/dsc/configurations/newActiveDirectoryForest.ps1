configuration newActiveDirectoryForest
{
    param
    (
        [Parameter(Mandatory)]
        [string] $keyVaultName,
 
        [Parameter(Mandatory)]
        [string] $DnsForwarder,
 
        [Parameter(Mandatory)]
        [string] $automationConnectionName,
 
        [Parameter()]
        [string] $windowsFirewallEnabled = 'false'
    )
 
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DSCResource -ModuleName StorageDsc    
    Import-DSCResource -ModuleName xActiveDirectory
    Import-DSCResource -ModuleName xDnsServer
    Import-DscResource -ModuleName NetworkingDsc 
    Import-DSCResource -ModuleName ComputerManagementDsc  
 
    # Connect to Azure tenant
    $automationConnection = Get-AutomationConnection -Name $automationConnectionName
    Connect-AzAccount -Tenant $automationConnection.TenantID -ApplicationId $automationConnection.ApplicationID -CertificateThumbprint $automationConnection.CertificateThumbprint
  
    Node $AllNodes.NodeName
    {
        # Wait for data disk
        WaitForDisk Disk2
        {
            DiskId           = 2
            RetryIntervalSec = 60
            RetryCount       = 60
        } 

        # Initialize and format data disk
        Disk FVolume
        {
            DiskId      = 2
            DriveLetter = 'F'
            FSLabel     = 'Data'
            DependsOn   = '[WaitForDisk]Disk2'
        }
        
        # Install Windows Features
        WindowsFeature DNS 
        { 
            Ensure = "Present" 
            Name = "DNS"            
            DependsOn   = '[Disk]FVolume'
        }

        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
			DependsOn = '[WindowsFeature]DNS'
        }

        WindowsFeature RSATDNSServer 
        { 
            Ensure = "Present" 
            Name = "RSAT-DNS-Server"
			DependsOn = '[WindowsFeature]ADDSInstall'
        }
        
        WindowsFeature RSATADTools
        { 
            Ensure = "Present" 
            Name = "RSAT-AD-Tools"
            IncludeAllSubFeature = $true
			DependsOn = '[WindowsFeature]RSATDNSServer'
        }  
        WindowsFeature GPMC 
        { 
            Ensure = "Present" 
            Name = "GPMC"
			DependsOn = '[WindowsFeature]RSATADTools'
        }
        
        # Change time zone
        TimeZone EasternTime
        {
            IsSingleInstance = 'Yes'
            TimeZone         = 'Eastern Standard Time'
        }

        # Configure Windows Firewall Profiles
        FirewallProfile FirewallProfileDomain
        {
            Name = 'Domain'
            Enabled = $windowsFirewallEnabled
        }
        FirewallProfile FirewallProfilePrivate
        {
            Name = 'Private'
            Enabled = $windowsFirewallEnabled
        }
        FirewallProfile FirewallProfilePublic
        {
            Name = 'Public'
            Enabled = $windowsFirewallEnabled
        }

        # Get secrets from Key vault
        $daSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $Node.daUsername
        $daCredentials = New-Object System.Management.Automation.PSCredential (($Node.DomainName + "\" + $Node.daUsername), $daSecret.SecretValue)
        $djSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $Node.djUsername
        $djCredentials = New-Object System.Management.Automation.PSCredential (($Node.DomainName + "\" + $Node.djUsername), $djSecret.SecretValue)
       
        # Create AD Forest
        xADDomain FirstDS 
        {
            DomainName = $Node.DomainName
            DomainAdministratorCredential = $daCredentials
            SafemodeAdministratorPassword = $daCredentials
            DatabasePath = "F:\NTDS"
            LogPath = "F:\NTDS"
            SysvolPath = "F:\SYSVOL"
			DependsOn = '[WindowsFeature]GPMC'
        }

        # Configure DNS Forwarders
        xDnsServerForwarder 'SetForwarders'
        {
            IsSingleInstance = 'Yes'
            IPAddresses      = $DnsForwarder
            UseRootHint      = $false
			DependsOn = '[xADDomain]FirstDS'
        }

        # Create Domain join user
        xADUser 'domainJoinUser'
        {
            Ensure = 'Present'
            UserName = $Node.djUsername
            Password = $djCredentials
            PasswordNeverExpires = $true
            DomainName = $Node.DomainName
            Path = ("CN=Users,DC=" + $Node.DomainName.replace(".",",DC="))
			DependsOn = '[xDnsServerForwarder]SetForwarders'
        } 

        # Create Servers OU
        xADOrganizationalUnit 'ServersOU'
        {
            Name = "Servers"
            Path = ("DC=" + $Node.DomainName.replace(".",",DC="))
            ProtectedFromAccidentalDeletion = $true
            Description = "Servers' OU"
            Ensure = 'Present'
			DependsOn = '[xADDomain]FirstDS'
        } 
        
        # Create internal public DNS zone
        xDnsServerADZone 'AddForwardADZone'
        {
            Name             = $Node.PublicDomainName
            DynamicUpdate    = 'Secure'
            ReplicationScope = 'Forest'
            Ensure           = 'Present'
			DependsOn        = '[xDnsServerForwarder]SetForwarders'
        }

        # Create A DNS Host records
        xDnsRecord 'AddStsArecord'
        {
            Name   = $Node.StsRecordName
            Target = $Node.StsRecordAddress
            Zone   = $Node.PublicDomainName
            Type   = 'ARecord'
            Ensure = 'Present'
			DependsOn   = '[xDnsServerADZone]AddForwardADZone'
        }
        xDnsRecord 'AddCaArecord'
        {
            Name   = $Node.CaRecordName
            Target = $Node.CaRecordAddress
            Zone   = $Node.PublicDomainName
            Type   = 'ARecord'
            Ensure = 'Present'
			DependsOn   = '[xDnsServerADZone]AddForwardADZone'
        }

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $True
            ConfigurationID = ([guid]::NewGuid()).Guid
        }
    }
}