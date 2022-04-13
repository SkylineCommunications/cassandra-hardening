#Requires -RunAsAdministrator
param ($binaries, $cassandra_home = 'C:\Program Files\Cassandra', $java_home = 'C:\Program Files\Cassandra\Java')

# Example usage: .\Update-CassandraJavaVersion.ps1 -binaries "C:\Users\UserName\Downloads\Java"

# Constants
Set-Variable cassandra_service_name -Option Constant -Value 'cassandra'
Set-Variable slkill_path -Option Constant -Value 'C:\Skyline DataMiner\Files\SLKill.exe'
Set-Variable java_home_bak -Option Constant -Value ($java_home + '_bak')

#region Functions

Function Stop-DataMiner {
    Write-Host 'Stopping DataMiner'
    Start-Process -NoNewWindow -FilePath $slkill_path -ArgumentList '-f SL' -Wait
}

#endregion

if ([string]::IsNullOrEmpty($binaries)) {
    throw 'Please provide the -binaries argument, pointing to the new Java binaries'
}

$foundBinaries = Test-Path $binaries

if ($foundBinaries -eq $False) {
    throw "Cannot continue, $binaries does not exist"
}

Write-Host "New Java binaries are located in: $binaries"

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

Write-Host "Renaming $java_home to $java_home_bak"
Rename-Item $java_home $java_home_bak

Write-Host "Copying new Java binaries to $java_home"
Copy-Item $binaries -Destination $java_home -Recurse

Write-Host "Starting $cassandra_service_name service again"
Start-Service -Name $cassandra_service_name

if ($foundDataMiner -eq $True) {
    Write-Host 'Starting DataMiner again'
    Start-Service -Name 'SLDataMiner'
}

$location = Get-Location
Set-Location ($java_home + '\bin')
.\java.exe -version
Set-Location $location.Path

Write-Host 'Java version was updated'