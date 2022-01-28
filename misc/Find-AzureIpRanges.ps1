#Script to populate routes in existing UDR ARM parameter file, based on the IP ranges published in https://www.microsoft.com/en-us/download/details.aspx?id=56519
#Fabien Gilbert, AIS, 04-2020
#
Param
(
    #SubscriptionName
    [Parameter(Mandatory = $true, 
        Position = 0)]
    [ValidateNotNullOrEmpty()]   
    [array]
    $ipAddresses
)
#Function to test if IP is in subnet
Function Test-IpInSubnet {
    param (
        [parameter(Mandatory = $true)]
        [string]
        $subnet,
    
        [parameter(Mandatory = $true)]
        [array]
        $ipAddresses
    )
    #Extract subnet address and prefix length
    $subnetArray = $subnet.Split("/")
    $subnetAddress = [Net.IPAddress]($subnetArray[0])
    $subnetPrefixLength = [int]($subnetArray[1])
    #Calculate subnet mask
    $mask = ([Math]::Pow(2, $subnetPrefixLength ) - 1) * [Math]::Pow(2, (32 - $subnetPrefixLength ))
    $bytes = [BitConverter]::GetBytes([UInt32] $mask)
    $subnetMask = [Net.IPAddress]((($bytes.Count - 1)..0 | ForEach-Object { [String] $bytes[$_] }) -join ".")
    #Test if IP addresses are in subnet
    $ipReport = @()
    foreach($ipAddress in $ipAddresses){
        $ipHash = @{
            "ip" = $ipAddress
            "inSubnet" = $false
        }     
        if (($subnetAddress.address -band $subnetMask.address) -eq (([Net.IPAddress]$ipAddress).address -band $subnetMask.address)) {$ipHash.inSubnet = $true}
        $ipReport += New-Object -TypeName psobject -Property $ipHash
    }  
    $ipReport
}
#Turning IP Address array into array of objects
$clientIpAddresses = @()
foreach ($ip in $ipAddresses) {
    $clientIpAddresses += @{
        "ipAddress"   = $ip
        "azureClouds" = @()
    }
}
$currentFolder = Split-Path $script:MyInvocation.MyCommand.Path
#Import Azure Datacenter IP ranges JSON file
$ipRangesFilePath = Get-ChildItem -Path $currentFolder -Recurse -Filter "ServiceTags*.json" | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
Write-Output ("Importing Azure Datacenter IP ranges JSON file " + [char]34 + $ipRangesFilePath.Name + [char]34 + "...")
$ipRangesFile = Get-Content -Path $ipRangesFilePath.FullName | ConvertFrom-Json
if (!($ipRangesFile)) { Write-Output ("Could not import JSON file " + [char]34 + $ipRangesFilePath.FullName + [char]34 + ". Aborting."); exit }
#Selecting all public Azure cloud services and regions
$azClouds = $ipRangesFile | Where-Object -Property Cloud -EQ -Value "Public" | Select-Object -ExpandProperty values
#Narrow down clouds and services with address prefixes are within the same /15 range
Write-Output "`r`nNarrowing down Azure clouds/services with subnets within the same /15 range..."
$shortList = @()
foreach ($azCloud in $azClouds) { 
    foreach ($clientIp in $clientIpAddresses) {
        $cOcts = $clientIp.ipAddress.Split(".")
        $cOct1 = [int]($cOcts[0])
        $cOct2 = [int]($cOcts[1])
        $ip1 = ([string]$cOct1 + "." + [string]($cOct2 - 1) + ".*")
        $ip2 = ([string]$cOct1 + "." + [string]($cOct2) + ".*")
        $ip3 = ([string]$cOct1 + "." + [string]($cOct2 + 1) + ".*")
        $subnetShortlist = $null
        $subnetShortlist = $azCloud.properties.addressPrefixes | Where-Object { $_ -like $ip1 -or $_ -like $ip2 -or $_ -like $ip3 }
        if ($subnetShortlist) {
            Write-Output ("`tfound " + [string]($subnetShortlist).Count + " address prefixes within a /15 range in " + [char]34 + $azCloud.name + [char]34 + "...")
            $shortList += New-Object -TypeName PSObject -Property @{
                "name"     = $azCloud.name
                "region"   = $azCloud.properties.region
                "platform" = $azCloud.properties.platform
                "subnet"   = $subnetShortlist    
            }
        }
    }
}
Write-Output ("Completed narrowing down " + [string]($shortList.Count) + " Azure clouds/services with " + ($shortList | Select-Object -ExpandProperty subnet).Count + " subnets within the same /15 range.`r`n")
Write-Output ("`r`nLooking for exact subnet matched within shortlist...")
#Look for exact subnet match in each short list cloud/service address prefix
foreach ($azCloud in $shortList) {    
    Write-Output ("Processing " + $azCloud.name + "...") 
    $snts = $azCloud.subnet
    foreach ($snt in $snts) {
        Write-Output ("`tsubnet " + [string]([array]::IndexOf($snts, $snt) + 1) + "/" + [string]($snts.Count) + " - " + $snt)
        #Testing if IP Addresses are part of subnet
        $sntTest = Test-IpInSubnet -subnet $snt -ipAddresses $ipAddresses
        $matchIp = $sntTest | Where-Object {$_.inSubnet -eq $true}
        if($matchIp){
            foreach($ip in $matchIp){    
                Write-Output ("`t`tfound " + $ip.ip + " in that subnet!")            
                $clientIpAddress = $clientIpAddresses | Where-Object {$_.ipAddress -eq $ip.ip}               
                $clientIpAddress.azureClouds +=  @{
                    "name"     = $azCloud.name
                    "region"   = $azCloud.region
                    "platform" = $azCloud.platform
                    "subnet"   = $snt   
                }
            }
        }
        <#Calculating subnet size and generating array of IP addresses
        $subnetArray = $snt.Split("/")
        $subnetAddress = $subnetArray[0]
        $subnetPrefix = $subnetArray[1]
        $subnetSize = [Math]::Pow(2, (32 - $subnetPrefix)) 
        $sntOctArray = $subnetAddress.Split(".")
        $sntOct1 = [int]($sntOctArray[0])
        $sntOct2 = [int]($sntOctArray[1])
        $sntOct3 = [int]($sntOctArray[2])
        $sntOct4 = [int]($sntOctArray[3])
        $subnetIpAddresses = @()
        $i = 0        
        do {            
            $subnetIpAddresses += ([string]$sntOct1 + "." + [string]$sntOct2 + "." + [string]$sntOct3 + "." + [string]$sntOct4)
            if ($sntOct4 -eq 255) {
                $sntOct4 = 0
                if ($sntOct3 -eq 255) {
                    $sntOct3 = 0
                    if ($sntOct2 -eq 255) {
                        $sntOct2 = 0
                        $sntOct1++
                    }
                    else { $sntOct2++ }
                }
                else { $sntOct3++ }
            }
            else { $sntOct4++ }
            $i++
        }while ($i -lt $subnetSize)
        #Checking if provided IP Addresses are in that subnet
        foreach ($ip in $clientIpAddresses) {
            if ($subnetIpAddresses -contains $ip.ipAddress) {
                Write-Output ("`tfound " + $ip.ipAddress + " in " + $snt + ".")
                $ip.azureClouds += @{
                    "name"     = $azCloud.name
                    "region"   = $azCloud.properties.region
                    "platform" = $azCloud.properties.platform
                    "subnet"   = $snt    
                }            
            }
        }#>
    }
}
#Output JSON IP Address report
$clientIpAddresses | ConvertTo-Json -Depth 10