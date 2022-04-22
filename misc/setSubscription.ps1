$allContexts = Get-AzContext -ListAvailable
$sortedAllContexts = $allContexts | Sort-Object -Property {$_.Account.id}, {$_.Subscription.Name}
$indexedAllContexts = $sortedAllContexts | Select-Object -Property @{l="Index";e={[array]::IndexOf($sortedAllContexts,$_)}},@{l="Login";e={$_.Account.id}}, @{l="Subscription";e={$_.Subscription.Name}}
$indexedAllContexts | Format-Table -AutoSize
$selectId = Read-Host -Prompt "Subscription # to switch context to?"
if($selectId -and ($indexedAllContexts | Select-Object -ExpandProperty Index) -contains $selectId){
    $selectSub = $sortedAllContexts[$selectId]
    if((Get-AzContext).Subscription.Id -ne $selectSub.Subscription.Id)
    {
        $selectSub | Set-AzContext
    }
}
else{
    exit
}