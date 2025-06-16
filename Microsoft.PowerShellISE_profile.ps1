### PowerShell ISE Profile Refactor
### Version 1.03 - Refactored

Set-ExecutionPolicy Bypass
Set-Location C:\
if ($psISE)
{
  Start-Steroids
  Clear-Host
  Write-Host 'ISE Launched' 
  Get-Date
  $env:USERNAME
}
# Initial GitHub.com connectivity check with 1 second timeout
$canConnectToGitHub = Test-Connection github.com -Count 1 -Quiet

function Update-Profile {
    if (-not $global:canConnectToGitHub) {
        Write-Host "Skipping profile update check due to GitHub.com not responding within 1 second." -ForegroundColor Yellow
        return
    }

    try {
        $url = "https://raw.githubusercontent.com/rookie-eyes/ise-powershell-profile/main/Microsoft.PowerShellISE_profile.ps1"
        $oldhash = Get-FileHash $PROFILE
        Invoke-RestMethod $url -OutFile "$env:temp/Microsoft.PowerShellISE_profile.ps1"
        $newhash = Get-FileHash "$env:temp/Microsoft.PowerShellISE_profile.ps1"
        if ($newhash.Hash -ne $oldhash.Hash) {
            Copy-Item -Path "$env:temp/Microsoft.PowerShellISE_profile.ps1" -Destination $PROFILE -Force
            Write-Host "Profile has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
        }
    } catch {
        Write-Error "Unable to check for `$profile updates"
    } finally {
        Remove-Item "$env:temp/Microsoft.PowerShellISE_profile.ps1" -ErrorAction SilentlyContinue
    }
}
Update-Profile

#Re-load Profile Function

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
function ISEAdmin {
    if ($args.Count -gt 0) {
        $argList = "& '" + $args + "'"
        Start-Process "$psHome\powershell_ise.exe" -Verb runAs -ArgumentList $argList
    } else {
        Start-Process "$psHome\powershell_ise.exe" -Verb runAs
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