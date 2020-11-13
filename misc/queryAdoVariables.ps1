# Query Azure DevOps Variables groups through the API
Param
(
    #Azure DevOps Personal Access Token
    [Parameter(Mandatory = $true, 
        Position = 0)]
    [ValidateNotNullOrEmpty()]      
    [String]
    $adoPat,

    #Organization name
    [Parameter(Mandatory = $true, 
        Position = 1)]
    [ValidateNotNullOrEmpty()]      
    [String]
    $organizationName,

    #Project name
    [Parameter(Mandatory = $true, 
        Position = 1)]
    [ValidateNotNullOrEmpty()]      
    [String]
    $projectName,

    #Variable group name
    [Parameter(Mandatory = $true, 
        Position = 2)]
    [ValidateNotNullOrEmpty()]      
    [String]
    $variableGroupName 
)

#Build authentication header
$AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($adoPat)")) }
#DevOps URI
$UriOrga = "https://dev.azure.com/$($organizationName)/" 

#Get project list
$uriAccount = $UriOrga + "_apis/projects?api-version=5.1"
$projects = Invoke-RestMethod -Uri $uriAccount -Method get -Headers $AzureDevOpsAuthenicationHeader 
if(!($projects)){
    Write-Error -Message ("No project could be found at " + $UriOrga)
    exit
}

#Select desired project
$project = $projects.value | Where-Object -Property name -EQ -Value $projectName
if(!($project)){
    $projectString = ($projects.value | Select-Object -ExpandProperty Name) -join ", "
    Write-Error -Message ("Project " + [char]34 + $projectName + [char]34 + " could not be found in projects " + $projectString + " at " + $UriOrga + ".")
    exit
}

#Get variable group
$uriVariablesGroup = $UriOrga + "/" + $project.name + "/_apis/distributedtask/variablegroups?groupName=" + $variableGroupName + "*&queryOrder=IdDescending&api-version=5.0-preview.1"
$variableGroup = Invoke-RestMethod -Uri $uriVariablesGroup -Method get -Headers $AzureDevOpsAuthenicationHeader
if($variableGroup.value.variables){
    $variableMembers = $variableGroup.value.variables | Get-Member -MemberType NoteProperty
    $variableHash = @{}
    foreach($variableMember in $variableMembers){
        $variableValue = $variableGroup.value.variables.($variableMember.Name).value
        #Convert JSON to array if variable is an array
        if($variableValue.Substring(0,1) -eq "[" -and $variableValue.Substring($variableValue.Length - 1) -eq "]"){
            $variableValue = @(
                (ConvertFrom-Json -InputObject $variableValue)
            )
        }
        $variableHash.Add($variableMember.Name,$variableValue)        
    }
    #Output variables hash
    $variableHash
}
else{
    Write-Error -Message ("Variable group " + [char]34 + $variableGroupName + [char]34 + " could not be found under project " + $project.name + " at " + $UriOrga + ".")
}