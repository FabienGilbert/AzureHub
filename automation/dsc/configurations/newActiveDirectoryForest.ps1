configuration newActiveDirectoryForest
{
    param
    (
        [Parameter(Mandatory)]
        [string] $keyVaultName,
 
        [Parameter(Mandatory)]
        [string] $usernameSecretName,
 
        [Parameter(Mandatory)]
        [string] $passwordSecretName,
 
        [Parameter(Mandatory)]
        [string] $automationConnectionName
    )
 
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DSCResource -ModuleName StorageDsc    
    Import-DSCResource -ModuleName xActiveDirectory
    Import-DSCResource -ModuleName xDnsServer
 
    $automationConnection = Get-AutomationConnection -Name $automationConnectionName
    Connect-AzAccount -Tenant $automationConnection.TenantID -ApplicationId $automationConnection.ApplicationID -CertificateThumbprint $automationConnection.CertificateThumbprint
 
    $username = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $usernameSecretName).SecretValueText
 
    $password = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $passwordSecretName).SecretValue
 
    $credentials = New-Object System.Management.Automation.PSCredential ($username, $password)
 
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
       
        xADDomain FirstDS 
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
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
            UserName = $DomainJoinUserName
            Password = $DomainJoinPassword
            PasswordNeverExpires = $true
            DomainName = $DomainName
            Path = ("CN=Users,DC=" + $DomainName.replace(".",",DC="))
			DependsOn = '[xDnsServerForwarder]SetForwarders'
        } 
        xADOrganizationalUnit 'ServersOU'
        {
            Name = "Servers"
            Path = ("DC=" + $DomainName.replace(".",",DC="))
            ProtectedFromAccidentalDeletion = $true
            Description = "Servers' OU"
            Ensure = 'Present'
			DependsOn = '[xADDomain]FirstDS'
        } 
        User NonAdminUser
        {
            UserName = $username
            Password = $credentials
        }
        
        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $True
            ConfigurationID = ([guid]::NewGuid()).Guid
        }
    }
}