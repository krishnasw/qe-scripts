Write-Output "
  PRE-REQUISITE:
- ZFSin should be installed:
- This script has to be run from the installation folder of zpool and zvol applications Or the location has to be included in the PATH variable"

# Function to find the secondary disk and return the deviceid
function Get-Second-PhysicalDrive
{
    $disks  = Get-WmiObject Win32_DiskDrive
    $diskcount = (Get-WmiObject Win32_DiskDrive | Measure-Object | Select-Object Count).count
    if($diskcount -le 1) {
        Write-Error 'Number of disks should be greater than 1 to continue run tests' -ErrorAction Stop
    }
    $pooldeviceid=""
    For ($i=0; $i -lt $diskcount; $i++)
    {
        $id=$disks.DeviceID[$i]
        $diskdeviceid = $id.Replace('\\.\', '')
        if ($diskdeviceid -like '*DRIVE1*')
        {
            $pooldeviceid = $diskdeviceid
        }
    }
    return $pooldeviceid
  }

  # Function to get the zpool status
function Get-ZPool-Status
{
    Param ([String] $commandname,[String] $arguments)
    $currentdirectory =  Get-Location
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo 
    $pinfo.UseShellExecute  = $false
    $pinfo.FileName = "$currentdirectory\$commandname"
    $pinfo.Arguments = $arguments 
    $pinfo.CreateNoWindow = $true 
    $pinfo.RedirectStandardOutput = $true 
    $pinfo.RedirectStandardError = $true

    $process= New-Object System.Diagnostics.Process 
    $process.StartInfo = $pinfo
    $process.Start() | Out-Null 
    $process.WaitForExit()
    $stdout=$process.StandardOutput.ReadToEnd() 
    $stderr=$process.StandardError.ReadToEnd()
    write-host("output=$stdout error=$stderr")
    if($stdout.Contains("ONLINE"))
    {
        return 10;
    }
    if($stderr.Contains("no pools"))
    {
        return 0;
    }
    else
    {
        return -99;
    }
}

#Function to Create a ZPool and single ZVol
function Create-ZVOL($drive,$size,$numberf_of_zvols)
{
#$Null = @(
#Check zfs is installed , any zpool with same name exists
$zpool_status = Get-ZPool-Status "zpool.exe" "status"
if($zpool_status -eq 10 )
{
    throw "Zpool with same name exists already"
} 
if($zpool_status -ne 0 )
{
    throw "Please install ZFSin to continue to run tests"
}
#Create zpool
Invoke-Expression "zpool.exe create -O dedup=on mypool $drive"
"Zpool got created "
Invoke-Expression "zpool status"
Invoke-Expression "zfs list"
Get-job | Remove-Job
Write-Host "Going to create zvols "
$vol_list = @()

#Create zvols 

1..$numberf_of_zvols | %{
  # Define what each job does
  $ScriptBlock = {  
    param($i,$size) 
    Invoke-Expression "zfs create -V $size.gb mypool/vol$i"
    $vol_list+="mypool/vol$i"
    "Created zvol mypool/vol$i"
  }

  # Execute the jobs in parallel
  Start-Job $ScriptBlock -ArgumentList @($_,$size)
}
# Wait for it all to complete
While (Get-Job -State "Running")
{
Get-Job | Receive-Job 
}

# Getting the information back from the jobs
Get-Job | Receive-Job


#Verify zvols are created successfully
Invoke-Expression "zfs list"
#Get-Disk
$out=@(Get-Disk -FriendlyName ZVOL*)
$no_zvols_created=$out.length
if($no_zvols_created -ne $numberf_of_zvols){
   write-host("ZVol creation is not succesful")
}else {
   write-host("$no_zvols_createds ZVols created successfully")
}
#)
#return $vol_list
} 


#Function to Resize the zvol
Function Resize-Zvol($size,$numberf_of_zvols)
{
"Resizing zvols to $size.gb"

Get-job | Remove-Job
Write-Host "Going to resize zvols "

#Create zvols 

1..$numberf_of_zvols | %{
  # Define what each job does
  $ScriptBlock = {  
    param($i,$size) 
    Invoke-Expression "zfs set volsize=$size.gb mypool/vol$i"
    "Resized zvol mypool/vol$i"
  }

  # Execute the jobs in parallel
  Start-Job $ScriptBlock -ArgumentList @($_,$size)
}
# Wait for it all to complete
While (Get-Job -State "Running")
{
Get-Job | Receive-Job 
}

# Getting the information back from the jobs
Get-Job | Receive-Job

#Verify zvols are resized successfully
Invoke-Expression "zfs list"
$size_in_bytes=((1073741824*$size)+4096)
$out=@(Get-Disk -FriendlyName *ZVOL* |Where-Object {$_.Size -eq $size_in_bytes})
$no_zvols_resized=$out.length
if($no_zvols_resized -ne $numberf_of_zvols){
   write-host("ZVOL resizing is not succesfull")
}else {
   write-host(" ZVOL resized successfully")
}
}

#Function to Delete the zvol
Function Delete-Zvol($numberf_of_zvols)
{
"Deleting zvols"

Get-job | Remove-Job
Write-Host "Going to delete zvols "

#Create zvols 

1..$numberf_of_zvols | %{
  # Define what each job does
  $ScriptBlock = {  
    param($i) 
    Invoke-Expression "zfs destroy
     mypool/vol$i"
    "Deleted zvol mypool/vol$i"
  }

  # Execute the jobs in parallel
  Start-Job $ScriptBlock -ArgumentList @($_)
}
# Wait for it all to complete
While (Get-Job -State "Running")
{
Get-Job | Receive-Job 
}

# Getting the information back from the jobs
Get-Job | Receive-Job

#Verify zvols are resized successfully
Invoke-Expression "zfs list"
$out=@(Get-Disk -FriendlyName *ZVOL* )
$no_zvols_resized=$out.length
if($no_zvols_resized -ne 0){
   write-host("ZVOL deleting is not succesfull")
}else {
   write-host(" ZVOL deleted successfully")
}
}

$ST=(Get-Date).Millisecond
$no_of_zvol=16
$size_of_zvol_in_gb=5
$drive = Get-Second-PhysicalDrive
Create-Zvol $drive $size_of_zvol_in_gb $no_of_zvol
$new_size=($size_of_zvol_in_gb*2)
Resize-Zvol $new_size $no_of_zvol
Delete-Zvol $no_of_zvol
$ET=(Get-Date).Millisecond
Write-Host "Consumed $ET-$ST milliseconds"

Invoke-Expression "zpool destroy mypool"