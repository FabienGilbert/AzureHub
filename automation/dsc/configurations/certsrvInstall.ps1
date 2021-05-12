configuration certsrvInstall
{
    param
    (
        [Parameter(Mandatory)]
        [string] $keyVaultName,
 
        [Parameter(Mandatory)]
        [string] $automationConnectionName,
 
        [Parameter()]
        [string] $windowsFirewallEnabled = 'false'
    )
 
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName xAdcsDeployment
    Import-DscResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName NetworkingDsc 
 
    # Connect to Azure tenant
    $automationConnection = Get-AutomationConnection -Name $automationConnectionName
    Connect-AzAccount -Tenant $automationConnection.TenantID -ApplicationId $automationConnection.ApplicationID -CertificateThumbprint $automationConnection.CertificateThumbprint
  
    Node $AllNodes.NodeName
    {
        # Get secrets from Key vault
        $daSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $Node.daUsername
        $daCredentials = New-Object System.Management.Automation.PSCredential (($Node.DomainName + "\" + $Node.daUsername), $daSecret.SecretValue)
        
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

        # Install AD Certification Authority
        WindowsFeature ADCS-Cert-Authority {
            Ensure = 'Present'
            Name   = 'ADCS-Cert-Authority'
        }

        # Install AD Certification Authority RSAT
        WindowsFeature RSAT-ADCS {
            Ensure               = 'Present'
            Name                 = 'RSAT-ADCS'
            IncludeAllSubFeature = $true
            DependsOn            = '[WindowsFeature]ADCS-Cert-Authority'
        }

        # Configure Certification Authority
        xAdcsCertificationAuthority CertificateAuthority
        {
            Ensure       = 'Present'
            Credential   = $daCredentials
            CAType       = 'EnterpriseRootCA'
            CACommonName = $Node.CACommonName
            DependsOn    = '[WindowsFeature]RSAT-ADCS'
        }

        # Install AD CA Web Enrollment feature
        WindowsFeature ADCS-Web-Enrollment {
            Ensure    = 'Present'
            Name      = 'ADCS-Web-Enrollment'
            DependsOn = '[xAdcsCertificationAuthority]CertificateAuthority'
        }

        # Configure AD CA Web Enrollment feature
        xAdcsWebEnrollment WebEnrollment
        {
            Ensure           = 'Present'
            IsSingleInstance = 'Yes'
            Credential       = $daCredentials
            DependsOn        = '[WindowsFeature]ADCS-Web-Enrollment'
        }
        
        # Install AD CA Online Responder feature
        WindowsFeature ADCS-Online-Cert {
            Ensure    = 'Present'
            Name      = 'ADCS-Online-Cert'
            DependsOn = '[xAdcsWebEnrollment]WebEnrollment'
        }

        # Configure AD CA Online Responder feature
        xAdcsOnlineResponder OnlineResponder
        {
            Ensure           = 'Present'
            IsSingleInstance = 'Yes'
            Credential       = $daCredentials
            DependsOn        = '[WindowsFeature]ADCS-Online-Cert'
        }

        # Install IIS Management Tools
        WindowsFeature Web-Mgmt-Console {
            Ensure    = 'Present'
            Name      = 'Web-Mgmt-Console'
            DependsOn = '[xAdcsOnlineResponder]OnlineResponder'
        }
        WindowsFeature Web-Mgmt-Service {
            Ensure    = 'Present'
            Name      = 'Web-Mgmt-Service'
            DependsOn = '[WindowsFeature]Web-Mgmt-Console'
        }
        
        # Enable double escaping for delta CRL
        xWebConfigProperty EnableDoubleEscaping
        {
            WebsitePath  = 'IIS:\Sites\Default Web Site'
            Filter       = 'system.webServer/security/requestFiltering'
            PropertyName = 'allowDoubleEscaping'
            Value        = 'True'
            Ensure       = 'Present'
            DependsOn    = '[WindowsFeature]Web-Mgmt-Service'
        }

        # Create CRL folder
        File CRL
        {
            Ensure          = 'Present'
            Type            = 'Directory'
            DestinationPath = 'C:\inetpub\wwwroot\crl'
            DependsOn       = '[xWebConfigProperty]EnableDoubleEscaping'
        }

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $True
            ConfigurationID = ([guid]::NewGuid()).Guid
        }
    }
}