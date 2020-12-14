#Generate VM Local Administrator password and Encryption Key in Key Vault
Param
(
    #EnterprisePrefix
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]   
    [String]
    $EnterprisePrefix,

    #RegionPrefix
    [Parameter(Position = 1)]
    [ValidateNotNullOrEmpty()]   
    [String]
    $RegionPrefix,

    #vmApplicationPrefix
    [Parameter(Position = 2)]
    [ValidateNotNullOrEmpty()]   
    [String]
    $vmApplicationPrefix,

    #EnvironmentPrefix
    [Parameter(Mandatory = $true, 
        Position = 3)]
    [ValidateNotNullOrEmpty()]   
    [String]
    $EnvironmentPrefix,

    #Naming convention Subscription Ordinal Prefix
    [Parameter(Mandatory = $true, 
        Position = 4)]
    [ValidatePattern("^[S]\d{2}$")]    
    [String]
    $SubscriptionOrdinalPrefix,

    #Subscription Id
    [Parameter(Mandatory = $true, 
        Position = 5)]
        [ValidateNotNullOrEmpty()]  
    [String]
    $SubscriptionId,

    #vmComponentPrefix
    [Parameter(Mandatory = $true, 
        Position = 6)]
    [ValidateNotNullOrEmpty()]   
    [String]
    $vmComponentPrefix,

    #encryptionVolumeType
    [Parameter(Mandatory = $true,  
        Position = 7)]
    [ValidateSet("None", "OS", "Data", "All")]
    $encryptionVolumeType,
    

    #encryptionType
    [Parameter(Position = 8)]
    [ValidateSet("bek", "kek")]
    $encryptionType = "bek"
)

#Function to generate random password
function Get-RandomPassword {
    param (
        #Password length
        [Parameter(Mandatory = $true, 
            Position = 0)]
        [ValidateRange(8, 64)] 
        [Int]
        $Length
    )    
    $SegmentTypes = "[
        {
            'Number': 1,
            'MinimumRandom': 65,
            'MaximumRandom': 91
        },
        {
            'Number': 2,
            'MinimumRandom': 97,
            'MaximumRandom': 122
        },
        {
            'Number': 3,
            'MinimumRandom': 48,
            'MaximumRandom': 58
        },
        {
            'Number': 4,
            'MinimumRandom': 37,
            'MaximumRandom': 47
        }
    ]" | ConvertFrom-Json
    $PasswordSegments = @()
    do {
        $Fourtet = @()    
        do {
            $SegmentsToAdd = @()
            foreach ($SegmentType in $SegmentTypes) {
                if ($Fourtet -notcontains $SegmentType.Number) { $SegmentsToAdd += $SegmentType.Number }
            }
            $RandomSegment = Get-Random -InputObject $SegmentsToAdd
            $Fourtet += $RandomSegment
            $PasswordSegments += $RandomSegment
        }until($Fourtet.Count -ge 4 -or $PasswordSegments.Count -ge $Length)    
    }until($PasswordSegments.Count -ge $Length)
    $RandomPassword = $null
    foreach ($PasswordSegment in $PasswordSegments) {
        $SegmentType = $null; $SegmentType = $SegmentTypes | Where-Object -Property Number -EQ -Value $PasswordSegment    
        $RandomPassword += [char](Get-Random -Minimum $SegmentType.MinimumRandom -Maximum $SegmentType.MaximumRandom)
    }
    $RandomPassword
}


$keyVaultName = ($EnterprisePrefix + "-" + $RegionPrefix + "-" + $EnvironmentPrefix + "-AKV-" + $SubscriptionOrdinalPrefix + "-01")
$keyVaultKeyName = ($vmApplicationPrefix + "-" + $vmComponentPrefix + "-" + $EnvironmentPrefix + "-CRYPTKEY-01")
$keyVaultSecretName = ($vmApplicationPrefix + $vmComponentPrefix + $EnvironmentPrefix + "localusr1").ToLower()
$keyVaultSecretValue = ConvertTo-SecureString -AsPlainText -Force -String (Get-RandomPassword -Length 16)

#Set context to proper subscription
if((Get-AzContext).Subscription.Id -ne $SubscriptionId){
    Write-Output ("setting context to subscription id " + [char]34 + $SubscriptionId + [char]34 + "...")
    Set-AzContext -SubscriptionId $SubscriptionId
}

#Check Key Vault existence
$akv = Get-AzKeyVault -VaultName $keyVaultName
if ($akv) {
    Write-Output ("Found key vault " + [char]34 + $akv.VaultName + [char]34 + "...")
    #Check for key vault firewall
    if ($akv.NetworkAcls.DefaultAction -eq "Deny") {
        $currentPublicIpInfo = Invoke-RestMethod -Uri "http://ipinfo.io/json"
        if ($currentPublicIpInfo.ip) {
            if ($akv.NetworkAcls.IpAddressRanges -Contains $currentPublicIpInfo.ip -or $akv.NetworkAcls.IpAddressRanges -Contains ($currentPublicIpInfo.ip + "/32")) { Write-Output ("IP address " + $currentPublicIpInfo.ip + " already allowed in key vault firewall.") }
            else {
                Write-Output ("Adding IP address " + $currentPublicIpInfo.ip + " to key vault firewall.")
                Add-AzKeyVaultNetworkRule -ResourceGroupName $akv.ResourceGroupName -VaultName $akv.VaultName -IpAddressRange $currentPublicIpInfo.ip 
                $addedKeyVaultFirewallIp = $true
            }
        }
        else {
            Write-Error -Message ("Could not get current public IP address to add to the key vault firewall")
        }
    }
    #Check secret existence
    $keyVaultSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultSecretName
    if ($keyVaultSecret) {
        Write-Output ("Secret " + [char]34 + $keyVaultSecretName + [char]34 + " already exist in key vault " + [char]34 + $keyVaultName + [char]34 + ".")
    }
    else {
        #Create secret
        Write-Output ("Creating secret " + [char]34 + $keyVaultSecretName + [char]34 + " in key vault " + [char]34 + $keyVaultName + [char]34 + "...")
        $keyVaultSecret = Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultSecretName -SecretValue $keyVaultSecretValue
    }
    #Send the secret name to a pipeline variables for use by the ARM template     
    Write-Host ("##vso[task.setvariable variable=localAdminUsername;]" + $keyVaultSecretName)
    #Create key only if KEK encryption specified
    if ($encryptionVolumeType -ne "None" -and $encryptionType -eq "kek") {
        #Check key existence    
        $keyVaultKey = Get-AzKeyVaultKey -VaultName $keyVaultName -Name $keyVaultKeyName
        if ($keyVaultKey) {
            Write-Output ("Key " + [char]34 + $keyVaultKeyName + [char]34 + " already exist in key vault " + [char]34 + $keyVaultName + [char]34 + ".")
        }
        else {
            #Create key
            Write-Output ("Creating key " + [char]34 + $keyVaultKeyName + [char]34 + " in key vault " + [char]34 + $keyVaultName + [char]34 + "...")        
            $keyVaultKey = Add-AzKeyVaultKey -VaultName $keyVaultName -Name $keyVaultKeyName -Destination Software
        }
        #Send the key uri to a pipeline variables for use by the ARM template    
        Write-Host ("##vso[task.setvariable variable=encryptionKekUri;]" + $keyVaultKey.Id)
    }    
    #Remove public IP from key vault firewall
    if ($addedKeyVaultFirewallIp) {
        Write-Output ("Removing IP address " + $currentPublicIpInfo.ip + " from key vault firewall.")
        Remove-AzKeyVaultNetworkRule -ResourceGroupName $akv.ResourceGroupName -VaultName $akv.VaultName -IpAddressRange $currentPublicIpInfo.ip               
    }
}
else {
    Write-Error -Message ("Could not get Key Vault " + [char]34 + $keyVaultName + [char]34)
}