Configuration tzFwMgmt
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'NetworkingDsc'    
    Import-DSCResource -ModuleName 'ComputerManagementDsc'    
    Import-DscResource -ModuleName 'PackageManagement' -ModuleVersion 1.4.7

    Node 'localhost' {
        # Install PowerShell Az Module
        PackageManagementSource SourceRepository
        {
            Ensure      = "Present"
            Name        = "MyNuget"
            ProviderName= "Nuget"
            SourceLocation   = "http://nuget.org/api/v2/"
            InstallationPolicy ="Trusted"
        }    
        PackageManagementSource PSGallery
        {
            Ensure      = "Present"
            Name        = "psgallery"
            ProviderName= "PowerShellGet"
            SourceLocation   = "https://www.powershellgallery.com/api/v2"
            InstallationPolicy ="Trusted"
        }
        PackageManagement PsAzAccountModule
        {
            Ensure    = "Present"
            Name      = "Az.Accounts"
            Source    = "PSGallery"
            DependsOn = "[PackageManagementSource]PSGallery"
        }
        PackageManagement PsAzAutoModule
        {
            Ensure    = "Present"
            Name      = "Az.Automation"
            Source    = "PSGallery"
            DependsOn = "[PackageManagementSource]PSGallery"
        }
        PackageManagement PsAzComputeModule
        {
            Ensure    = "Present"
            Name      = "Az.Compute"
            Source    = "PSGallery"
            DependsOn = "[PackageManagementSource]PSGallery"
        }
        PackageManagement PsAzKeyVaultModule
        {
            Ensure    = "Present"
            Name      = "Az.KeyVault"
            Source    = "PSGallery"
            DependsOn = "[PackageManagementSource]PSGallery"
        }   
        PackageManagement PsAzNetworkModule
        {
            Ensure    = "Present"
            Name      = "Az.Network"
            Source    = "PSGallery"
            DependsOn = "[PackageManagementSource]PSGallery"
        }
        PackageManagement PsAzResourceModule
        {
            Ensure    = "Present"
            Name      = "Az.Resources"
            Source    = "PSGallery"
            DependsOn = "[PackageManagementSource]PSGallery"
        }
        PackageManagement PsAzStorageModule
        {
            Ensure    = "Present"
            Name      = "Az.Storage"
            Source    = "PSGallery"
            DependsOn = "[PackageManagementSource]PSGallery"
        }
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
        WindowsFeature DOTNET {
            Ensure = "Present"
            Name = "NET-Framework-Core" 
        }
        WindowsFeature GPManagementTools
        {
            Ensure = "Present"
            Name = "GPMC"            
        }
        WindowsFeature ADManagementTools
        {
            Ensure = "Present"
            Name = "RSAT-AD-Tools"
            IncludeAllSubFeature = $true
        }
        WindowsFeature CSManagementTools
        {
            Ensure = "Present"
            Name = "RSAT-ADCS"
            IncludeAllSubFeature = $true
        }         
        WindowsFeature RDGManagementTools
        {
            Ensure = "Present"
            Name = "RSAT-RDS-Gateway"            
        }
        WindowsFeature DNSManagementTools
        {
            Ensure = "Present"
            Name = "RSAT-DNS-Server"            
        }
        WindowsFeature IISManagementTools
        {
            Ensure = "Present"
            Name = "Web-Mgmt-Tools"
            IncludeAllSubFeature = $true           
        }
    }
}