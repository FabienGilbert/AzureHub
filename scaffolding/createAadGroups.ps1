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

    #Naming convention Management Group Name Prefix
    [Parameter(Mandatory = $true, 
        Position = 1)]
    [ValidateLength(3, 5)]  
    [String]
    $ManagementGroupNamePrefix,

    #Naming convention Subscription Name Prefix
    [Parameter(Mandatory = $true, 
        Position = 2)]
    [ValidateLength(3, 5)]  
    [String]
    $SubscriptionNamePrefix,

    #Naming convention Subscription Ordinal Prefix
    [Parameter(Mandatory = $true, 
        Position = 3)]
    [ValidatePattern("^[S]\d{2}$")]    
    [String]
    $SubscriptionOrdinalPrefix   
)

#Declare Azure AD Groups
$aadGroups = ("[
    {
        'groupName': '" + $EnterprisePrefix + "-MGP-" + $ManagementGroupNamePrefix + "-READ',
        'groupDescription': 'Group with Reader RBAC assignment on " + $ManagementGroupNamePrefix + " Management Group',
        'groupObjectId': '',
        'armParameter': 'mgpRbacReaderGroupId'
    },
    {
        'groupName': '" + $EnterprisePrefix + "-MGP-" + $ManagementGroupNamePrefix + "-CTRB',
        'groupDescription': 'Group with Contributor RBAC assignment on " + $ManagementGroupNamePrefix + " Management Group',
        'groupObjectId': '',
        'armParameter': 'mgpRbacContributorGroupId'
    },
    {
        'groupName': '" + $EnterprisePrefix + "-MGP-" + $ManagementGroupNamePrefix + "-OWNR',
        'groupDescription': 'Group with Owner RBAC assignment on " + $ManagementGroupNamePrefix + " Management Group',
        'groupObjectId': '',
        'armParameter': 'mgpRbacOwnerGroupId'
    },
    {
        'groupName': '" + $EnterprisePrefix + "-AKV-" + $SubscriptionOrdinalPrefix + "-READ',
        'groupDescription': 'Group with read-only access in " + $SubscriptionNamePrefix + " subscription key vault access policies.',
        'groupObjectId': '',
        'armParameter': 'keyVaultReadOnlyAccessGroupId'
    },
    {
        'groupName': '" + $EnterprisePrefix + "-AKV-" + $SubscriptionOrdinalPrefix + "-ALL',
        'groupDescription': 'Group with full access access in " + $SubscriptionNamePrefix + " subscription key vault access policies.',
        'groupObjectId': '',
        'armParameter': 'keyVaultFullAccessGroupId'
    }
]") | ConvertFrom-Json

#Create Azure AD Groups and get their Object Id
foreach ($aadGroup in ($aadGroups | Where-Object { !($_.groupObjectId) })) {
    #Get existing Azure AD Group
    $grp = $null
    $grp = Get-AzADGroup -DisplayName $aadGroup.groupName
    if (!($grp)) {
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

