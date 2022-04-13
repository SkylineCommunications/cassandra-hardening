#Requires -RunAsAdministrator
param ($binaries, $cassandra_home = 'C:\Program Files\Cassandra')

# Example usage: .\update-cassandra.ps1 -binaries "C:\Users\UserName\Downloads\apache-cassandra-3.11.12"
# Note the contents of the $binaries path should be the bin/conf/tools/... folders from Cassandra

# Constants
Set-Variable cassandra_service_name -Option Constant -Value 'cassandra'
Set-Variable slkill_path -Option Constant -Value 'C:\Skyline DataMiner\Files\SLKill.exe'
Set-Variable cassandra_home_bak -Option Constant -Value ($cassandra_home + '_bak')

#region Functions

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

Write-Host "Cassandra binaries are located in: $binaries"

$foundCassandra = Test-Path $cassandra_home

if ($foundCassandra -eq $False) {
    throw "Cannot continue, $cassandra_home does not exist"
}

$foundDataMiner = Test-Path 'C:\Skyline DataMiner'

if ($foundDataMiner -eq $True) {
    Stop-DataMiner
}

$service = Get-Service -Name W32Time -ErrorAction SilentlyContinue

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

Write-Host 'Updating Cassandra service'
Invoke-Expression 'C:\progra~1\Cassandra\bin\cassandra.ps1 -install | Write-Host'
Start-Sleep -Seconds 5
Write-Host 'Cassandra service is updated'

Write-Host 'Setting Jvm registry key to correct path'
Set-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Apache Software Foundation\Procrun 2.0\cassandra\Parameters\Java' -Name 'Jvm' -Value 'C:\Program Files\Cassandra\Java\bin\server\jvm.dll'

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
cd 'C:\progra~1\Cassandra\bin\'
.\nodetool version
cd $location.Path

Write-Host 'Cassandra was updated, check if the service is running'