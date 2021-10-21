#Download NSG Flow Logs and turns them into a spreadsheet for analysis
#Written by Fabien Gilbert in May of 2019
#
$NsgHistoryInHours = -3
$AskSettings = $true
if($AzureConnection -and $Sub -and $FlowStore){
  $UseCurrentSettings = Read-Host ("`r`nSubscription: " + $Sub.Name + "`r`nStorage Account: " + $FlowStore.StorageAccountName + "`r`n`r`nEnter different settings? Y/N (default N)")
  if($UseCurrentSettings -ne "Y"){$AskSettings=$false}
}
if($AskSettings){
    #Connect to Azure
    do{
        if((Get-AzTenant).Id){$AzureConnection=$true}
        else{
            $AzureConnection=$false
            Write-Output "Enter your Azure credentials (Window may be in the background)"
            Connect-AzAccount
        }
    }until($AzureConnection)
    #Select subscription
    Write-Output "`r`nSelect Subscription in gridview window (may be in the background)`r`n"
    $Sub = Get-AzSubscription | Where-Object -Property State -EQ -Value "Enabled" | Select Name, @{l="Ordinal";e={[regex]::Match($_.Name,"\d{1,}").Value}}, Id | Sort Ordinal | Select Name, Id | Out-GridView -PassThru
    if((Get-AzContext).Subscription.Name -ne $Sub.Name){Set-AzContext -SubscriptionName $Sub.Name}
    #Select storage account    
    $StorageAccts = Get-AzStorageAccount
    $FlowStore = $StorageAccts | Select-Object StorageAccountName, location, @{l="Component Tag";e={$_.Tags.Component}}, context | Out-GridView -PassThru
}
$AskNsg = $true
if($NSGFlowBlobs){
    Write-Output "`r`n"
    foreach($NSGFlowBlob in $NSGFlowBlobs){
        Write-Output ("`t" + $NSGFlowBlob.Name)
    }
    $UseCurrentNsg = Read-Host ("`r`nUse current NSG Flow Log selection? Y/N (default Y)")
    if($UseCurrentNsg -ne "N"){$AskNsg=$false}
}
if($AskNsg){
    #Download flow logs and export them to a spreadsheet
    Write-Output ("`r`nGetting blob list from storage account...")
    $NSGFlowContainer = Get-AzStorageContainer -Context $FlowStore.Context -Name "insights-logs-networksecuritygroupflowevent"
    if($NSGFlowContainer)
    {
        #Compile list of NSG Flow logs
        $NSGFlowBlobs = Get-AzStorageBlob -Context $FlowStore.Context -Container $NSGFlowContainer.Name | Where-Object -Property LastModified -GE ([datetime]::now).ToUniversalTime().AddHours($NsgHistoryInHours)
        $SubNICs = Get-AzNetworkInterface
        $FullConnectionLog = @()
        foreach($NSGFlowBlob in $NSGFlowBlobs)
        {
            $Mac1 = ([regex]::Matches($NSGFlowBlob.Name,"macAddress=[0-9A-F]{12}")).Value
            $Mac = $Mac1.Split("=")[1]
            $NsgName = ([regex]::Matches($NSGFlowBlob.Name,"AG[VT]{1}-[PS]{1}-SNT-[A-Z]{1,4}-[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}_[0-9]{1,2}-NSG")).Value
            $FlowNIC = $SubNICs | Select-Object Name, @{l="MAC";e={$_.MacAddress.Replace("-","")}} | Where-Object -Property MAC -EQ -Value $Mac
            Add-Member -InputObject $NSGFlowBlob -MemberType NoteProperty -Name NSG -Value $NsgName
            Add-Member -InputObject $NSGFlowBlob -MemberType NoteProperty -Name NIC -Value $FlowNIC.Name
        }
        #Select desired NSG Flow Log
        Write-Output "`r`nSelect NSG Flow Log File in gridview window (may be in the background)`r`n"
        $NSGFlowBlobs = $NSGFlowBlobs | Sort-Object NSG, NIC | Select-Object NSG, NIC, Name | Out-GridView -PassThru
    }
    else{Write-Output ("No NSG Flow Log in storage account " + $Settings.StorageAccount.StorageAccountName + "...")}
}
if($NSGFlowBlobs){
    #Create temp folder to download flow logs
    $TempFolder = $env:TEMP + "\NsgFlowReader"
    if(!(Test-Path -Path $TempFolder)){New-Item -Path $TempFolder -ItemType Directory}  
    foreach($NSGFlowBlob in $NSGFlowBlobs)
    {
        if(@($NSGFlowBlobs).count -gt 1){$ArrayIndex = [array]::IndexOf($NSGFlowBlobs,$NSGFlowBlob)}
        else{$ArrayIndex = 0}
        Write-Output ("Processing file " + ($ArrayIndex + 1) + " out of " + @($NSGFlowBlobs).count + "...")
        $NSGName = [regex]::Match($NSGFlowBlob.Name,"AG[VT]{1}-[PS]{1}-SNT-[DBAPEDINSS]{2}-[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}_[0-9]{1,2}-NSG").Value.Replace("NETWORKSECURITYGROUPS/","")        
        $DownloadPath = $TempFolder + "\" + $ArrayIndex + ".json"
        Write-Output ("Downloading " + [char]34 + $NSGFlowBlob.Name + [char]34 + " to " + [char]34 + $DownloadPath + [char]34 + "...")
        Get-AzStorageBlobContent -Context $FlowStore.Context -Container $NSGFlowContainer.Name -Blob $NSGFlowBlob.Name -Destination $DownloadPath -Force
        $NSGFlowLog = Get-Content $DownloadPath | ConvertFrom-Json        
        foreach($NSGFlowLogRecord in $NSGFlowLog.records)
        {        
            foreach($NSGRule in $NSGFlowLogRecord.properties.flows)
            {            
                foreach($NSGFlow in $NSGRule.flows)
                {
                    foreach($NSGFlowTuple in $NSGFlow.flowTuples)
                    {
                        $FullConnectionLog += $NSGFlowTuple | Select @{l="NSG Name";e={$NSGName}},@{l="UTC Time";e={$NSGFlowLogRecord.Time}}, @{l="NSG Rule";e={$NSGRule.Rule}}, @{l="Source IP Address";e={$NSGFlowTuple.Split(",")[1]}}, @{l="Destination IP Address";e={$NSGFlowTuple.Split(",")[2]}}, @{l="Source Port";e={$NSGFlowTuple.Split(",")[3]}}, @{l="DestinationPort";e={$NSGFlowTuple.Split(",")[4]}}, @{l="Protocol";e={$NSGFlowTuple.Split(",")[5]}}, @{l="Inbound/Outbound";e={$NSGFlowTuple.Split(",")[6]}}, @{l="Allow/Deny";e={$NSGFlowTuple.Split(",")[7]}}
                    }                
                }
            }        
        }
        Remove-Item -Path $DownloadPath -Force
    }
}
#Export to spreadsheet and open it
$FullConnectionLog | Export-Excel -Path ($TempFolder + "\NSG Flow Log " + (Get-Date -UFormat %Y%m%d%H%M%S) + ".xlsx") -AutoSize -Show