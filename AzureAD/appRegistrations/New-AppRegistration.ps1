# Create Azure AD App registration and store app key inside a Key Vault
# Fabien Gilbert, Microsoft, 04-2021
#
[CmdletBinding()]
param (
    #ParameterFilePath
    [Parameter(Position = 0,
        HelpMessage = "Path to the JSON parameter file",
        Mandatory = $true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $ParameterFilePath,

    #SaveToKeyVault
    [Parameter(Position = 1,
        HelpMessage = "Save App Key to specified Key Vault")]
    [Boolean]
    $SaveToKeyVault = $true,

    #DisplayKeyInClear
    [Parameter(Position = 2,
        HelpMessage = "Display App Key in clear")]
    [Boolean]
    $DisplayKeyInClear = $false
)
# Function to generate password
function Get-RandomPassword {
    param (
        $pLength
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
    do{
        $Fourtet = @()    
        do{
            $SegmentsToAdd = @()
            foreach($SegmentType in $SegmentTypes){
                if($Fourtet -notcontains $SegmentType.Number){$SegmentsToAdd+=$SegmentType.Number}
            }
            $RandomSegment = Get-Random -InputObject $SegmentsToAdd
            $Fourtet += $RandomSegment
            $PasswordSegments += $RandomSegment
        }until($Fourtet.Count -ge 4 -or $PasswordSegments.Count -ge $pLength)    
    }until($PasswordSegments.Count -ge $pLength)
    $RandomPassword = $null
    foreach($PasswordSegment in $PasswordSegments){
        $SegmentType=$null;$SegmentType = $SegmentTypes | Where-Object -Property Number -EQ -Value $PasswordSegment    
        $RandomPassword += [char](Get-Random -Minimum $SegmentType.MinimumRandom -Maximum $SegmentType.MaximumRandom)
    }
    $RandomPassword
}
$currentFolder = Split-Path $script:MyInvocation.MyCommand.Path
# Import App Registration JSON parameter file
Write-Output ("Importing App Registration JSON parameter file path " + [char]34 + $ParameterFilePath + [char]34 + "...")
$appSettings = Get-Content -Path $ParameterFilePath | ConvertFrom-Json
if(!($appSettings)){Write-Error -Message ("Could not import JSON file " + [char]34 + $ParameterFilePath + [char]34 + ".");exit}
# Check Az connection
$azTenant = Get-AzTenant
if(!($azTenant)){Write-Error -Message "Could not get Azure AD Tenant. Check Az module and connection to Azure.";exit}
#Get App Registration
$aadApp = Get-AzADApplication -DisplayName $appSettings.displayName -ErrorAction:SilentlyContinue
if($aadApp){
    Write-Output ("Found existing " + [char]34 + $appSettings.displayName + [char]34 + " App Registration " + ".")
}
else{
    Write-Output ("Creating Azure AD App Registration " + [char]34 + $appSettings.displayName + [char]34 + "...")
    $aadApp = New-AzADApplication -DisplayName $appSettings.displayName -IdentifierUris $appSettings.identifierUri
    if($aadApp){
        Write-Output ("`tApp Registration created with Key " + $aadApp.ApplicationId.Guid)        
        $appSettings.ApplicationId = $aadApp.ApplicationId.Guid
        $appSettings | ConvertTo-Json -Depth 10 | Out-File -FilePath $ParameterFilePath
    }
    else{Write-Error -Message ("Could not create Azure AD App Registration " + [char]34 + $appSettings.displayName + [char]34 + ".");exit}
}
#Create Service Principal
$aadAppSvcPrincipal = Get-AzADServicePrincipal -ApplicationId $aadApp.ApplicationId
if($aadAppSvcPrincipal){Write-Output ("Service Principal id " + $aadAppSvcPrincipal + " already exists.")}
else{
    Write-Output ("Creating service principal...")
    $aadAppSvcPrincipal = New-AzADServicePrincipal -ApplicationId $aadApp.ApplicationId -SkipAssignment
}
#Certificates
if($appSettings.certificate){
    #Create self signed SSL certificate if no thumbprint specified
    if(!($appSettings.certificate.thumbprint)){
        Write-Output ("Creating SSL Certificate " + [char]34 + $appSettings.certificate.friendlyName + [char]34 + "...")
        $selfSignedCert = $null
        $selfSignedCert = New-SelfSignedCertificate -DnsName $appSettings.certificate.dnsName -FriendlyName $appSettings.certificate.friendlyName -CertStoreLocation $appSettings.certificate.store -KeyExportPolicy Exportable -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -NotAfter ([datetime]::now).AddYears($appSettings.certificate.lengthYears)   
        $appSettings.certificate.thumbprint = $selfSignedCert.Thumbprint
        $appSettings | ConvertTo-Json -Depth 10 | Out-File -FilePath $ParameterFilePath
    }
    #Open SSL Certificate
    Write-Output ("Opening SSL Certificate " + [char]34 + $appSettings.certificate.friendlyName + [char]34 + " thumbprint " + $appSettings.certificate.thumbprint + "...")
    $authCert = $null;$credValue=$null
    $authCert = Get-ChildItem -Path $appSettings.certificate.store | Where-Object -Property Thumbprint -EQ -Value $appSettings.certificate.thumbprint
    if(!($authCert)){Write-Output("Could not open SSL Certificate thumbprint " + $appSettings.certificate.thumbprint + " in store " + $appSettings.certificate.store + ". Aborting.");exit}
    $tempCertPath = Join-Path -Path $ENV:TMP -ChildPath ($appSettings.certificate.friendlyName + ".cer")    
    $authCert | Export-Certificate -FilePath $tempCertPath
    if(!(Test-Path -Path $tempCertPath)){Write-Output ("Could not export SSL Certificate thumbprint " + $appSettings.certificate.thumbprint + " to store path " + [char]34 + $tempCertPath + [char]34 + ". Aborting.");exit}
    $cer = New-Object System.Security.Cryptography.X509Certificates.X509Certificate     
    $cer.Import($tempCertPath) 
    $binCert = $cer.GetRawCertData() 
    $credValue = [System.Convert]::ToBase64String($binCert)
    if(!($credValue)){Write-Output ("Could not open SSL Certificate path " + [char]34 + $tempCertPath + [char]34 + " and convert it to Base 64. Aborting.");exit}
    #Upload certificate to App Registration
    Write-Output ("Uploading SSL Certificate thumbprint " + $appSettings.certificate.thumbprint + " to Credentials for App Registration " + [char]34 + $aadApp.DisplayName + [char]34 +  "...")
    New-AzADAppCredential -ApplicationId $aadApp.ApplicationId -CertValue $credValue -EndDate $cer.GetExpirationDateString()
}
#Key
if($appSettings.key){
    $validUntil = ([datetime]::Now).AddYears(1)
    Write-Output ("Generating Application Key valid until: " + $validUntil)
    $appKey = Get-RandomPassword -pLength 24
    if($DisplayKeyInClear){Write-Output ("`r`n" + $appKey + "`r`n")}
    $appKeySecure = ConvertTo-SecureString -String $appKey -AsPlainText -Force
    $setKey = New-AzADAppCredential -ApplicationId $aadApp.ApplicationId -Password $appKeySecure -EndDate $validUntil
    if($setKey){Write-Output "`tkey creation succeeded"}
    else{Write-Error -Message ("App Registration key creation failed")}
    if($SaveToKeyVault){
        Write-Output ("Saving Application Key in Key Vault " + [char]34 + $appSettings.key.keyVaultName + [char]34 + "...")
        Set-AzKeyVaultSecret -VaultName $appSettings.key.keyVaultName -Name $appSettings.key.secretName -SecretValue $appKeySecure
    }
}