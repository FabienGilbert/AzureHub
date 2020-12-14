#Find available IP addresses in a VNET subnet
#
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

    #EnvironmentPrefix
    [Parameter(Mandatory = $true, 
        Position = 2)]
    [ValidateNotNullOrEmpty()]   
    [String]
    $EnvironmentPrefix,

    #Naming convention Subscription Ordinal Prefix
    [Parameter(Mandatory = $true, 
        Position = 3)]
    [ValidatePattern("^[S]\d{2}$")]    
    [String]
    $SubscriptionOrdinalPrefix,

    #Subscription Id
    [Parameter(Mandatory = $true, 
        Position = 4)]
        [ValidateNotNullOrEmpty()]  
    [String]
    $SubscriptionId,

    #vmCount
    [Parameter(Mandatory = $true, 
        Position = 5)]
    [ValidateNotNullOrEmpty()]   
    [Int]
    $vmCount,

    #SubnetName
    [Parameter(Position = 6)]
    [String]
    $subnetName,

    #SubnetTier
    [Parameter(Position = 7)]
    [String]
    $subnetTier,

    #staticIpAddresses
    [Parameter(Position = 8)]
    [String]
    $staticIpAddresses
)

$vnetResourceGroup = ($EnterprisePrefix + "-" + $RegionPrefix + "-" + $EnvironmentPrefix + "-NET-RGP-" + $SubscriptionOrdinalPrefix)
$vnetName = ($EnterprisePrefix + "-" + $RegionPrefix + "-" + $EnvironmentPrefix + "-VNET-" + $SubscriptionOrdinalPrefix + "-01")

#Set context to proper subscription
if((Get-AzContext).Subscription.Id -ne $SubscriptionId){
    Write-Output ("setting context to subscription id " + [char]34 + $SubscriptionId + [char]34 + "...")
    Set-AzContext -SubscriptionId $SubscriptionId
}
#Get VNET
Write-Output ("Getting VNET " + [char]34 + $vnetName + [char]34 + " in Resource Group " + [char]34 + $vnetResourceGroup + [char]34 + "...")
$VN = Get-AzVirtualNetwork -ResourceGroupName $vnetResourceGroup -Name $vnetName
#Attempt to select subnet based on subnetName parameter
$VNS = $null
$VNS = $VN.Subnets | Where-Object -Property Name -EQ -Value $subnetName
if ($VNS) {
    Write-Output ("Found subnet " + [char]34 + $VNS.Name + [char]34 + " based on provided subnetName parameter (" + [char]34 + $subnetName + [char]34 + ").")
}
#If not, attempt to select subnet based on subnetTier parameter
else {
    $VNS = $VN.Subnets | Where-Object -Property Name -Like -Value ($EnterprisePrefix + "-" + $RegionPrefix + "-" + $EnvironmentPrefix + "-SNT-" + $subnetTier + "-*")
    if ($VNS) { Write-Output ("Found subnet " + [char]34 + $VNS.Name + [char]34 + " based on provided subnetTier parameter (" + [char]34 + $subnetTier + [char]34 + ").") }    
}
#Only proceed if subnet found
if ($VNS) {    
    #Send the subnetname to a pipeline variables for use by the ARM template 
    Write-Host ("##vso[task.setvariable variable=vnetSubnetName;]" + $VNS.Name)
    #Build array with all IP addresses in subnet
    Write-Output ("Looking for " + [string]$vmCount + " IP addresses in VNET " + [char]34 + $VN.Name + [char]34 + " subnet " + [char]34 + $VNS.Name + [char]34 + "...")
    $subnetArray = $null; $subnetAddress = $null; $subnetPrefix = $null; $subnetSize = $null; $subnetIndex = $null; $subnetFirstPart = $null; $subnetLastPart = $null; $subnetIpReport = @(); $i = 0
    $subnetArray = $VNS.AddressPrefix.Split("/")
    $subnetAddress = $subnetArray[0]
    $subnetPrefix = $subnetArray[1]
    $subnetSize = ([Math]::Pow(2, (32 - $subnetPrefix)) - 5)
    $subnetIndex = $subnetAddress.LastIndexOf(".")
    $subnetFirstPart = $subnetAddress.SubString(0, $subnetIndex) + "."
    $subnetLastPart = $subnetAddress.SubString($subnetIndex + 1)
    do {
        $subnetIpReport += New-Object -TypeName PSObject -Property @{"IpAddress" = ($subnetFirstPart + [string]([int]($subnetLastPart) + 4 + $i))
                                                                     "Status" = "Available"
        }
        $i++
    }while ($i -le $subnetSize)
    #Remove used IP addresses from array
    foreach ($vnIpConf in $VNS.IpConfigurations) {
        #Break Ip Configuration Id into an array
        $idar = $vnIpConf.Id.Split("/")
        #switch depending on whether the IP Configuration is that of a NIC or a Load Balancer
        switch ($vnIpConf) {
            { $_.Id -like "*/networkInterfaces/*" } {            
                #Get resource group name, NIC name and IP config name from ip config id   
                $nicRg = $idar[($idar.IndexOf("resourceGroups") + 1)]
                $nicName = $idar[($idar.IndexOf("networkInterfaces") + 1)]
                $ipConfigName = $idar[($idar.IndexOf("ipConfigurations") + 1)]
                #Get IP config
                $nicObj = Get-AzNetworkInterface -ResourceGroupName $nicRg -Name $nicName
                $vnIpConfObj = Get-AzNetworkInterfaceIpConfig -NetworkInterface $nicObj -Name $ipConfigName
                if (!($vnIpConfObj)) { Write-Error -Message ("Could not get IP Configuration " + $vnIpConf.Id); exit }
                #Mark that IP as in use
                $usedIP = $subnetIpReport | Where-Object -Property IpAddress -EQ -Value $vnIpConfObj.PrivateIpAddress
                if (!($usedIP)) { Write-Error -Message ("Could not update array for IP Configuration " + $vnIpConf.Id); exit }
                $usedIP.Status = "In use"
            }
            { $_.Id -like "*/loadBalancers/*" } {              
                $lbRg = $idar[($idar.IndexOf("resourceGroups") + 1)]
                $lbName = $idar[($idar.IndexOf("loadBalancers") + 1)]
                $ipConfigName = $idar[($idar.IndexOf("frontendIPConfigurations") + 1)]
                $lbFeIpConfig = Get-AzLoadBalancer -ResourceGroupName $lbRg -Name $lbName | Get-AzLoadBalancerFrontendIpConfig -Name $ipConfigName
                #Mark that IP as in use
                $usedIP = $subnetIpReport | Where-Object -Property IpAddress -EQ -Value $lbFeIpConfig.PrivateIpAddress
                if (!($usedIP)) { Write-Error -Message ("Could not update array for IP Configuration " + $vnIpConf.Id); exit }
                $usedIP.Status = "In use"
            }
        }
    }
    #initiliaze empty IP Address Array
    $ipAddressArray = @()
    #Select provided static IP addresses if valid
    try {
        $ErrorActionPreference = 'SilentlyContinue'    
        $staticIpAddressArray = ConvertFrom-Json -InputObject $staticIpAddresses
    }
    catch{ $staticIpAddressArray = @()}
    $subnetIpReport | Where-Object -Property IpAddress -EQ $staticIpAddress
    if (@($staticIpAddressArray).Count -eq $vmCount) {
        foreach ($staticIpAddress in $staticIpAddressArray) {            
            if ($subnetIpReport | Where-Object -Property IpAddress -EQ $staticIpAddress) {
                $ipAddressArray += $staticIpAddress
                Write-Output ("Selecting static ip address " + $staticIpAddress + " as provided in the staticIpAddresses parameter.")
            }
        }
    }
    #Look available IP addresses if staticIpAddress not found or invalid
    if(@($ipAddressArray).Count -ne $vmCount){
        $i = @($ipAddressArray).Count
        do {
            $availableIpAddress = ($subnetIpReport | Where-Object { $_.Status -eq "Available" })[$i].IpAddress
            Write-Output ("Selecting available IP Address " + $availableIpAddress)
            $ipAddressArray += $availableIpAddress
            $i++
        }until($i -ge $vmCount)
    }
    #Send the array of available IP addresses to a pipeline variables for use by the ARM template 
    $jsonIpAddresses = ConvertTo-Json -InputObject $ipAddressArray -Compress
    Write-Host ("##vso[task.setvariable variable=staticIpAddresses;]" + $jsonIpAddresses)

}
else {
    Write-Error -Message ("Could not find desired subnet in VNET " + [char]34 + $VN.Name + [char]34 + " neither based on subnetName parameter (" + [char]34 + $subnetName + [char]34 + "), nor based on subnetTier  parameter (" + [char]34 + $subnetTier + [char]34 + ").")
}