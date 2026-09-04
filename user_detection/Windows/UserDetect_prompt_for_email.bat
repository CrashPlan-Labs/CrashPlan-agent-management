<# : batch script
@rem UserDetect_prompt_for_email.bat
@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~f0"
endlocal
exit /b %ERRORLEVEL%
goto:eof
#>
function Write-Log {
    param (
        [string]$Message
    )

    try {
        $logDirectory = Join-Path $env:ProgramData "CrashPlan\log"
        $logFile = Join-Path $logDirectory "userDetect_Result.log"

        if (-not (Test-Path -LiteralPath $logDirectory -ErrorAction Stop)) {
            New-Item -ItemType Directory -Path $logDirectory -Force -ErrorAction Stop | Out-Null
        }

        Add-Content -LiteralPath $logFile -Value "$(Get-Date) - $Message" -ErrorAction Stop
    }
    catch {
        [Console]::Error.WriteLine("CrashPlan user detection logging failed: $($_.Exception.Message)")
        throw
    }
}

function Ask-Email {
    Add-Type -AssemblyName Microsoft.VisualBasic

    return [Microsoft.VisualBasic.Interaction]::InputBox(
        "Please enter your email address to continue:",
        "CRASHPLAN BACKUP",
        ""
    )
}

function Find-User {
    Write-Log "Starting user detection..."

    try {
        $consoleUser = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName
    }
    catch {
        Write-Log "Unable to detect console user: $($_.Exception.Message)"
        throw
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
        $message = "Excluded or null username detected ($user)."
        Write-Log $message
        throw $message
    }

    $agentUsername = Ask-Email

    if ([string]::IsNullOrWhiteSpace($agentUsername)) {
        $message = 'Email address was empty or whitespace. Cannot continue user detection.'
        Write-Log $message
        throw $message
    }

    if ($agentUsername -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') {
        $message = "Invalid email address format entered ($agentUsername). Cannot continue user detection."
        Write-Log $message
        throw $message
    }

    Write-Log "Email found from user input ($agentUsername)"

    $escapedUser = [regex]::Escape($user)
    $userProfile = Get-CimInstance Win32_UserProfile -ErrorAction Stop |
        Where-Object {
            $_.LocalPath -match "\\$escapedUser$"
        } |
        Select-Object -First 1

    if ($null -eq $userProfile) {
        $message = "Unable to find a Windows user profile for ($user)."
        Write-Log $message
        throw $message
    }

    $agentUserHome = $userProfile.LocalPath
    Write-Log "Home directory read from Windows ($agentUserHome)"
    Write-Log "Returning AGENT_USERNAME=$agentUsername"
    Write-Log "Returning AGENT_USER_HOME=$agentUserHome"

    Write-Output "AGENT_USERNAME=$agentUsername"
    Write-Output "AGENT_USER_HOME=$agentUserHome"
}
Find-User
