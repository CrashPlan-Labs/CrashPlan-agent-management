#UserDetect_prompt_for_email.bat
<# : batch script
@echo off
setlocal
cd %~dp0
powershell -executionpolicy bypass -Command "Invoke-Expression $([System.IO.File]::ReadAllText('%~f0'))"
endlocal
goto:eof
#>
function Write-Log {
    param (
        [string]$Message
    )

    $logDirectory = Join-Path $env:ProgramData "CrashPlan\log"
    $logFile = Join-Path $logDirectory "userDetect_Result.log"

    if (-not (Test-Path $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    }

    Add-Content -Path $logFile -Value "$(Get-Date) - $Message"
}

function Ask-Email {
    Add-Type -AssemblyName Microsoft.VisualBasic

    return [Microsoft.VisualBasic.Interaction]::InputBox(
        "Please fill in your email address to continue:",
        "CRASHPLAN BACKUP",
        ""
    )
}

function Main {
    Write-Log "Starting user detection..."

    try {
        $consoleUser = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName
    }
    catch {
        Write-Log "Unable to detect console user: $($_.Exception.Message)"
        return
    }

    $user = if ($consoleUser -match "\\") {
        $consoleUser.Split("\")[-1]
    }
    else {
        $consoleUser
    }

    Write-Log "User name found ($user)"

    if (
        [string]::IsNullOrWhiteSpace($user) -or
        $user -match "^(admin1|admin2|admin3)$"
    ) {
        Write-Log "Excluded or null username detected ($user). Will retry user detection in 60 minutes, or when reboot occurs."
        return
    }

    $agentUsername = Ask-Email
    Write-Log "Email found from user input ($agentUsername)"

    $escapedUser = [regex]::Escape($user)
    $userProfile = Get-CimInstance Win32_UserProfile |
        Where-Object {
            $_.LocalPath -match "\\$escapedUser$"
        } |
        Select-Object -First 1

    $agentUserHome = $userProfile.LocalPath
    Write-Log "Home directory read from Windows ($agentUserHome)"
    Write-Log "Returning AGENT_USERNAME=$agentUsername"
    Write-Log "Returning AGENT_USER_HOME=$agentUserHome"

    Write-Output "AGENT_USERNAME=$agentUsername"
    Write-Output "AGENT_USER_HOME=$agentUserHome"
}

Main