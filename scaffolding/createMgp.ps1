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
    $SubscriptionOrdinalPrefix,

    #Parent Management Group Resource Id
    [Parameter(Mandatory = $true, 
        Position = 4)]
    [ValidateNotNullOrEmpty()]    
    [String]
    $ParentMgpResourceId
)

# Build names
$managementGroupName = ($EnterprisePrefix + "-" + $ManagementGroupNamePrefix + "-MGP")
$subscriptionName = ($EnterprisePrefix + "-" + $SubscriptionNamePrefix + "-" + $SubscriptionOrdinalPrefix.Replace("S","SUB-"))

# Check for Management Group existence
$mgp = $null
$mgp = Get-AzManagementGroup | Where-Object -Property DisplayName -EQ -Value $managementGroupName
# Create Management Group if it doesn't exist
if ($mgp) {
    Write-Output ("Management Group DisplayName " + [char]34 + $managementGroupName + [char]34 + " already exists with Name " + [char]34 + $mgp.Name + [char]34 + ".")
}
else {       
    $randomGuid = New-Guid 
    Write-Output ("Creating Management Group DisplayName " + [char]34 + $managementGroupName + [char]34 + " Name " + [char]34 + $randomGuid.Guid + [char]34 + " under parent Management Group " + [char]34 + $ParentMgpResourceId + [char]34 + "...")
    $mgp = New-AzManagementGroup -GroupName $randomGuid.Guid -DisplayName $managementGroupName -ParentId $ParentMgpResourceId
}

# Add Subscription to Management Group
if ($mgp) {
    $sub = Get-AzSubscription -SubscriptionName $subscriptionName
    if ($sub) {
        $mgpChildren = Get-AzManagementGroup -GroupName $mgp.Name -Expand | Select-Object -ExpandProperty Children
        if($mgpChildren | Where-Object -Property Name -EQ -Value $sub.SubscriptionId){
            Write-Output ("Subscription Name " + [char]34 + $sub.Name + [char]34 + " already children of Management Group " + [char]34 + $mgp.DisplayName + [char]34 + ".")
        }
        else{        
            Write-Output ("Adding Subscription Name " + [char]34 + $sub.Name + [char]34 + " as children of Management Group " + [char]34 + $mgp.DisplayName + [char]34 + "...")
            New-AzManagementGroupSubscription -GroupName $mgp.Name -SubscriptionId $sub.SubscriptionId         
        }
    }
    else {
        Write-Error -Message ("Could not find subscription name " + [char]34 + $sub.Name + [char]34 + ".")
    }
}
else {
    Write-Error -Message ("Management Group DisplayName " + [char]34 + $managementGroupName + [char]34 + " could not be created under parent Management Group " + [char]34 + $ParentMgpResourceId + [char]34 + ".")
}

# Outputs Management Group Name and Subscription Id
Write-Host ("mgpName set to " + $mgp.Name)
Write-Host ("##vso[task.setvariable variable=mgpName;]" + $mgp.Name)
Write-Host ("subscriptionId set to " + $sub.SubscriptionId)
Write-Host ("##vso[task.setvariable variable=subscriptionId;]" + $sub.SubscriptionId)