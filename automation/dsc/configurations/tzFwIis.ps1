Configuration tzFwIis
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DSCResource -ModuleName 'ComputerManagementDsc'
    Import-DscResource -ModuleName 'NetworkingDsc'

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

        #Install IIS
        WindowsFeature IIS {
            Ensure               = "Present"
            Name                 = "Web-Server"
            IncludeAllSubFeature = $true
        }

        WindowsFeature IISManagementTools
        {
            Ensure               = "Present"
            Name                 = "Web-Mgmt-Tools"
            IncludeAllSubFeature = $true 
            DependsOn            = '[WindowsFeature]IIS'
        }

        WindowsFeature IISMGMT {
            Ensure    = "Present"
            Name      = "Web-Mgmt-Service"
            DependsOn = '[WindowsFeature]IIS'
        }
    }
}