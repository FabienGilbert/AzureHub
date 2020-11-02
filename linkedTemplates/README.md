This folder contains ARM templates meant to be used as linked templates within the main scaffolding and VM deployment ARM templates.

File                                    | Description
---                                     | ---
keyVault_armTemplate.json               | ARM template to deploy Azure Key Vaults complete with access policy, firewall and diagnostic logs configuration.
logAnalyticsWorkspace_armTemplate.json  | ARM template to deploy Azure Log Analytics Workspaces with advanced settings to collect Windows and Linux logs.
recVault_armTemplate.json               | ARM template to deploy Azure Recovery Vaults with diagnostic logs configuration.
storageAccount_armTemplate.json         | ARM template to deploy Azure Storage Accounts complete with firewall configuration.
nsg_armTemplate.json                    | ARM template to deploy Azure Network Security Groups with security rules and diagnostic logs configuration.
udr_armTemplate.json                    | ARM template to deploy Azure User Defined Routes.
vnetPeering_armTemplate.json            | ARM template to deploy Azure Virtual Network Peerings.
vm_armTemplate.json                     | ARM template to deploy Azure Virtual Machines with custom configurations.
vmAutomationExtWindows_armTemplate.json | ARM template to deploy the Azure Automation Virtual Machine extension and connect it to the designated Automation account.
vmDiskEncryption_armTemplate.json       | ARM template to deploy the Azure Disk Encryption Virtual Machine extension using bek or kek.
vmDomainJoin_armTemplate.json           | ARM template to deploy the Azure Domain Join Virtual Machine extension and join it to the designated Active Directory domain.
vmLogAnalyticsAgent_armTemplate.json    | ARM template to deploy the Azure Log Analytics Virtual Machine extension and join it to the designated Log Analytics Workspace.
vmNetworkWatcher_armTemplate.json       | ARM template to deploy the Azure Network Watcher Virtual Machine extension and join it to the designated Log Analytics Workspace.
vnet_armTemplate.json                   | ARM template to deploy Azure Virtual Networks with subnets and diagnostic logs configuration.