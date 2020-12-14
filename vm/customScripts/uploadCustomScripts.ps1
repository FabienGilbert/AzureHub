#Upload custom script files to storage account
#Fabien Gilbert, AIS, 2020-12
#
#
$customScriptContainerName = "vmcustomscripts"
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
# Storage account selection
$storageAccounts = Get-AzStorageAccount
$storageAccountsWithId = $storageAccounts | Select-Object @{l = "Index"; e = { [array]::IndexOf($storageAccounts, $_) } }, StorageAccountName
Write-Output "`r`n"
foreach ($store in $storageAccountsWithId) { Write-Output ([string]($store.Index) + " - " + $store.StorageAccountName) }
Write-Output "`r`n"
$storePrompt = Read-Host -Prompt ("Enter storage account index. Default 0")
if (!($storePrompt)) {$storePrompt = 0}
$autoStore = $storageAccounts | Where-Object -Property StorageAccountName -EQ -Value ($storageAccountsWithId | Where-Object -Property Index -EQ -Value $storePrompt).StorageAccountName
if (!($autoStore)) { Write-Error -Message "Could not get Storage Account"; exit }
#Get Storage Account Context
$StorObj = Get-AzStorageAccount -ResourceGroupName $autoStore.ResourceGroupName -Name $autoStore.StorageAccountName
#Get storage container
$templateContainer = Get-AzStorageContainer -Context $StorObj.Context -Name $customScriptContainerName -ErrorAction:SilentlyContinue
#Create container if it doesn't exist
if(!($templateContainer)){$templateContainer = New-AzStorageContainer -Context $StorObj.Context -Name $customScriptContainerName }
#Select files to uplod
$subfolders = Get-ChildItem -Path $currentFolder | Where-Object -Property PSIsContainer -EQ -Value $true
Write-Output "Select folders to upload in gridview window (may be in the background)."
$selectedFolder = $subfolders | Out-GridView -PassThru
$fileList = Get-ChildItem -Path $selectedFolder
foreach($F in $fileList){    
    $B = Get-AzStorageBlob -Context $StorObj.Context -Container $customScriptContainerName -Blob $f.Name -ErrorAction:SilentlyContinue
    if($F.LastWriteTimeUtc -gt $B.LastModified.UtcDateTime)
    {
        Write-Output ("Uploading " + [char]34 + $F.Name + [char]34 + " to storage container...")
        Set-AzStorageBlobContent -Context $StorObj.Context -Container $customScriptContainerName -Blob $F.Name -File $F.FullName      
    }
}