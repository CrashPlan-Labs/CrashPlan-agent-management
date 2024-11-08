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
     $username = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI | Select-Object -ExpandProperty LastLoggedOnUser).Split('\')[-1].Split('@')[0]
     $displayname = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI | Select-Object -ExpandProperty LastLoggedOnDisplayName)
     #Remove and start and end spaces on the string and force lowercase
     $displayname= $($displayname.Trim()).ToLower()
     if([string]::IsNullOrEmpty($displayname) -or $displayname -like ""){
         Write-log "Regkey LastLoggedOnDisplayName not found or empty.  Will retry user detection in 60 minutes, or when reboot occurs."
         exit
     }
     Write-Log "User name found ($username)"
     Write-Log "DisplayName found ($displayname)"
     #Check for firstname lastname or lastname, firstname in the regkey LastLoggedOnDisplayName
     if($displayname -like "*,*"){
         Write-Log "Lastname, Firstname Mode"
         $namearray= $displayname.Split(",")
         $lastname= $($namearray[0].Trim()).Trim(",")
         Write-Log "ln: ($lastname)"
         $firstname= $namearray[1].Trim()
         Write-Log "fn: ($firstname)"         
     }
     else{
         Write-Log "Firstname Lastname Mode"
         $namearray= $displayname.Split(" ")
         $lastname= $namearray[1].Trim()
         Write-Log "ln: ($lastname)"
         $firstname= $namearray[0].Trim()
         Write-Log "fn: ($firstname)"    
     }
     $AGENT_USERNAME = $firstname + "." + $lastname + '@domain.com'
     Write-Log "Email assembled by appending domain ($AGENT_USERNAME)"
     $ExcludedUsers = @(
          'user1'
          'user2'
          'user3'
          'admin'
          'Administrator'
          'admin-*'
     )
     $ExcludedUsers | ForEach-Object { if ([string]::IsNullOrEmpty($username) -or $username -like $_ -or $AGENT_USERNAME -like $_) {
          Write-Log "Excluded or null email address detected ($username).  Will retry user detection in 60 minutes, or when reboot occurs."
          exit
          }
     }
     $wmiuser = Get-CimInstance Win32_UserAccount -Filter "Name = '$username'"
     $AGENT_USER_HOME = Get-CimInstance Win32_UserProfile -Filter "SID = '$($wmiuser.SID)'" | Select-Object -ExpandProperty LocalPath
     if (!$AGENT_USER_HOME) {
          Write-Log "User home query from WMI failed. Using fallback home detection method"
          $AGENT_USER_HOME = "$env:HOMEDRIVE\Users\$username"
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