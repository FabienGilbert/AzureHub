# Temporarily allow RDP from current public IP to a specific host
# Fabien Gilbert, AIS, 12/2020
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
# NIC selection
$subNics = Get-AzNetworkInterface
$automationAccounts = Get-AzAutomationAccount
$automationAccountsWithId = $automationAccounts | Select-Object @{l = "Index"; e = { [array]::IndexOf($automationAccounts, $_) } }, AutomationAccountName
Write-Output "`r`n"
foreach ($aua in $automationAccountsWithId) { Write-Output ([string]($aua.Index) + " - " + $aua.AutomationAccountName) }
Write-Output "`r`n"
$subPrompt = Read-Host -Prompt ("Enter automation account index. Default 0")
if (!($subPrompt)) {$subPrompt = 0}
$autoAccount = $automationAccounts | Where-Object -Property AutomationAccountName -EQ -Value ($automationAccountsWithId | Where-Object -Property Index -EQ -Value $subPrompt).AutomationAccountName
if (!($autoAccount)) { Write-Error -Message "Could not get Automation Account"; exit }

$networkRg = ""
$nicRg = ""
$nicName = ""
$nsgRg = ""
$nsgName = ""
$ipName = ""
$pip = $null
$nic = $null
$nsg = $null
$secRule = $null
$revertprompt = $null
#get public IP
$ipInfoJson = Invoke-WebRequest -Uri http://ipinfo.io/json
$ipInfo = $ipInfoJson.Content | ConvertFrom-Json
#get IP
$pip = Get-AzPublicIpAddress -ResourceGroupName $networkRg -Name $ipName
if(!($pip)){Write-Error -Message ("Could not get Public IP Address  " + [char]34 + $pip + [char]34 + ". Aborting.");exit}
#get NIC
$nic = Get-AzNetworkInterface -ResourceGroupName $nicRg -Name $nicName
if(!($nic)){Write-Error -Message ("Could not get NIC " + [char]34 + $nicName + [char]34 + ". Aborting.");exit}
if($nic.IpConfigurations[0].PublicIpAddress.Id -ne $pip.Id){
    Write-Output ("Setting Public IP name " + [char]34 + $pip.Name + [char]34 + " FQDN " + [char]34 + $pip.DnsSettings.Fqdn + [char]34 + " on NIC " + [char]34 + $nic.Name + [char]34 + "...")
    Set-AzNetworkInterfaceIpConfig -NetworkInterface $nic -PublicIpAddress $pip -Name $nic.IpConfigurations[0].Name
    Set-AzNetworkInterface -NetworkInterface $nic
}
#get NSG
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $nsgRg -Name $nsgName
if(!($nsg)){Write-Error -Message ("Could not get NSG " + [char]34 + $nsgName + [char]34 + ". Aborting.");exit}
#build security rules
$secRule = New-AzNetworkSecurityRuleConfig -Access "Allow" `
                                           -Direction "inbound" `
                                           -Priority 190 `
                                           -Name "AllowInBoundRDPfromInternet" `
                                           -Description ("Allow temporary InBound RDP from " + $ipInfo.ip + ". Created on " + (Get-Date -UFormat %Y-%m-%d) + " at " + (Get-Date -UFormat %H:%M) + ".") `
                                           -Protocol "tcp" `
                                           -SourceAddressPrefix $ipInfo.ip `
                                           -DestinationAddressPrefix $nic.IpConfigurations[0].PrivateIpAddress `
                                           -SourcePortRange "*" `
                                           -DestinationPortRange "3389"
if(!($nsg.SecurityRules | Where-Object {$_.DestinationPortRange -eq $secrule.destinationPortRange -and $_.Priority -eq $secrule.Priority -and $_.SourceAddressPrefix -eq $ipInfo.ip})){
    Write-Output ("Adding Security Rule below to NSG " + [char]34 + $nsgName + [char]34 + "...")
    $secRule
    $nsg.SecurityRules += $secRule
    $nsgSave = $nsg | Set-AzNetworkSecurityGroup
    Write-Output ("Security Rule addition completed with status " + $nsgSave.ProvisioningState + ".")
}
Write-Output ("`r`n" + $ipInfo.ip + " should now be able to RDP into " + [char]34 + $pip.DnsSettings.Fqdn + [char]34 + ".")
do{
    $revertprompt = Read-Host -Prompt "`r`nEnter Y when ready to revert or N to keep as is and exit"
}until($revertprompt -eq "Y" -or $revertprompt -eq "N")
if($revertprompt -eq "N"){exit}
#Revert configuration
#get NSG
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $nsgRg -Name $nsgName
if(!($nsg)){Write-Error -Message ("Could not get NSG " + [char]34 + $nsgName + [char]34 + ". Aborting.");exit}
Write-Output ("Removing Security Rule from NSG " + [char]34 + $nsgName + [char]34 + "...")
$nsg.SecurityRules = $nsg.SecurityRules | Where-Object {!($_.DestinationPortRange -eq $secrule.destinationPortRange -and $_.Priority -eq $secrule.Priority -and $_.SourceAddressPrefix -eq $ipInfo.ip)}
$nsgSave = $nsg | Set-AzNetworkSecurityGroup
#get NIC
$nic = Get-AzNetworkInterface -ResourceGroupName $nicRg -Name $nicName
if(!($nic)){Write-Error -Message ("Could not get NIC " + [char]34 + $nicName + [char]34 + ". Aborting.");exit}
Write-Output ("Removing Public IP name " + [char]34 + $pip.Name + [char]34 + " from NIC " + [char]34 + $nic.Name + [char]34 + "...")
$nic.IpConfigurations[0].PublicIpAddress = $null
Set-AzNetworkInterface -NetworkInterface $nic