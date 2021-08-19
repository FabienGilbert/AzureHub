# Create RBAC assignments through PowerShell. 
# Fabien Gilbert, Microsoft
[CmdletBinding()]
param (
    #ParameterFilePath
    [Parameter(Position = 0,
        HelpMessage = "Path to the JSON parameter file",
        Mandatory = $true)]
    [ValidateScript( { Test-Path $_ })]
    [String]
    $ParameterFilePath
)
# Import parameter file
Write-Output ("`r`nFile: " + $ParameterFilePath)
$rbacAssignments = $null
$rbacAssignments = Get-Content -Path $ParameterFilePath | ConvertFrom-Json
if ($rbacAssignments) {
    # Loop through scopes
    foreach ($rbacScope in $rbacAssignments) {
        if ($rbacScope.scopeId -and $rbacScope.roleAssignments) {
            Write-Output ("`t`tScope: " + $rbacScope.scopeId)
            foreach ($rbacAssignment in $rbacScope.roleAssignments) {
                $existingRoleAssignment = $null
                $existingRoleAssignment = Get-AzRoleAssignment -Scope $rbacScope.scopeId -ObjectId $rbacAssignment.principalId -RoleDefinitionName $rbacAssignment.role -ErrorAction:SilentlyContinue
                if (!($existingRoleAssignment)) {
                    Write-Output ("`t`t`tNew " + $rbacAssignment.role + " role assignment for principal name " + $rbacAssignment.principalName + "...")
                    $newRoleAssignment = New-AzRoleAssignment -Scope $rbacScope.scopeId -ObjectId $rbacAssignment.principalId -RoleDefinitionName $rbacAssignment.role    
                }
            }
        }
        else { Write-Output ("JSON file " + [char]34 + $ParameterFilePath + [char]34 + " does not have the expected structure.") }
    }
}
else { Write-Output ("Could not import JSON file " + [char]34 + $ParameterFilePath + [char]34 + ".") }
