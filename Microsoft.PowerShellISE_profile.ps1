### PowerShell ISE Profile Refactor
### Version 1.03 - Refactored

Set-ExecutionPolicy Bypass
Set-Location C:\
if ($psISE)
{
  Start-Steroids
  Clear-Host
  Write-Host 'Welcome to PowerShell ISE!'
  Write-Host 'ISE Launched on $env:computername'
  Get-Date
  $env:USERNAME
}
# Initial GitHub.com connectivity check with 1 second timeout
$canConnectToGitHub = Test-Connection github.com -Count 1 -Quiet

function Update-Profile {
    if (-not $global:canConnectToGitHub) {
        Write-Host "Skipping profile update check due to GitHub.com not responding within 1 second." -ForegroundColor DarkYellow
        return
    }

    try {
        $url = "https://raw.githubusercontent.com/rookie-eyes/ise-powershell-profile/main/Microsoft.PowerShellISE_profile.ps1"
        $oldhash = Get-FileHash $PROFILE
        Invoke-RestMethod $url -OutFile "$env:temp/Microsoft.PowerShellISE_profile.ps1"
        $newhash = Get-FileHash "$env:temp/Microsoft.PowerShellISE_profile.ps1"
        if ($newhash.Hash -ne $oldhash.Hash) {
            Copy-Item -Path "$env:temp/Microsoft.PowerShellISE_profile.ps1" -Destination $PROFILE -Force
            Write-Host "Profile has been updated. Please restart your shell to reflect changes" -ForegroundColor DarkMagenta
        }
    } catch {
        Write-Error "Unable to check for `$profile updates"
    } finally {
        Remove-Item "$env:temp/Microsoft.PowerShellISE_profile.ps1" -ErrorAction SilentlyContinue
    }
}
Update-Profile

#Reload Profile Function

function reload-profile {
    & $profile
}

# Import Modules and External Profiles

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}
# Initial GitHub.com connectivity check with 1 second timeout
$canConnectToGitHub = Test-Connection github.com -Count 1 -Quiet
# Network Utilities
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }
# System Utilities
function uptime {
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        Get-WmiObject win32_operatingsystem | Select-Object @{Name='LastBootUpTime'; Expression={$_.ConverttoDateTime($_.lastbootuptime)}} | Format-Table -HideTableHeaders
    } else {
        net statistics workstation | Select-String "since" | ForEach-Object { $_.ToString().Replace('Statistics since ', '') }
    }
}
# Simple function to start a new elevated process. If arguments are supplied then 
# a single command is started with admin rights; if not then a new admin instance
# of PowerShell ISE is started.
function ISE {
    if ($args.Count -gt 0) {   
        $argList = "& '" + $args + "'"
        Start-Process "$psHome\powershell_ise.exe" -Verb runAs -ArgumentList $argList
    } else {
        Start-Process "$psHome\powershell_ise.exe" -Verb runAs
    }
}
# Simple function to start a new elevated powershell process. If arguments are supplied then 
# a single command is started with admin rights; if not then a new admin instance
# of PowerShell is started.
function admin {

    [CmdletBinding(DefaultParameterSetName='NoCommand')]
    param (
        [Parameter(Position=0, ValueFromRemainingArguments=$true, ParameterSetName='Command')]
        [string[]]$Command
    )

    $powerShellExecutable = $null

    if ($PSVersionTable.PSEdition -eq 'Core') {
        $powerShellExecutable = Join-Path $PSHOME "pwsh.exe"
        if (-not (Test-Path $powerShellExecutable)) {
            $powerShellExecutable = "$($env:ProgramFiles)\PowerShell\7\pwsh.exe"
            if (-not (Test-Path $powerShellExecutable)) {
                Write-Error "Could not locate 'pwsh.exe' for PowerShell 7. Please ensure PowerShell 7 is installed correctly."
                return
            }
        }
    } else {
        $powerShellExecutable = Join-Path $PSHOME "powershell.exe"
    }
    if (-not (Test-Path $powerShellExecutable)) {
        Write-Error "Could not locate the PowerShell executable at '$powerShellExecutable'. Please ensure PowerShell is installed correctly."
        return
    }
    if (-not $powerShellExecutable) {
        Write-Error "Could not determine the PowerShell executable path for the current session."
        return
    }

    $argumentList = @()
    $argumentList += "-NoExit"
    if ($PSBoundParameters.ContainsKey('Command')) {
        $commandToExecute = $Command -join ' '
        $argumentList += "-Command"
        $argumentList += "& { $commandToExecute }"
    }

    try {
        Start-Process -FilePath $powerShellExecutable -Verb RunAs -ArgumentList $argumentList
    }
    catch {
        Write-Error "Failed to launch administrative PowerShell window. Error: $($_.Exception.Message)"
        Write-Warning "This usually happens if User Account Control (UAC) is disabled or if you do not have sufficient permissions to run as administrator."
    }
}
# This function launches PowerShell ISE with administrative privileges.
# If arguments are provided, it runs the command in a new elevated ISE instance.
# If no arguments are provided, it simply opens a new elevated ISE window.
function iseadmin {
    [CmdletBinding(DefaultParameterSetName='NoCommand')]
    param (
        [Parameter(Position=0, ValueFromRemainingArguments=$true, ParameterSetName='Command')]
        [string[]]$Command
    )

    # PowerShell ISE (Integrated Scripting Environment) is part of Windows PowerShell,
    # not PowerShell Core. Its executable is 'powershell_ise.exe'.
    $iseExecutable = Join-Path $PSHOME "powershell_ise.exe"

    # Verify that the PowerShell ISE executable exists at the expected path.
    if (-not (Test-Path $iseExecutable)) {
        Write-Error "Could not locate 'powershell_ise.exe'. Please ensure PowerShell ISE is installed correctly on your system."
        return
    }

    # Initialize an array to hold arguments passed to powershell_ise.exe
    $argumentList = @()

    # If the user provides a command, pass it to ISE using its -Command parameter.
    # This will execute the command directly within the ISE console pane upon launch.
    if ($PSBoundParameters.ContainsKey('Command')) {
        $commandToExecute = $Command -join ' '
        $argumentList += "-Command"
        # Wrap the command in a script block to ensure it's properly interpreted and executed by ISE.
        $argumentList += "& { $commandToExecute }"
    }

    # Attempt to launch PowerShell ISE with administrative privileges using 'Start-Process'.
    # The -Verb RunAs triggers the User Account Control (UAC) prompt for elevation.
    try {
        Write-Host "Attempting to launch PowerShell ISE with administrative privileges..."
        # Only pass -ArgumentList if there are actual arguments to provide.
        # This prevents the error when no command is specified.
        if ($PSBoundParameters.ContainsKey('Command')) {
            Start-Process -FilePath $iseExecutable -Verb RunAs -ArgumentList $argumentList
        } else {
            Start-Process -FilePath $iseExecutable -Verb RunAs
        }
    }
    catch {
        # Catch any errors during the launch process, such as UAC being disabled
        # or insufficient permissions.
        Write-Error "Failed to launch administrative PowerShell ISE window. Error: $($_.Exception.Message)"
        Write-Warning "This usually happens if User Account Control (UAC) is disabled or if you do not have sufficient permissions to run as administrator."
    }
}

# This function starts the ISE Steroids module if it is installed.
# It checks for the module's path and imports it if found.
# If the module is not found, it provides a warning message.
# Usage: Call Start-Steroids to load the ISE Steroids module.
# This function is designed to be called in the PowerShell ISE profile to ensure that
# the ISE Steroids module is available whenever the ISE is launched.

function Start-Steroids {
    $steroidsPath = "$env:ProgramFiles\WindowsPowerShell\Modules\ISESteroids\ISESteroids.psd1"
    if (Test-Path $steroidsPath) {
        Import-Module $steroidsPath -Force
        Write-Host "ISE Steroids module loaded successfully." -ForegroundColor Green
    } else {
        Write-Warning "ISE Steroids module not found at '$steroidsPath'. Please ensure it is installed."
    }
}