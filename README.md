# Azure HUB Scaffolding

This repository contains ARM templates and PowerShell scripts to deploy the hub scaffolding and resources of a standard Azure Hub and Spoke topology.

# High level steps

## Azure DevOps Service Connections

Establish Azure DevOps Service Connections to the desired Azure Subscription(s). This can be done two ways:

- Use the "Service principal (automatic)" option which will ask you to authenticate to your Azure tenant and automatically create a service principal there.

OR

- For more control, create the service connections manually:
    1. Create the Azure App Registration and Service Principal using script [newAppRegistration.ps1](/AzureAD/appRegistrations/newAppRegistration.ps1).
    2. Create desired RBAC assignments for the Service Principal.
    3. Create the DevOps service connection using the "Service principal (manual)" option. You will need the App Key created in #1.

## Scaffolding

This step will create all of the scaffolding including Resource Groups, VNET...