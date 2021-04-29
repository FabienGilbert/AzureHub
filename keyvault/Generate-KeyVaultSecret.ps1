#Generate secret in Key Vault
#Fabien Gilbert, AIS, 06/2020
Param
(
    # Key Vault name
    [Parameter(Mandatory = $true, 
        Position = 0)]
    [ValidateNotNullOrEmpty()]   
    [String]
    $VaultName,

    # Secret name
    [Parameter(Mandatory = $true, 
        Position = 1)]
    [ValidateNotNullOrEmpty()]   
    [String]
    $SecretName,

    # Password length
    [Parameter(Mandatory = $false, 
        Position = 2)] 
    [Int]
    $PasswordLength = 12,

    # Display Password
    [Parameter(Mandatory = $false, 
        Position = 3)] 
    [Bool]
    $DisplayPassword = $false

)
$armTemplate = "keyVaultSecret_armTemplate.json"
$currentFolder = Split-Path $script:MyInvocation.MyCommand.Path
$armTemplatePath = Join-Path -Path $currentFolder -ChildPath $armTemplate
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
#Get Key Vault
Write-Output ("Getting Key Vault " + $VaultName + "...")
$akv = Get-AzKeyVault -VaultName $VaultName
if ($akv) { Write-Output ("`tfound key vault resource id: " + $akv.ResourceId) }
else { Write-Error -Message ("Could not find Key Vault name " + $VaultName + "."); exit }
# Get existing secret
Write-Output ("`r`nChecking for existence of secret " + $SecretName + "...")
$akvSecret = Get-AzKeyVaultSecret -VaultName $akv.VaultName -Name $SecretName -ErrorAction:SilentlyContinue
if($akvSecret){
    $outStr = "`tsecret already exists"
    if($DisplayPassword){
        $clearSecret = ConvertFrom-SecureString -AsPlainText -SecureString $akvSecret.SecretValue
        $outStr += (" with value: " + $clearSecret)
    }
    else{$outStr += "."}
    Write-Output $outStr
    exit
}
else{Write-Output "`tsecret does not exist yet."}
# Get random password    
Write-Output ("`r`nGenerating random password with " + $PasswordLength + " characters...")
$randomPwd = Get-RandomPassword -Length $PasswordLength
if($DisplayPassword){Write-Output ("`tgenerated: " + $randomPwd)}
else{Write-Output "`tgenerated password."}
Write-Output "`tconverting random password to secure string..."
$randomSecPwd = ConvertTo-SecureString -AsPlainText -Force -String $randomPwd   
# Create secret
Write-Output ("`r`nCreating key vault secret " + $SecretName + "...")
$akvSecret = Set-AzKeyVaultSecret -VaultName $akv.VaultName -Name $SecretName -SecretValue $randomSecPwd
if($akvSecret){Write-Output "`tsecret created successfully"}
else{Write-Error -Message ("Could not create key vault secret name " + $SecretName + ".")}