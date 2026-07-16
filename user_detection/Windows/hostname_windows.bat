<# :
@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dpnx0" %*
exit /b %ERRORLEVEL%
#>

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$LogMessage
    )

    $programData = if ($env:ProgramData) { $env:ProgramData } else { [Environment]::GetFolderPath('CommonApplicationData') }
    $logDir = Join-Path $programData 'CrashPlan\log'
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $script:PROC_LOG = Join-Path $logDir 'userDetect_Result.log'
    Add-Content -LiteralPath $script:PROC_LOG -Value ((Get-Date).ToString() + ' - ' + $LogMessage)
}

function Find-User {
    Write-Log 'Starting user detection...'

    $hostname = [string]$env:COMPUTERNAME
    Write-Log "Computer hostname read from environment ($hostname)"

    $AGENT_USERNAME = $hostname + '@domain.com'
    Write-Log "Email assembled by appending domain ($AGENT_USERNAME)"

    $homeDrive = if ($env:HOMEDRIVE) { $env:HOMEDRIVE } else { $env:SystemDrive }
    $AGENT_USER_HOME = if ($homeDrive) { "$homeDrive\Users\" } else { "$PWD\Users\" }

    Write-Log "Returning AGENT_USERNAME: $AGENT_USERNAME"
    Write-Log "Returning AGENT_USER_HOME: $AGENT_USER_HOME"
    Write-Host "AGENT_USERNAME=$AGENT_USERNAME"
    Write-Host "AGENT_USER_HOME=$AGENT_USER_HOME"
}

$script:PROC_LOG = $null
Find-User
