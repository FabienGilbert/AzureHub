configuration newActiveDirectoryForest
{
    param
    (
        [Parameter(Mandatory)]
        [string] $keyVaultName,
 
        [Parameter(Mandatory)]
        [string] $DnsForwarder,
 
        [Parameter(Mandatory)]
        [string] $automationConnectionName
    )
 
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DSCResource -ModuleName StorageDsc    
    Import-DSCResource -ModuleName xActiveDirectory
    Import-DSCResource -ModuleName xDnsServer
 
    $automationConnection = Get-AutomationConnection -Name $automationConnectionName
    Connect-AzAccount -Tenant $automationConnection.TenantID -ApplicationId $automationConnection.ApplicationID -CertificateThumbprint $automationConnection.CertificateThumbprint
  
    Node $AllNodes.NodeName
    {
        WaitForDisk Disk2
        {
            DiskId           = 2
            RetryIntervalSec = 60
            RetryCount       = 60
        } 

        Disk FVolume
        {
            DiskId      = 2
            DriveLetter = 'F'
            FSLabel     = 'Data'
            DependsOn   = '[WaitForDisk]Disk2'
        }
        
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
        
        $daSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $Node.daUsername
        $daCredentials = New-Object System.Management.Automation.PSCredential (($Node.DomainName + "\" + $Node.daUsername), $daSecret.SecretValue)
        $djSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $Node.djUsername
        $djCredentials = New-Object System.Management.Automation.PSCredential (($Node.DomainName + "\" + $Node.djUsername), $djSecret.SecretValue)
       
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
        xDnsServerForwarder 'SetForwarders'
        {
            IsSingleInstance = 'Yes'
            IPAddresses      = $DnsForwarder
            UseRootHint      = $false
			DependsOn = '[xADDomain]FirstDS'
        }
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
        xADOrganizationalUnit 'ServersOU'
        {
            Name = "Servers"
            Path = ("DC=" + $Node.DomainName.replace(".",",DC="))
            ProtectedFromAccidentalDeletion = $true
            Description = "Servers' OU"
            Ensure = 'Present'
			DependsOn = '[xADDomain]FirstDS'
        } 
        
        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $True
            ConfigurationID = ([guid]::NewGuid()).Guid
        }
    }
}