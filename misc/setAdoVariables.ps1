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
        Position = 2)]
    [ValidateNotNullOrEmpty()]      
    [String]
    $projectName,

    #Variable group name
    [Parameter(Mandatory = $true, 
        Position = 3)]
    [ValidateNotNullOrEmpty()]      
    [String]
    $variableGroupName,

    #Variables
    [Parameter(Mandatory = $true, 
        Position = 4)]
    [ValidateNotNullOrEmpty()]      
    [Array]
    $Variables
)

#Build authentication header
$AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($adoPat)")) }
#DevOps URI
$UriOrga = "https://dev.azure.com/$($organizationName)/" 

#Get project list
$uriAccount = $UriOrga + "_apis/projects?api-version=5.1"
$projects = Invoke-RestMethod -Uri $uriAccount -Method get -Headers $AzureDevOpsAuthenicationHeader 
if (!($projects)) {
    Write-Error -Message ("No project could be found at " + $UriOrga)
    exit
}

#Select desired project
$project = $projects.value | Where-Object -Property name -EQ -Value $projectName
if (!($project)) {
    $projectString = ($projects.value | Select-Object -ExpandProperty Name) -join ", "
    Write-Error -Message ("Project " + [char]34 + $projectName + [char]34 + " could not be found in projects " + $projectString + " at " + $UriOrga + ".")
    exit
}

#Get variable group
$uriVariablesGroup = $UriOrga + "/" + $project.name + "/_apis/distributedtask/variablegroups?groupName=" + $variableGroupName + "*&queryOrder=IdDescending&api-version=5.0-preview.1"
$variableGroup = Invoke-RestMethod -Uri $uriVariablesGroup -Method get -Headers $AzureDevOpsAuthenicationHeader
if ($variableGroup.value.variables) {
    # Convert variables to desired structure
    $variableHash = @{
        "id" = $variableGroup.value.id 
        "name" = $variableGroup.value.name
        "description" = $variableGroup.value.description
        "type" = $variableGroup.value.type
        "variables" = @{"parameter"=@{"value"="1"}}
    }
    $variableMembers = $variables | Get-Member -MemberType NoteProperty
    foreach($variableMember in $variableMembers){
        $variableHash.variables.Add($variableMember.Name, @{"value" = ""<#$variables.($variableMember.Name)#>})        
    }
    #convert to JSON
    $requestBody = $variableHash | ConvertTo-Json -Depth 10
    Write-Output ("Updating variable group " + $variableGroup.value + " with " + @($variableMembers).Count + " variables...")
    #variable group API url
    $uriSetVariableGroup = $UriOrga + "/" + $project.name + "/_apis/distributedtask/variablegroups/" + $variableGroup.value.id + "?api-version=5.0-preview.1"
    #invoke API
    $setVariableGroup = Invoke-RestMethod -Uri $uriSetVariableGroup -Method Put -Headers $AzureDevOpsAuthenicationHeader -Body $requestBody -ContentType 'application/json'    
}
else {
    Write-Error -Message ("Variable group " + [char]34 + $variableGroupName + [char]34 + " could not be found under project " + $project.name + " at " + $UriOrga + ".")
}