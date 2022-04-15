#Requires -RunAsAdministrator

<#
.SYNOPSIS
    A script to change the LogonUser for the Cassandra service to a non-privileged account.
.DESCRIPTION
    This script will update the user running the Cassandra service.
    A new user (default name: cassandra_service) is created and granted Modify permissions on C:\Program Files\Cassandra and C:\ProgramData\Cassandra.
    A password of your choosing will be used. A strong, randomly generated password is recommended.
.EXAMPLE
    PS> .\Edit-CassandraServiceUser.ps1
.LINK
    Find the latest version on GitHub: https://github.com/SkylineCommunications/cassandra-hardening
#>
param (
    # Shows this help menu
    [Switch]$help
)

# Constants
Set-Variable cassandraServiceName -Option Constant -Value 'cassandra'
Set-Variable defaultUserName -Option Constant -Value 'cassandra_service'

if ($help -eq $True) {
    Get-Help ".\\$($MyInvocation.MyCommand.Name)" -Detailed
    return
}

#region Functions

Function Grant-ModifyPermission {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory = $true)][string]$Folder, 
        [Parameter(Mandatory = $true)][string]$UserName
    )

    Write-Host "Granting recursive modify permission to $($UserName) on folder $($Folder)"
    cmd.exe /c "icacls `"$($Folder)`" /grant $($UserName):(OI)(CI)M /T /q"
}

Function Grant-LogonAsServicePermission {
    PARAM(
        [string]$UserName
    )

    $computerName = ('{0}.{1}' -f $env:COMPUTERNAME.ToLower(), $env:USERDNSDOMAIN.ToLower())
    $tempPath = [System.IO.Path]::GetTempPath()
    $import = Join-Path -Path $tempPath -ChildPath 'import.inf'

    if (Test-Path $import) { 
        Remove-Item -Path $import -Force 
    }

    $export = Join-Path -Path $tempPath -ChildPath 'export.inf'

    if (Test-Path $export) { 
        Remove-Item -Path $export -Force 
    }

    $secedt = Join-Path -Path $tempPath -ChildPath 'secedt.sdb'

    if (Test-Path $secedt) { 
        Remove-Item -Path $secedt -Force 
    }

    try {
        Write-Host ('Granting SeServiceLogonRight to user account: {0} on host: {1}.' -f $UserName, $computerName)
        $sid = ((New-Object System.Security.Principal.NTAccount($UserName)).Translate([System.Security.Principal.SecurityIdentifier])).Value
        secedit /export /cfg $export
        $sids = (Select-String $export -Pattern 'SeServiceLogonRight').Line
        foreach ($line in @('[Unicode]', 'Unicode=yes', '[System Access]', '[Event Audit]', '[Registry Values]', '[Version]', "signature=`"`$CHICAGO$`"", 'Revision=1', '[Profile Description]', 'Description=GrantLogOnAsAService security template', '[Privilege Rights]', "$sids,*$sid")) {
            Add-Content $import $line
        }

        secedit /import /db $secedt /cfg $import
        secedit /configure /db $secedt
        gpupdate /force

        Remove-Item -Path $import -Force
        Remove-Item -Path $export -Force
        Remove-Item -Path $secedt -Force
    }
    catch {
        Write-Error "Failed to grant SeServiceLogonRight to user account: $UserName"
        throw
    }
}

#endregion

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -eq $false) {
    Write-Error 'Please execute this script with Administrator privileges'
    return
}

$service = Get-Service -Name $cassandraServiceName -ErrorAction SilentlyContinue

if ($null -eq $service) {
    # Service does not exist
    Write-Error "Service '$($cassandraServiceName)' does not exist, cannot continue"
    return
}

# Prompt for new user name
$userName = Read-Host -Prompt "Enter the name for the Cassandra service user [default: $($defaultUserName)]"

if ([string]::IsNullOrEmpty($userName)) {
    $userName = $defaultUserName
    Write-Host "Using the default username: $($userName)"
}

$localUser = Get-LocalUser $userName -ErrorAction 'silentlycontinue'

if ($null -ne $localUser) {
    Write-Error "A user named `'$($userName)`' already exists, use a different name"
    return
}

# Prompt for pwd
$password = ''
$passwordConfirmed = ''
$retry = $false
$pwd1_text = ''

do {
    if ($retry -eq $true) {
        Write-Host 'Passwords did not match, please try again.'
    }

    $password = Read-Host -AsSecureString 'Enter the password for the Cassandra service user'
    $passwordConfirmed = Read-Host -AsSecureString 'Confirm the password for the Cassandra service user'
    $retry = $true

    $pwd1_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
    $pwd2_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($passwordConfirmed))
}
while ($pwd1_text -ne $pwd2_text -Or [string]::IsNullOrEmpty($pwd1_text))


# Create the user in Windows
New-LocalUser $userName -Password $password -FullName $userName -Description 'User that Cassandra is run under' -PasswordNeverExpires -UserMayNotChangePassword
Start-Sleep -s 3

$localUser = Get-LocalUser $userName -ErrorAction 'silentlycontinue'

if ($null -eq $localUser) {
    Write-Error "Something went wrong while creating the '$($userName)' user"
    return
}

# Grant permissions on the folders
Grant-ModifyPermission -Folder 'C:\ProgramData\Cassandra' -UserName $userName
Grant-ModifyPermission -Folder 'c:\Program Files\Cassandra' -UserName $userName

Grant-LogonAsServicePermission -UserName $userName

# Stop Service
Write-Host "Stopping the $($cassandraServiceName) service"
Stop-Service -Name $cassandraServiceName

# Change logon user
Write-Host "Setting the $($cassandraServiceName) service Log On user"
$hostName = cmd.exe /c 'hostname'

$service = gwmi win32_service -computer $hostName -filter "name='$($cassandraServiceName)'"

Write-Host "Password is: $pwd1_text"
$service.change($null, $null, $null, $null, $null, $false, ".\$($userName)", $pwd1_text)

# Start service  
Write-Host "Starting the $($cassandraServiceName) service"  
Start-Service -Name $cassandraServiceName

Write-Host 'Cassandra service user was succesfully updated'