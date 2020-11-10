#Create Management Group, join subscription to it and output its name 
#Fabien Gilbert, AIS, 11/2020
Param
(
    #Naming convention Enterprise Prefix
    [Parameter(Mandatory = $true, 
        Position = 0)]
    [ValidateNotNullOrEmpty()]      
    [String]
    $EnterprisePrefix,

    #Tenant Root Management Group Resource Id
    [Parameter(Mandatory = $true, 
        Position = 1)]
    [ValidateNotNullOrEmpty()]    
    [String]
    $rootMgpName,    

    #HUB Subscription Id
    [Parameter(Mandatory = $true, 
        Position = 2)]
    [ValidateNotNullOrEmpty()]      
    [String]
    $hubSubscriptionId
)

# Define Management Groups, associated subscriptions and Azure AD Groups (for RBAC)
$managementGroups = "[
    {
        'displayName': 'Tenant Root Group',
        'name': '" + $rootMgpName + "',
        'childSubscriptions': [],
        'aadGroups': [
            {
                'groupName': '" + $EnterprisePrefix + "-MGP-ROOT-READ',
                'groupDescription': 'Group with Reader assignment over Tenant Root Group.',
                'armParameter': 'rootMgpRbacReaderGroupId'
            },            
            {
                'groupName': '" + $EnterprisePrefix + "-MGP-ROOT-CTRB',
                'groupDescription': 'Group with Contributor assignment over Tenant Root Group.',
                'armParameter': 'rootMgpRbacContributorGroupId'
            },            
            {
                'groupName': '" + $EnterprisePrefix + "-MGP-ROOT-OWNR',
                'groupDescription': 'Group with Owner assignment over Tenant Root Group.',
                'armParameter': 'rootMgpRbacOwnerGroupId'
            }
        ],
        'armParameter': ''
    },
    {
        'displayName': '" + $EnterprisePrefix + "-CORE-MGP',
        'name': '',
        'childSubscriptions': [
            {
                'id': '" + $hubSubscriptionId + "'
            }
        ],
        'aadGroups': [
            {
                'groupName': '" + $EnterprisePrefix + "-MGP-CORE-READ',
                'groupDescription': 'Group with Reader assignment over " + $EnterprisePrefix + "-CORE-MGP Management Group.',
                'armParameter': 'coreMgpRbacReaderGroupId'
            },            
            {
                'groupName': '" + $EnterprisePrefix + "-MGP-CORE-CTRB',
                'groupDescription': 'Group with Contributor assignment over " + $EnterprisePrefix + "-CORE-MGP Management Group.',
                'armParameter': 'coreMgpRbacContributorGroupId'
            },            
            {
                'groupName': '" + $EnterprisePrefix + "-MGP-CORE-OWNR',
                'groupDescription': 'Group with Owner assignment over " + $EnterprisePrefix + "-CORE-MGP Management Group.',
                'armParameter': 'coreMgpRbacOwnerGroupId'
            }
        ],
        'armParameter': 'coreMgpName'
    },
    {
        'displayName': '" + $EnterprisePrefix + "-LAB-MGP',
        'name': '',
        'childSubscriptions': [],
        'aadGroups': [
            {
                'groupName': '" + $EnterprisePrefix + "-MGP-LAB-READ',
                'groupDescription': 'Group with Reader assignment over " + $EnterprisePrefix + "-LAB-MGP Management Group.',
                'armParameter': 'labMgpRbacReaderGroupId'
            },            
            {
                'groupName': '" + $EnterprisePrefix + "-MGP-LAB-CTRB',
                'groupDescription': 'Group with Contributor assignment over " + $EnterprisePrefix + "-LAB-MGP Management Group.',
                'armParameter': 'labMgpRbacContributorGroupId'
            },            
            {
                'groupName': '" + $EnterprisePrefix + "-MGP-LAB-OWNR',
                'groupDescription': 'Group with Owner assignment over " + $EnterprisePrefix + "-LAB-MGP Management Group.',
                'armParameter': 'labMgpRbacOwnerGroupId'
            }
        ],
        'armParameter': 'labMgpName'
    }
]" | ConvertFrom-Json
$rootMgpResourceId = ("/providers/Microsoft.Management/managementGroups/" + $rootMgpName)

foreach ($managementGroup in $managementGroups) {
    # If Management Group Name/Id is not specified, attempt to create the Management Group
    if ($managementGroup.name) {
        Write-Output ("Getting Management Group Name " + [char]34 + $managementGroup.name + [char]34 + "...")
        $mgp = Get-AzManagementGroup -GroupName $managementGroup.name
    }
    else{
        # Check for Management Group existence
        $mgp = $null
        Write-Output ("Getting Management Group DisplayName " + [char]34 + $managementGroup.displayName + [char]34 + "...")
        $mgp = Get-AzManagementGroup -Expand $rootMgpName | Select-Object -ExpandProperty Children | Where-Object -Property DisplayName -EQ -Value $managementGroup.displayName   
        # Create Management Group if it doesn't exist
        if ($mgp) {
            Write-Output ("Management Group DisplayName " + [char]34 + $mgp.DisplayName + [char]34 + " already exists with Name " + [char]34 + $mgp.Name + [char]34 + ".")
        }
        else {       
            $randomGuid = New-Guid 
            Write-Output ("Creating Management Group DisplayName " + [char]34 + $managementGroup.displayName + [char]34 + " Name " + [char]34 + $randomGuid.Guid + [char]34 + " under parent Management Group " + [char]34 + $rootMgpResourceId + [char]34 + "...")
            $mgp = New-AzManagementGroup -GroupName $randomGuid.Guid -DisplayName $managementGroup.displayName -ParentId $rootMgpResourceId
        }
    }

    # Add Subscription to Management Group
    if ($mgp) {
        # Loop through all child subscriptions
        foreach ($childSub in $managementGroup.childSubscriptions) {
            $sub = Get-AzSubscription -SubscriptionId $childSub.id
            if ($sub) {
                $mgpChildren = Get-AzManagementGroup -GroupName $mgp.Name -Expand | Select-Object -ExpandProperty Children
                if ($mgpChildren | Where-Object -Property Name -EQ -Value $sub.SubscriptionId) {
                    Write-Output ("Subscription Name " + [char]34 + $sub.Name + [char]34 + " already children of Management Group " + [char]34 + $mgp.DisplayName + [char]34 + ".")
                }
                else {        
                    Write-Output ("Adding Subscription Name " + [char]34 + $sub.Name + [char]34 + " as children of Management Group " + [char]34 + $mgp.DisplayName + [char]34 + "...")
                    New-AzManagementGroupSubscription -GroupName $mgp.Name -SubscriptionId $sub.SubscriptionId         
                }
            }
            else {
                Write-Error -Message ("Could not find subscription id " + [char]34 + $childSub.id + [char]34 + ".")
            }
        }
    }
    else {
        Write-Error -Message ("Subscriptions could not be added to Management Group DisplayName " + [char]34 + $managementGroup.displayName + [char]34 + " because it could not be found.")
    }

    # Outputs Management Group Name
    if ($managementGroup.armParameter) {
        Write-Host ($managementGroup.armParameter + " set to " + $mgp.Name)
        Write-Host ("##vso[task.setvariable variable=" + $managementGroup.armParameter + ";]" + $mgp.Name)
    }

    # Create Azure AD Groups for RBAC
    foreach ($aadGroup in $managementGroup.aadGroups) {
        #Get existing Azure AD Group
        Write-Output ("Getting Azure AD Group Name " + [char]34 + $aadGroup.groupName + [char]34 + "...")
        $grp = $null
        $grp = Get-AzADGroup -DisplayName $aadGroup.groupName
        if ($grp) {
            Write-Output ("Azure AD Group Name " + [char]34 + $aadGroup.groupName + [char]34 + " already exists.")
        }
        else {        
            Write-Output ("Creating Azure AD Group Name " + [char]34 + $aadGroup.groupName + [char]34 + "...")
            $grp = New-AzADGroup -DisplayName $aadGroup.groupName -MailNickname $aadGroup.groupName -Description $aadGroup.groupDescription
        }
        if ($grp.Id) {
            Write-Host ($aadGroup.armParameter + " set to " + $grp.Id)
            Write-Host ("##vso[task.setvariable variable=" + $aadGroup.armParameter + ";]" + $grp.Id)
        }
        else {
            Write-Error -Message ("could not get/create Azure AD Group " + [char]34 + $aadGroup.groupName + [char]34 + " and get its OjectId.")
            Exit
        }
    }
}