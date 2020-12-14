#Custom script to perform the following upon VM deployment:
#- Move CD drive to W.
#- Format data disks, assign letter and name based on disk configuration passed as parameter
#
#Written by Fabien Gilbert, Applied Information Sciences in February of 2018

Set-StrictMode -Version 3

try{	
	Write-Output "Change CD drive letter to W"
	Write-Verbose -Message "[Start]::Changing CD drive letter to W..."
    $CDDrive = Get-WmiObject -Class Win32_volume -Filter "DriveType = '5'"
    if($CDDrive){$CDDrive | Set-WmiInstance -Arguments @{DriveLetter='W:'}}
    Write-Verbose -Message "[Finish]::Changed CD drive letter to W"

    #Extend C drive if necessary
    $CPartition = Get-Partition -DriveLetter C
    $CSupportedSize = Get-PartitionSupportedSize -DriveLetter C
    if(($CSupportedSize.SizeMax - $CPartition.Size) -ge 1GB)
    {
        Resize-Partition -DriveLetter C -Size $CSupportedSize.SizeMax
    }

    Write-Output "Initializing Disks"
	$disks = Get-Disk | Where-Object partitionstyle -eq 'raw' | Sort-Object number

    #Import disk configuration
    $CurrentFolder = Split-Path $script:MyInvocation.MyCommand.Path
    $DiskConfigFilePath = ($CurrentFolder + "\DiskConfig_" + $env:COMPUTERNAME + ".json")
    $CurrentDiskConfiguration = Get-Content -Path $DiskConfigFilePath | Out-String | ConvertFrom-Json
    #Create base disk configuration by default
    if(!($CurrentDiskConfiguration))
    {
        $CurrentDiskConfiguration = @()
        $i=70
        $DiskCount=1
        do
        {        
            
            $DiskID=switch($DiskCount){{$_ -le 9} {"0" + [string]$DiskCount}                              
                                Default {[string]$DiskCount}}
            $CurrentDiskConfiguration += New-Object -TypeName PSObject -Property @{"LUN"=($DiskCount - 1)
                                                                                   "DiskLabel"=($env:COMPUTERNAME + "-DataDisk-" + $DiskID)
                                                                                   "DiskLetter"=[char]$i}                                                                                   
            $i++;$DiskCount++
        }
        until($i -gt 90)
    }
    #Format disks
    foreach ($disk in $disks)
    {
        $DiskLUN = [int]([regex]::Match($disk.Path,"[#]{1}\d{1,}[#]{1}").Value.Replace("#",""))
        $DiskConfig = $CurrentDiskConfiguration | Where-Object -Property LUN -EQ $DiskLUN
        if($DiskConfig){
            $disk | 
            Initialize-Disk -PartitionStyle GPT -PassThru |
            New-Partition -UseMaximumSize -DriveLetter $DiskConfig.DiskLetter |
            Format-Volume -FileSystem NTFS -NewFileSystemLabel $DiskConfig.DiskLabel -Confirm:$false -Force            
        }
    }
} #end try
catch{
	Write-Error -Message "Caught an exception:"
	Write-Error -Message "Exception Type: $($_.Exception.GetType().FullName)"
	Write-Error -Message "Exception Message: $($_.Exception.Message)"
}