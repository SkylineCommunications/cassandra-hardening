#Requires -RunAsAdministrator

<#
.SYNOPSIS
    A script to update the Apache Cassandra version.
.DESCRIPTION
    This script will update the Cassandra version, based on new binaries provided by the -binaries parameter.
    A backup of the old Cassandra installation is created by renaming the current -cassandra_home folder to <cassandra_home>_bak_<date>
.PARAMETER binaries
    The path to the new Apache Cassandra binaries. These will be installed in the -cassandra_home folder.
.PARAMETER cassandra_home
    The path to the current Cassandra installation folder.
.EXAMPLE
    PS> .\Update-CassandraVersion.ps1 -binaries "C:\Users\UserName\Downloads\apache-cassandra-3.11.12"
.LINK
    Find the latest version on GitHub: https://github.com/SkylineCommunications/cassandra-hardening
#>
param (
    # Path to the new Cassandra binaries
    [Parameter(Mandatory)]
    [String]$binaries, 
    # Path to the Cassandra installation folder.
    [String]$cassandra_home = 'C:\Program Files\Cassandra',
    # Displays this help
    [Switch]$help
)

# Constants
$cassandra_service_name = 'cassandra'
$slkill_path = 'C:\Skyline DataMiner\Files\SLKill.exe'
$cassandra_home_bak = "$cassandra_home" + '_bak_' + (Get-Date -Format 'yyyy_MM_dd_HH_mm_ss')

#region Functions

if ($help -eq $True) {
    Get-Help ".\\$($MyInvocation.MyCommand.Name)" -Detailed
    return
}

Function Stop-DataMiner {
    Write-Host 'Stopping DataMiner'
    Start-Process -NoNewWindow -FilePath $slkill_path -ArgumentList '-f SL' -Wait
}

#endregion

if ([string]::IsNullOrEmpty($binaries)) {
    throw 'Please provide the -binaries argument, pointing to the new Cassandra binaries'
}

$foundBinaries = Test-Path $binaries

if ($foundBinaries -eq $False) {
    throw "Cannot continue, $binaries does not exist"
}

Write-Host "New Cassandra binaries are located in: $binaries"

$foundCassandra = Test-Path $cassandra_home

if ($foundCassandra -eq $False) {
    throw "Cannot continue, $cassandra_home does not exist"
}

$foundDataMiner = Test-Path 'C:\Skyline DataMiner'

if ($foundDataMiner -eq $True) {
    Stop-DataMiner
}

$service = Get-Service -Name $cassandra_service_name -ErrorAction SilentlyContinue

if ($service.Length -gt 0) {
    Write-Host "Stopping the $cassandra_service_name service"
    Stop-Service -Name $cassandra_service_name
}

Write-Host "Renaming $cassandra_home to $cassandra_home_bak"
Rename-Item $cassandra_home $cassandra_home_bak

Write-Host "Copying new Cassandra binaries to $cassandra_home"
Copy-Item $binaries -Destination $cassandra_home -Recurse

Write-Host 'Restoring Java'
Copy-Item ($cassandra_home_bak + '\Java') -Destination $cassandra_home -Recurse

Write-Host 'Restoring Deamon'
Copy-Item ($cassandra_home_bak + '\bin\daemon') -Destination ($cassandra_home + '\bin') -Recurse

Write-Host 'Restoring DevCenter'
Copy-Item ($cassandra_home_bak + '\DevCenter') -Destination $cassandra_home -Recurse

Write-Host 'Restoring cassandra.yaml'
Copy-Item ($cassandra_home_bak + '\conf\cassandra.yaml') -Destination ($cassandra_home + '\conf')

# Set CASSANDRA_HOME & JAVA_HOME machine wide
[System.Environment]::SetEnvironmentVariable('CASSANDRA_HOME', 'C:\progra~1\Cassandra\', [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable('JAVA_HOME', 'C:\progra~1\Cassandra\Java\', [System.EnvironmentVariableTarget]::Machine)

# Also set them in this session
$env:CASSANDRA_HOME = 'C:\progra~1\Cassandra\'
$env:JAVA_HOME = 'C:\progra~1\Cassandra\Java\'



#Write-Host 'Updating Cassandra service'
#Invoke-Expression 'C:\progra~1\Cassandra\bin\cassandra.ps1 -install | Write-Host'
#Start-Sleep -Seconds 5
#Write-Host 'Cassandra service is updated'

Write-Host 'Installing Cassandra service...'
Invoke-Expression 'C:\progra~1\Cassandra\bin\cassandra.ps1 -install | Write-Host'
Start-Sleep -Seconds 5

Write-Host 'Checking for Cassandra service...'
Get-Service | Where-Object { $_.DisplayName -like "*cassandra*" }

Write-Host 'Setting Cassandra service logon to LocalSystem...'
Start-Process -FilePath "sc.exe" -ArgumentList 'config', 'cassandra', 'obj= "LocalSystem"', 'password= ""' -NoNewWindow -Wait

Start-Sleep -Seconds 2
Write-Host 'Cassandra service is updated'


Write-Host 'Setting Jvm registry key to correct path'
Set-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Apache Software Foundation\Procrun 2.0\cassandra\Parameters\Java' -Name 'Jvm' -Value 'C:\Program Files\Cassandra\Java\jre\bin\server\jvm.dll'

Write-Host 'Enabling Cassandra startup setting: ignorereplayerrors=true'
$options = Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Apache Software Foundation\Procrun 2.0\cassandra\Parameters\Java' -Name 'Options'

$ignoreReplayErrors = $options.Options.Contains('-Dcassandra.commitlog.ignorereplayerrors=true')
if ($ignoreReplayErrors -eq $False) {
    $options.Options += '-Dcassandra.commitlog.ignorereplayerrors=true'
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Apache Software Foundation\Procrun 2.0\cassandra\Parameters\Java' -Name 'Options' -Value $options.Options
}
else {
    Write-Host 'Replay errors are already ignored'
}

Write-Host "Starting the $cassandra_service_name service"
Start-Service -Name $cassandra_service_name

$location = Get-Location
Set-Location 'C:\progra~1\Cassandra\bin\'
$newVersion = .\nodetool version
Set-Location $location.Path

if ($foundDataMiner -eq $True) {
    Write-Host 'Starting DataMiner again'
    Start-Service -Name 'SLDataMiner'
}

Write-Host "Cassandra version was updated to $newVersion, please verify the $cassandra_service_name service is running"