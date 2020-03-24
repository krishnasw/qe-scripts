Write-Output "
  PRE-REQUISITE:
- ZFSin should be installed:
- This script has to be run from the installation folder of zpool and zvol applications Or the location has to be included in the PATH variable"

# Function to get the zpool status
# This script has to be run from the installation folder of zpool and zvol applications � Or the location has to be included in the PATH variable
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

function Create-ZVOL($drive,$size,$numberf_of_zvols)
{
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

#Create zvols 
$i=1
Do {
    Invoke-Expression "zfs create -V $size.gb mypool/vol$i"
    "Created zvol mypool/vol$i"
    $i++
    }
While ($i -le $numberf_of_zvols)

#Verify zvols are created successfully
Invoke-Expression "zfs list"
Get-Disk
$out=Get-Disk -FriendlyName ZVOL*
$no_zvols_created=$out.length
if($no_zvols_created -ne $numberf_of_zvols){
   write-host("ZVOL creation is not succesful")
}else {
   write-host("$numberf_of_zvols ZVOLs created successfully")
}
}

function Delete-ZVol
{
    #Delete zvol
    Invoke-Expression "zfs destroy -f mypool/vol1"
    "Deleted zvol mypool/vol1"

    #Verify if zvols are deleted successfully
    Invoke-Expression "zfs list"
    Get-Disk
    $out=Get-Disk -FriendlyName ZVOL*
    $no_zvols_created=$out.length
    if($no_zvols_created -eq 0){
        write-host("ZVol deleted successfully")
    }
    else {
        write-host("ZVol did not delete successfully")
    }
}

$no_of_zvol=1
$size_of_zvol_in_gb=5
$drive = Get-Second-PhysicalDrive
Create-Zvol $drive $size_of_zvol_in_gb $no_of_zvol

