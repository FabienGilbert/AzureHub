Configuration tzFwAddsCa
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
        #Install Windows Roles and Features
        WindowsFeature ActiveDirectory {
            Ensure = "Present"
            Name = "AD-Domain-Services" 
        }
        WindowsFeature ADManagementTools
        {
            Ensure = "Present"
            Name = "RSAT-AD-Tools"
            IncludeAllSubFeature = $true
        }
        WindowsFeature DNSManagementTools
        {
            Ensure = "Present"
            Name = "RSAT-DNS-Server"
        }        
        WindowsFeature CA {
            Ensure = "Present"
            Name = "ADCS-Cert-Authority" 
        }
        WindowsFeature CAWeb {
            Ensure = "Present"
            Name = "ADCS-Web-Enrollment" 
        }
        WindowsFeature CAOCSP {
            Ensure = "Present"
            Name = "ADCS-Online-Cert" 
        }
        WindowsFeature IISMGMT {
            Ensure = "Present"
            Name = "Web-Mgmt-Service" 
        }     
    }
}