#Requires -RunAsAdministrator

<#
.SYNOPSIS
    A script to update the Java version used by Cassandra.
.DESCRIPTION
    This script will update the Java version used Cassandra, based on new Java binaries provided by the -binaries parameter.
    A backup of the old Java installation is created by renaming the current -java_home folder to <java_home>_bak_<date>
.PARAMETER binaries
    The path to the new Java OpenJDK JRE binaries. These will be installed in the -java_home folder.
.PARAMETER cassandra_home
    The path to the current Cassandra installation folder.
.PARAMETER java_home
    The path to the current Java installation folder.
.EXAMPLE
    PS> .\Update-CassandraJavaVersion.ps1 -binaries "C:\Users\UserName\Downloads\Java"
.LINK
    Find the latest version on GitHub: https://github.com/SkylineCommunications/cassandra-hardening
#>
param (
    # Path to the new Java binaries
    [Parameter(Mandatory)]
    [String]$binaries,
    # Path to the Cassandra installation folder. Default: C:\Program Files\Cassandra
    [String]$cassandra_home = 'C:\Program Files\Cassandra',
    # Path to the Java installation folder. Default: C:\Program Files\Cassandra\Java
    [String]$java_home = 'C:\Program Files\Cassandra\Java',
    # Shows this help menu
    [Switch]$help
)

# Constants
Set-Variable cassandra_service_name -Option Constant -Value 'cassandra'
Set-Variable slkill_path -Option Constant -Value 'C:\Skyline DataMiner\Files\SLKill.exe'
Set-Variable java_home_bak -Option Constant -Value ($java_home + '_bak_' + (Get-Date -Format 'yyyy_MM_dd_HH_mm_ss'))

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