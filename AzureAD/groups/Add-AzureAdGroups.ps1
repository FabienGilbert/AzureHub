# Create Azure AD Groups and add members
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
$param = Get-Content -Path $ParameterFilePath | ConvertFrom-Json
if (!($param)) { Write-Output ("Failed " + $resourceType + " JSON parameter file " + [char]34 + $ParameterFilePath + [char]34 + ". Aborting."); exit }
# Loop through groups
foreach ($group in $param) {
    $aadGroup = $Null
    $aadGroup = Get-AzADGroup -DisplayName $group.groupName -ErrorAction:SilentlyContinue
    Write-Output ("`r`nAzure AD Group " + [char]34 + $group.groupName + [char]34 + "...")
    if (!($aadGroup)) {
        Write-Output "`tCreating Azure AD Group..."
        $aadGroup = New-AzADGroup -DisplayName $group.groupName -Description $group.description -MailNickname $group.groupName.Replace(" ", "")
        if ($aadGroup) { Write-Output ("`tcreated with Id " + $aadGroup.Id) } 
        else { Write-Output "`tfailed to get new group. Exiting."; exit }
    }
    $aadGroupMembers = Get-AzADGroupMember -GroupObjectId $aadGroup.Id
    #Adding Azure AD User group members
    foreach ($aadUser in $group.members.azureAdUsers) {
        $aadUserObject = $null; $addMember = $null
        if (!($aadGroupMembers | Where-Object -Property userPrincipalName -EQ $aadUser.userPrincipalName)) {
            Write-Output ("`tadding member Azure AD User " + [char]34 + $aadUser.userPrincipalName + [char]34 + "...")
            $aadUserObject = Get-AzADUser -ObjectId $aadUser.userPrincipalName
            if ($aadUserObject) {
                $addMember = Add-AzADGroupMember -TargetGroupObjectId $aadGroup.Id -MemberObjectId $aadUserObject.Id
            }
            else {
                Write-Output ("`t`tcould not find Azure AD User.")
            }
        }
    }
    #Adding Azure AD App Registration members
    foreach ($appReg in $group.members.appRegistations) {
        $appRegSvc = $null
        $appRegSvc = Get-AzADServicePrincipal -DisplayName $appreg.name
        if ($appRegSvc) {
            if (!($aadGroupMembers | Where-Object -Property Id -EQ $appRegSvc.Id)) {
                Write-Output ("`tadding member Azure App Registration " + [char]34 + $appRegSvc.DisplayName + [char]34 + "...")
                $addMember = Add-AzADGroupMember -TargetGroupObjectId $aadGroup.Id -MemberObjectId $appRegSvc.Id          
            }
        }
        else { Write-Error -Message ("Could not find App Registration " + [char]34 + $appreg.name + [char]34 + ".") }            
    }
}