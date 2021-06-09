Param
(
    # ConfigFilePath
    [Parameter(Position = 0,
        HelpMessage = "Path to the DSC configuration file",
        Mandatory = $true)]
    [ValidateScript( { Test-Path $_ })]
    $ConfigFilePath,

    # ParamFilePath
    [Parameter(Position = 1,
        HelpMessage = "Path to the compilation parameters JSON file",
        Mandatory = $true)]
    [ValidateScript( { Test-Path $_ })]
    $ParamFilePath,

    # ForceImportConfig
    [Parameter(Position = 2,
        HelpMessage = "Allways import config, even if existing",
        Mandatory = $false)]
    $ForceImportConfig = $false
)

# Import DSC config file
Write-Output ("Importing compilation parameters JSON file path " + [char]34 + $ParamFilePath + [char]34 + "...")
$dscParams = Get-Content -Path $ParamFilePath | ConvertFrom-Json
if (!($dscParams)) { Write-Error -Message ("Could not import compilation parameters JSON file " + [char]34 + $ParamFilePath + [char]34 + "."); exit }
# Check Az connection
$azTenant = Get-AzTenant
if (!($azTenant)) { Write-Error -Message "Could not get Azure AD Tenant. Check Az module and connection to Azure."; exit }
# Set subscription context
if ((Get-AzContext).Subscription.Id -ne $dscParams.automationAccountSubscriptionId) {
    Write-Output ("Changing context to subscription id " + $dscParams.automationAccountSubscriptionId + "...")
    Set-AzContext -SubscriptionId $dscParams.automationAccountSubscriptionId
}
# Get automation account
Write-Output ("Getting Automation Account name " + [char]34 + $dscParams.automationAccountName + [char]34 + " resource group " + [char]34 + $dscParams.automationAccountResourceGroupName + [char]34 + "...")
$autoAccount = Get-AzAutomationAccount -ResourceGroupName $dscParams.automationAccountResourceGroupName -Name $dscParams.automationAccountName
if (!($autoAccount)) { Write-Error -Message ("Could not get Automation Account name " + [char]34 + $dscParams.automationAccountName + [char]34 + " resource group " + [char]34 + $dscParams.automationAccountResourceGroupName + [char]34 + "."); exit }
# Get automation account connection
Write-Output ("Getting Automation Account Connection name " + [char]34 + $dscParams.automationConnectionName + [char]34 + "...")
$autoCon = Get-AzAutomationConnection -ResourceGroupName $autoAccount.ResourceGroupName -AutomationAccountName $autoAccount.AutomationAccountName -Name $dscParams.automationConnectionName
if (!($autoCon)) { Write-Error -Message ("Could not get Automation Account Connection name " + [char]34 + $dscParams.automationConnectionName + [char]34 + "."); exit }
# Open .ps1 file to get Configuration Name
$stateConfFile = Get-Content -Path $ConfigFilePath
$configName = $stateConfFile[0].Replace("configuration ", "")
# Import State Configuration to Automation Account
Write-Output ("Check for existing state configuration name " + [char]34 + $configName + [char]34 + "...")
$stateConf = Get-AzAutomationDscConfiguration -ResourceGroupName $autoAccount.ResourceGroupName -AutomationAccountName $autoAccount.AutomationAccountName -Name $configName -ErrorAction:SilentlyContinue
if ($stateConf) { Write-Output (" `tfound existing config last modified on " + $stateConf.LastModifiedTime + "."); $importConf = $ForceImportConfig }
else { Write-Output " `tconfig does not yet exist"; $importConf = $true }
if($importConf){
    Write-Output ("Importing state configuration name " + [char]34 + $configName + [char]34 + " path " + [char]34 + $ConfigFilePath + [char]34 + " to automation account...")
    $stateConf = Import-AzAutomationDscConfiguration -ResourceGroupName $autoAccount.ResourceGroupName -AutomationAccountName $autoAccount.AutomationAccountName  -SourcePath $ConfigFilePath -Published -Force
    if ($stateConf.Name -eq $configName) { Write-Output ("`tImport completed with state: " + $stateConf.State) }
    else { Write-Error -Message ("Import of state configuration " + [char]34 + $ConfigFilePath + [char]34 + " completed with status: " + $stateConf.State); exit }
}
###############################
# Compile State Configuration #
###############################
#
# Build basic compilation command (without parameters or config data)
$compileCmd = ("Start-AzAutomationDscCompilationJob -ResourceGroupName " + [char]36 + "autoAccount.ResourceGroupName -AutomationAccountName " + [char]36 + "autoAccount.AutomationAccountName -ConfigurationName " + [char]36 + "configName")
# Add parameters if specified in the parameter file
if($dscParams.parameters){
    $paramHash = @{}
    foreach($dscParam in $dscParams.parameters){
        $paramHash.Add($dscParam.name, $dscParam.value)
    }
    $compileCmd += (" -Parameters " + [char]36 + "paramHash")
}
# Add configuration data if specified in the parameter file
if($dscParams.configurationData){
    $AllNodesHash = @{"AllNodes"=@()}
    foreach($nodeData in $dscParams.configurationData){
        $nodeDataHash = @{}
        foreach($nodeConfigData in $nodeData){
            $nodeDataHash.Add($nodeConfigData.name, $nodeConfigData.value)
        }
        $AllNodesHash.AllNodes += $nodeDataHash
    }
    $compileCmd += (" -ConfigurationData " + [char]36 + "AllNodesHash")
}
Write-Output ("`r`nStarting configuration compilation with cmdlet: " + $compileCmd)
$configCompile = Invoke-Expression -Command $compileCmd
$getCompileStatusCmdlet = ("Get-AzAutomationDscCompilationJob -ResourceGroupName " + $autoAccount.ResourceGroupName + " -AutomationAccountName " + $autoAccount.AutomationAccountName + " -ConfigurationName " + $configName + " | Select-Object Id, CreationTime, Status")
$getCompileStatusCmdlet | Set-Clipboard
Write-Output ("`tcompilation started with status: " + $configCompile.Status + ". Use command below to check status. `r`n`r`n" + $getCompileStatusCmdlet)