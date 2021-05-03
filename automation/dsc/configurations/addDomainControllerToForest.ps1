configuration addDomainControllerToForest
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
       
        # Promote server to additional Domain Controller of existing domain  
        xADDomainController SecondDS
        {
            DomainName = $Node.DomainName
            DomainAdministratorCredential = $daCredentials
            SafeModeAdministratorPassword = $daCredentials
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
			DependsOn = '[xADDomainController]SecondDS'
        }

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $True
            ConfigurationID = ([guid]::NewGuid()).Guid
        }
    }
}