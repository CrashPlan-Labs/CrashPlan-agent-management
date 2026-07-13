<# : batch script
@echo off
setlocal
cd %~dp0
powershell -executionpolicy bypass -Command "Invoke-Expression $([System.IO.File]::ReadAllText('%~f0'))"
endlocal
goto:eof
#>
function Find-User {
     Write-Log "Starting user detection..."
     $hostname = $env:computername
     Write-Log "Computer hostname read from environment ($hostname)"
     $AGENT_USERNAME = $hostname + '@domain.com'
     Write-Log "Email assembled by appending domain ($AGENT_USERNAME)"
     $ExcludedUsers = @(
          'user1'
          'user2'
          'user3'
          'admin'
          'Administrator'
          'admin-*'
     )
     $ExcludedUsers | ForEach-Object { if ([string]::IsNullOrEmpty($hostname) -or $hostname -like $_) {
          Write-Log "Excluded or null email address detected ($hostname).  Will retry user detection in 60 minutes, or when reboot occurs."
          Write-Output "Excluded or null email address detected ($hostname).  Will retry user detection in 60 minutes, or when reboot occurs."
          exit
          }
     }
     $AGENT_USER_HOME = "$env:HOMEDRIVE\Users\"
     Write-Log "Returning AGENT_USERNAME: $AGENT_USERNAME"
     Write-Log "Returning AGENT_USER_HOME: $AGENT_USER_HOME"
     Write-Host AGENT_USERNAME=$AGENT_USERNAME
     Write-Host AGENT_USER_HOME=$AGENT_USER_HOME
}

<# Helper functions below this point. Most likely these will not need to be edited. #>
$PROC_LOG = "$env:HOMEDRIVE\ProgramData\CrashPlan\log\userDetect_Result.log"
function Write-Log {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$LogMessage
    )
    Add-Content -Path $PROC_LOG -Value (Write-Output ("{0} - {1}" -f (Get-Date), $LogMessage))
}
Find-User