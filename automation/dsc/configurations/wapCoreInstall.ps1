configuration wapCoreInstall
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'ComputerManagementDsc'
    Import-DscResource -ModuleName 'NetworkingDsc'
    Import-DscResource -ModuleName 'xWebAdministration'

    Node 'localhost' {
        #Change time zone
        TimeZone EasternTime
        {
            IsSingleInstance = 'Yes'
            TimeZone         = 'Eastern Standard Time'
        }
        #Disable Firewall Profiles
        FirewallProfile FirewallProfileDomain
        {
            Name = 'Domain'
            Enabled = 'False'
        }
        FirewallProfile FirewallProfilePrivate
        {
            Name = 'Private'
            Enabled = 'False'
        }
        FirewallProfile FirewallProfilePublic
        {
            Name = 'Public'
            Enabled = 'False'
        }
        #Install Windows Roles and Features
        WindowsFeature WAP {
            Ensure = "Present"
            Name = "Web-Application-Proxy"
        }
        WindowsFeature WebServer {
            Ensure = "Present"
            Name = "Web-Server"
			DependsOn = '[WindowsFeature]WAP'
        }
        WindowsFeature WebMgmtService {
            Ensure = "Present"
            Name = "Web-Mgmt-Service"
			DependsOn = '[WindowsFeature]WebServer'
        }
        # Enable IIS double escaping for delta CRL
        xWebConfigProperty EnableDoubleEscaping
        {
            WebsitePath  = 'IIS:\Sites\Default Web Site'
            Filter       = 'system.webServer/security/requestFiltering'
            PropertyName = 'allowDoubleEscaping'
            Value        = 'True'
            Ensure       = 'Present'
            DependsOn    = '[WindowsFeature]WebMgmtService'
        }
        
    }
}