#Upload and compile DSC configurations
#Fabien Gilbert, AIS, 2020-07
#
# Subscription selection
$subList = Get-AzSubscription | Where-Object -Property State -EQ -Value Enabled | Select-Object Name, @{l = "Ordinal"; e = { [regex]::Match($_.Name, "\d{1,}").Value } }, Id | Sort Ordinal
$currentSub = Get-AzContext
$subListwithId = $subList | Select-Object @{l = "Index"; e = { [array]::IndexOf($subList, $_) } }, Name, Id
Write-Output "`r`n"
foreach ($s in $subListwithId) { Write-Output ([string]($s.Index) + " - " + $s.Name) }
Write-Output "`r`n"
$subPrompt = Read-Host -Prompt ("Enter subscription index. Default " + ($subListwithId | Where-Object { $_.Name -eq $currentSub.Subscription.Name }).Index)
if ($subPrompt) {
    $newSub = $subListwithId | Where-Object -Property Index -EQ -Value $subPrompt
    Set-AzContext -SubscriptionName $newSub.Name
}
# Automation account selection
$automationAccounts = Get-AzAutomationAccount
$automationAccountsWithId = $automationAccounts | Select-Object @{l = "Index"; e = { [array]::IndexOf($automationAccounts, $_) } }, AutomationAccountName
Write-Output "`r`n"
foreach ($aua in $automationAccountsWithId) { Write-Output ([string]($aua.Index) + " - " + $aua.AutomationAccountName) }
Write-Output "`r`n"
$subPrompt = Read-Host -Prompt ("Enter subscription index. Default 0")
if (!($subPrompt)) {$subPrompt = 0}
$autoAccount = $automationAccounts | Where-Object -Property AutomationAccountName -EQ -Value ($automationAccountsWithId | Where-Object -Property Index -EQ -Value $subPrompt).AutomationAccountName
if (!($autoAccount)) { Write-Error -Message "Could not get Automation Account"; exit }
#Upload DSC Configs
$currentFolder = Split-Path $script:MyInvocation.MyCommand.Path
$dscConfigFolder = Join-Path -Path $currentFolder -ChildPath "configurations"
$dscConfigFiles = Get-ChildItem -Path $dscConfigFolder -Filter "*.ps1"
Write-Output "Select DSC Configuration to import and compile in the gridview window (may be in the background)"
$dscConfigFilesSelection = $dscConfigFiles | Out-GridView -PassThru
foreach ($dscConfigFile in $dscConfigFilesSelection) {
    Write-Output ("Uploading DSC config " + [char]34 + $dscConfigFile.name + [char]34 + " to Automation Account " + [char]34 + $autoAccount.AutomationAccountName + [char]34 + "...")
    Import-AzAutomationDscConfiguration -ResourceGroupName $autoAccount.ResourceGroupName -AutomationAccountName $autoAccount.AutomationAccountName  -SourcePath $dscConfigFile.FullName -Published -Force
    Write-Output ("Compiling DSC config " + [char]34 + $dscConfigFile.name + [char]34 + " in Automation Account " + [char]34 + $autoAccount.AutomationAccountName + [char]34 + "...")
    $configName = $null; $configName = $dscConfigFile.Name.subString(0, $dscConfigFile.Name.LastIndexOf("."))
    Start-AzAutomationDscCompilationJob -ResourceGroupName $autoAccount.ResourceGroupName -AutomationAccountName $autoAccount.AutomationAccountName -ConfigurationName $configName | Select-Object AutomationAccountName, ConfigurationName, Status
    Get-AzAutomationDscCompilationJob -ResourceGroupName $autoAccount.ResourceGroupName -AutomationAccountName $autoAccount.AutomationAccountName -ConfigurationName $configName | Select-Object AutomationAccountName, ConfigurationName, Status
}