###################################################################
# Kick-off ARM NSG Deployment                                     #
#  steps:                                                         #
#  - Import NSG parameter file.                                   #           
#  - Pass NSG parameters inline                                   #
#  - Pass security rules JSON parameter file as parameter file    #
#  - Kick-off ARM template deployment.                            #
###################################################################

Param
(
    #NsgParameterFilePath
    [Parameter(Position = 0,
        HelpMessage = "NSG Parameters JSON file path",
        Mandatory = $true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $NsgParameterFilePath,

    #SecurityRulesFilePath
    [Parameter(Position = 1,
        HelpMessage = "Security Rules Parameters JSON file path",
        Mandatory = $true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $SecurityRulesFilePath,

    #armTemplateFilePath
    [Parameter(Position = 2,
        HelpMessage = "NSG ARM Template file path",
        Mandatory = $true)]
    [ValidateScript({Test-Path $_})]
    [String]
    $armTemplateFilePath,

    #deploymentLocation
    [Parameter(Position = 3,
        HelpMessage = "Deployment location",
        Mandatory = $true)]
    [String]
    $deploymentLocation
)

# Import NSG Parameters JSON file
Write-Output ("Importing JSON file " + [char]34 + $NsgParameterFilePath + [char]34 + "...")
$nsgParameters = Get-Content -Path $NsgParameterFilePath | ConvertFrom-Json
if(!($nsgParameters)){Write-Error -Message ("Could not import JSON file " + [char]34 + $NsgParameterFilePath + [char]34);exit}
$p = $nsgParameters.parameters

# Turn NSG parameters into inline parameters
$inlineParams = ""
$paramList = $p | Get-Member -MemberType NoteProperty
foreach($param in $paramList ){    
    $inlineParams += (" -" + $param.Name + " " + [char]36 + "p." + $param.Name + ".value")
    # rebuild hashtables
    $paramValue = $p.($param.Name).value
    $paramValueMember = $paramValue | Get-Member
    if($paramValueMember | Where-Object {$_.TypeName -eq "System.Management.Automation.PSCustomObject"}){
        $newHash = @{}
        foreach($m in ($paramValue | Get-Member -MemberType NoteProperty)){$newHash.Add($m.Name,$paramValue.($m.Name))}
        $p.($param.Name).value = $newHash
    }
}

# Kick off NSG ARM Template deployment
$deploymentName = ("nsgSecurityRules_" + (Get-Date -UFormat %Y%m%d%H%M%S))
$deploymentCmd = ("New-AzDeployment -Name " + [char]36 + "deploymentName -Location " + [char]36 + "deploymentLocation -TemplateFile " + [char]36 + "armTemplateFilePath -TemplateParameterFile " + [char]36 + "SecurityRulesFilePath" + $inlineParams)
Write-Output ("Kicking off ARM template deployment with cmdlet: `r`n`r`n" + $deploymentCmd + "`r`n`r`n...")
Invoke-Expression -Command $deploymentCmd