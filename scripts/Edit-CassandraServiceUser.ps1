#Requires -RunAsAdministrator

# Constants
Set-Variable cassandraServiceName -Option Constant -Value 'cassandra'
Set-Variable defaultUserName -Option Constant -Value 'cassandra_service'

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
$localUser = Get-LocalUser $userName -ErrorAction 'silentlycontinue'

if ($null -eq $localUser) {
    Write-Error "Something went wrong while creating the '$($userName)' user"
    return
}

# Grant permissions on the folders
Grant-ModifyPermission -Folder 'C:\ProgramData\Cassandra' -UserName $userName
Grant-ModifyPermission -Folder 'c:\Program Files\Cassandra\logs' -UserName $userName
Grant-ModifyPermission -Folder 'c:\Program Files\Cassandra\data' -UserName $userName
Grant-ModifyPermission -Folder 'C:\Program Files\Cassandra\bin\daemon' -UserName $userName

# Stop Service
Write-Host "Stopping the $($cassandraServiceName) service"
Stop-Service -Name $cassandraServiceName

# Change logon user
Write-Host "Setting the $($cassandraServiceName) service Log On user"
$hostName = cmd.exe /c 'hostname'

$service = gwmi win32_service -computer $hostName -filter "name='$($cassandraServiceName)'"
$service.change($null, $null, $null, $null, $null, $null, ".\$($userName)", $pwd1_text)

# Start service  
Write-Host "Starting the $($cassandraServiceName) service"  
Start-Service -Name $cassandraServiceName

Write-Host 'Cassandra service user was succesfully updated'