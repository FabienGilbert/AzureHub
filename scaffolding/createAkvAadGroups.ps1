#Create Azure AD Groups and outputs their Object Ids
#Fabien Gilbert, AIS, 06/2020
Param
(
    #Naming convention Enterprise Prefix
    [Parameter(Mandatory = $true, 
        Position = 0)]
    [ValidateNotNullOrEmpty()]      
    [String]
    $EnterprisePrefix,

    #Naming convention Subscription Ordinal Prefix
    [Parameter(Mandatory = $true, 
        Position = 1)]
    [ValidatePattern("^[S]\d{2}$")]    
    [String]
    $SubscriptionOrdinalPrefix   
)

#Declare Azure AD Groups
$aadGroups = ("[
    {
        'groupName': '" + $EnterprisePrefix + "-AKV-" + $SubscriptionOrdinalPrefix + "-READ',
        'groupDescription': 'Group with read-only access in " + $SubscriptionOrdinalPrefix + " subscription key vault access policies.',
        'groupObjectId': '',
        'armParameter': 'keyVaultReadOnlyAccessGroupId'
    },
    {
        'groupName': '" + $EnterprisePrefix + "-AKV-" + $SubscriptionOrdinalPrefix + "-ALL',
        'groupDescription': 'Group with full access access in " + $SubscriptionOrdinalPrefix + " subscription key vault access policies.',
        'groupObjectId': '',
        'armParameter': 'keyVaultFullAccessGroupId'
    }
]") | ConvertFrom-Json

#Create Azure AD Groups and get their Object Id
foreach ($aadGroup in ($aadGroups | Where-Object { !($_.groupObjectId) })) {
    #Get existing Azure AD Group
    Write-Output ("Getting Azure AD Group Name " + [char]34 + $aadGroup.groupName + [char]34 + "...")
    $grp = $null
    $grp = Get-AzADGroup -DisplayName $aadGroup.groupName
    if ($grp) {
        Write-Output ("Azure AD Group Name " + [char]34 + $aadGroup.groupName + [char]34 + " already exists.")
    }
    else{        
        Write-Output ("Creating Azure AD Group Name " + [char]34 + $aadGroup.groupName + [char]34 + "...")
        $grp = New-AzADGroup -DisplayName $aadGroup.groupName -MailNickname $aadGroup.groupName -Description $aadGroup.groupDescription
    }
    if ($grp.Id) {
        $aadGroup.groupObjectId = $grp.Id
    }
    else {
        Write-Error -Message ("could not get/create Azure AD Group " + [char]34 + $aadGroup.groupName + [char]34 + " and get its OjectId.")
        Exit
    }
}

#Send the value of the group object ID for each group created as a pipeline variable for use by the ARM template
foreach ($grp in $aadGroups) {
    Write-Host ($grp.armParameter + " set to " + $grp.groupObjectId)
    Write-Host ("##vso[task.setvariable variable=" + $grp.armParameter + ";]" + $grp.groupObjectId)
}

