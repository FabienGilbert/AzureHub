configuration npsServer
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'NetworkingDsc'    
    Import-DSCResource -ModuleName 'ComputerManagementDsc'    

    Node 'localhost' {
        # Change time zone
        TimeZone EasternTime
        {
            IsSingleInstance = 'Yes'
            TimeZone         = 'Eastern Standard Time'
        }
        # Disable Firewall Profiles
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
        # Install Windows Roles & Features
        WindowsFeature ADManagementTools
        {
            Ensure = "Present"
            Name = "RSAT-AD-Tools"
            IncludeAllSubFeature = $true
        }
        WindowsFeature NPS
        {
            Ensure = "Present"
            Name = "NPAS"
            IncludeAllSubFeature = $true
        }         
        WindowsFeature NPSRSAT
        {
            Ensure = "Present"
            Name = "RSAT-NPAS"            
        }
    }
}