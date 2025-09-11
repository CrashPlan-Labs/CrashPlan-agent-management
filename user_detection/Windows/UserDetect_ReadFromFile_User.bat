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
     $username = (Get-Process -IncludeUserName -Name explorer | Select-Object -ExpandProperty UserName).Split('\')[-1].Split('@')[0]
     Write-Log "User name found ($username)"
     $AGENT_USERNAME = Get-Content $env:HOMEDRIVE\temp\CrashPlan_User.txt
     Write-Log "Email read from file ($AGENT_USERNAME)"
     $ExcludedUsers = @(
          'system'
          'user1'
          'user2'
          'user3'
          'admin'
          'Administrator'
          'admin-*'
     )
     $ExcludedUsers | ForEach-Object { if ([string]::IsNullOrEmpty($AGENT_USERNAME) -or $username -like $_ -or $AGENT_USERNAME -like $_) {
          Write-Log "Excluded or null email address detected ($username).  Will retry user detection in 60 minutes, or when reboot occurs."
          exit
          }
     }
     $wmiuser = Get-CimInstance Win32_UserAccount -Filter "Name = '$username'"
     $AGENT_USER_HOME = Get-CimInstance Win32_UserProfile -Filter "SID = '$($wmiuser.SID)'" | Select-Object -ExpandProperty LocalPath
     if (!$AGENT_USER_HOME) {
          Write-Log "User home query from WMI failed. Using fallback home detection method"
          if (!$env:HOMEDRIVE) {
               Write-Log "HOMEDRIVE environment variable not set. Defaulting to C:"
               $AGENT_USER_HOME = "C:\Users\$username"
          } else {
               $AGENT_USER_HOME = "$env:HOMEDRIVE\Users\$username"
          }
          Write-Log "User home set by appending $username to home path ($AGENT_USER_HOME)"
     } ELSE {
          Write-Log "User home queried from WMI successfully ($AGENT_USER_HOME)"
     }
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
    Write-Output $logMessage
}
Find-User