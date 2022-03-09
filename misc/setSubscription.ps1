Get-AzContext -ListAvailable | Sort-Object -Property {$_.Account.id}, {$_.Subscription.Name} |  Out-GridView -PassThru | Set-AzContext