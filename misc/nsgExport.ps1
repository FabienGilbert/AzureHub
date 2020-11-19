# Export existing Network Security Groups and their Security Rules to JSON files
# Useful when NSGs get created through Blueprint, and then changes need to be made to them later on
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
$currentFolder = Split-Path $script:MyInvocation.MyCommand.Path
# Get all NSGs in subcription
$networkSecurityGroups = Get-AzNetworkSecurityGroup
# Loop through NSGs and build hash
foreach ($networkSecurityGroup in $networkSecurityGroups) {
    $nsgHash = [ordered]@{
        ([char]36 + "schema") = "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
        "parameters"          = [ordered]@{
            "deploymentResourceGroup"  = @{"value" = $networkSecurityGroup.ResourceGroupName }
            "networkSecurityGroupName" = @{"value" = $networkSecurityGroup.Name }
            "tags"                     = @{"value" = $networkSecurityGroup.Tag }
            "securityRules"            = @{"value" = @() }
        }
    }
    foreach ($securityRule in $networkSecurityGroup.SecurityRules) {
        $secRuleHash = [ordered]@{
            "Direction"                  = $securityRule.Direction
            "Priority"                   = $securityRule.Priority
            "Name"                       = $securityRule.Name
            "Description"                = $securityRule.Description
            "Access"                     = $securityRule.Access
            "Protocol"                   = $securityRule.Protocol            
            "SourceAddressPrefix"        = ""
            "SourceAddressPrefixes"      = @()
            "DestinationAddressPrefix"   = ""
            "DestinationAddressPrefixes" = @()
            "SourcePortRange"            = ""
            "SourcePortRanges"           = @()
            "DestinationPortRange"       = ""
            "DestinationPortRanges"      = @()
        }
        if (@($securityRule.SourceAddressPrefix).Count -gt 1) {
            $secRuleHash.SourceAddressPrefixes = $securityRule.SourceAddressPrefix
        }
        else { $secRuleHash.SourceAddressPrefix = $securityRule.SourceAddressPrefix[0] }        
        if (@($securityRule.DestinationAddressPrefix).Count -gt 1) {
            $secRuleHash.DestinationAddressPrefixes = $securityRule.DestinationAddressPrefix
        }
        else { $secRuleHash.DestinationAddressPrefix = $securityRule.DestinationAddressPrefix[0] }       
        if (@($securityRule.SourcePortRange).Count -gt 1) {
            $secRuleHash.SourcePortRanges = $securityRule.SourcePortRange
        }
        else { $secRuleHash.SourcePortRange = $securityRule.SourcePortRange[0] }      
        if (@($securityRule.DestinationPortRange).Count -gt 1) {
            $secRuleHash.DestinationPortRanges = $securityRule.DestinationPortRange
        }
        else { $secRuleHash.DestinationPortRange = $securityRule.DestinationPortRange[0] }
        $nsgHash.parameters.securityRules.value += $secRuleHash        
    }
    $nsgFilePath = Join-Path -Path $currentFolder -ChildPath ((Get-AzContext).Subscription.Name + "\" + $networkSecurityGroup.Name + ".json")
    Write-Output ("Exporting NSG " + [char]34 + $networkSecurityGroup.Name + [char]34 + " to file " + [char]34 + $nsgFilePath + [char]34 + "...")
    $nsgHash | ConvertTo-Json -Depth 20 | Out-File -FilePath $nsgFilePath
}