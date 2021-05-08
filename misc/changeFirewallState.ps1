# Allocate/Deallocate Azure Firewall
#
[CmdletBinding()]
param (
    # ResourceGroup
    [Parameter(Position = 0,
        HelpMessage = "Name of the Resource Group that contains the firewall and public IPs",
        Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]
    $ResourceGroup,

    # Firewall
    [Parameter(Position = 1,
        HelpMessage = "Azure Firewall name",
        Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]
    $Firewall,

    # VNET
    [Parameter(Position = 2,
        HelpMessage = "VNET name")]
    [ValidateNotNullOrEmpty()]
    [String]
    $VNET,

    # PublicIp
    [Parameter(Position = 3,
        HelpMessage = "Public IP name")]
    [ValidateNotNullOrEmpty()]
    [String]
    $PublicIp,

    # State
    [Parameter(Position = 4,
        HelpMessage = "Desired Firewall state")]
    [ValidateSet("deallocated","allocated")]
    [String]
    $State
)

# Get Azure Firewall
Write-Output ("`r`nLooking for firewall " + [char]34 + $firewall + [char]34 + " in Resource Group " + [char]34 + $ResourceGroup + [char]34 + "...")
$azfw = Get-AzFirewall -ResourceGroupName $ResourceGroup -Name $Firewall
if(azfw){Write-Output ("`tfound firewall resource id: " + $azfw.Id)}
else{Write-Error -Message ("Could not find firewall " + [char]34 + $firewall + [char]34 + " in Resource Group " + [char]34 + $ResourceGroup + [char]34 + ".");exit}
# Check status
if($State -eq "deallocated" -and !($azfw.IpConfigurations)){Write-Output ("`r`nFirewall already deallocated.")}
# Deallocate
if($State -eq "deallocated" -and $azfw.IpConfigurations){
    Write-Output ("`r`nDeallocating firewall...")
    $azfw.Deallocate()
    Set-AzFirewall -AzureFirewall $azfw
}
if($State -eq "allocated" -and $azfw.IpConfigurations){Write-Output ("`r`nFirewall already allocated.")}
# Allocate
if($State -eq "allocated" -and !($azfw.IpConfigurations)){
    Write-Output ("`r`nAllocating firewall...")
    Write-Output ("`tchecking VNET...")
    $vn = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $VNET
    if($vn){Write-Output ("`t`tfound VNET.")}
    else{Write-Error -Message ("Could not find Virtual Network " + [char]34 + $VNET + [char]34 + " in Resource Group " + [char]34 + $ResourceGroup + [char]34 + ".");exit}
    Write-Output ("`tchecking Public IP...")
    $pip = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroup -Name $PublicIp
    if($pip){Write-Output ("`t`tfound Public IP.")}
    else{Write-Error -Message ("Could not find Public IP Address " + [char]34 + $PublicIp + [char]34 + " in Resource Group " + [char]34 + $ResourceGroup + [char]34 + ".");exit}
    $azfw.Allocate($vn,@($pip))
    Set-AzFirewall -AzureFirewall $azfw
}