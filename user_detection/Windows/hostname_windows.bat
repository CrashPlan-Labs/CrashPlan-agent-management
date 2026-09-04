<# :
@rem hostname_windows.bat
@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dpnx0" %*
exit /b %ERRORLEVEL%
#>

$hostname = [string]$env:COMPUTERNAME
$AGENT_USERNAME = $hostname + '@domain.com'

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$LogMessage
    )

    try {
        $programData = if ($env:ProgramData) { $env:ProgramData } else { [Environment]::GetFolderPath('CommonApplicationData') }
        $logDir = Join-Path $programData 'CrashPlan\log'
        if (-not (Test-Path -LiteralPath $logDir -ErrorAction Stop)) {
            New-Item -ItemType Directory -Path $logDir -Force -ErrorAction Stop | Out-Null
        }

        $script:PROC_LOG = Join-Path $logDir 'userDetect_Result.log'
        Add-Content -LiteralPath $script:PROC_LOG -Value ((Get-Date).ToString() + ' - ' + $LogMessage) -ErrorAction Stop
    }
    catch {
        [Console]::Error.WriteLine("CrashPlan user detection logging failed: $($_.Exception.Message)")
        throw
    }
}

function Find-User {
    Write-Log "---"
    Write-Log "-----------------------------------User Detection Run Start-----------------------------------"
    Write-Log "---"
    Write-Log "Running user detection script: hostname_windows.bat"
    Write-Log "Starting user detection...version 2026-09-03"

    Write-Log "Computer hostname read from environment ($hostname)"

    if ([string]::IsNullOrWhiteSpace($hostname)) {
        $message = 'Computer hostname is empty. Cannot assemble the AGENT_USERNAME.'
        Write-Log $message
        throw $message
    }

    Write-Log "Email assembled by appending domain ($AGENT_USERNAME)"

    $homeDrive = if ($env:HOMEDRIVE) { $env:HOMEDRIVE } else { $env:SystemDrive }
    $AGENT_USER_HOME = if ($homeDrive) { "$homeDrive\Users" } else { "$PWD\Users" }

    Write-Log "Returning AGENT_USERNAME: $AGENT_USERNAME"
    Write-Log "Returning AGENT_USER_HOME: $AGENT_USER_HOME"
    Write-Output "AGENT_USERNAME=$AGENT_USERNAME"
    Write-Output "AGENT_USER_HOME=$AGENT_USER_HOME"
}
try {
    Find-User
}
catch {
    exit 1
}
