<# : batch script
@echo off
setlocal
cd %~dp0
powershell -executionpolicy bypass -Command "Invoke-Expression $([System.IO.File]::ReadAllText('%~f0'))"
endlocal
goto:eof
#>
#Add users to this list that CrashPlan should not register with
$ExcludedUsers = @(
          'user1'
          'user2'
          'user3'
          'admin'
          'Administrator'
          'admin-*'
)
function Find-User {
    Write-Log "Starting user detection..."
        
    if (Check-Excluded-Users $username $AGENT_USERNAME) {
        Write-Log "Trying to grab the username from hybrid Azure reg key..."
        $username = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI | Select-Object -ExpandProperty LastLoggedOnDisplayName)
        Write-Log "Display name found: ($username)"
        $IdentityMatch = (Get-ItemProperty HKLM:SOFTWARE\Microsoft\IdentityStore\LogonCache\*\Name2Sid\* | Where-Object {$_.DisplayName -eq $username} | Select-Object -Unique -ExpandProperty identityName)
        if ($IdentityMatch.Length -gt 1){
            foreach ($email in $IdentityMatch) {
                $username=$email
                $AGENT_USERNAME=$email
                if(Check-Excluded-Users $username $AGENT_USERNAME) {
                    $IdentityMatch = $IdentityMatch -ne $email
                }
            }
            $AGENT_USERNAME=$IdentityMatch
        }        Write-Log "Username found via hybrid Azure reg key: ($AGENT_USERNAME)"
    }
    if (Check-Excluded-Users $username $AGENT_USERNAME) {
        Write-Log "Trying to find username from Azure Identity..."
        $username = (Get-Process -IncludeUserName -Name explorer | Select-Object -ExpandProperty UserName).Split('\')[1]
        Write-Log "Username found: ($username)"
        $AGENT_USERNAME = (Get-ItemProperty HKLM:SOFTWARE\Microsoft\IdentityStore\Cache\*\IdentityCache\* | Where-Object {$_.SAMName -eq $username} | Select-Object -Unique -ExpandProperty UserName)
        Write-Log "Email found in registry via Azure identity: ($AGENT_USERNAME)"
    }
    if (Check-Excluded-Users $username $AGENT_USERNAME) {
        Write-Log "Trying to grab the username from ADSI domain lookup key..."
        $username = (Get-Process -IncludeUserName -Name explorer | Select-Object -ExpandProperty UserName).Split('\')[1]
        Write-Log "Local username found ($username)"
        $searcher = [adsisearcher]"(samaccountname=$username)"
        ## Change attribute to userprincipalname, if required
        $AGENT_USERNAME = ($searcher.FindOne().Properties.mail)
        Write-Log "Username found via ADSI domain lookup: ($AGENT_USERNAME)"
    }
    if (Check-Excluded-Users $username $AGENT_USERNAME) {
        Write-Log "Excluded or null email address detected ($username).  Will retry user detection in 60 minutes, or when reboot occurs."
        exit
    }
    
    $ExplorerUser = (Get-Process -IncludeUserName -Name explorer | Select-Object -ExpandProperty UserName).Split('\')[1]
    $wmiuser = Get-CimInstance Win32_UserAccount -Filter "Name = '$ExplorerUser'"

    $AGENT_USER_HOME = Get-CimInstance Win32_UserProfile -Filter "SID = '$($wmiuser.SID)'" | Select-Object -ExpandProperty LocalPath
    if (!$AGENT_USER_HOME) {
        Write-Log "User home query from WMI failed. Using fallback home detection method"
        if (Check-Excluded-Users $ExplorerUser) {
            Write-Log "Excluded or null local user detected ($ExplorerUser).  Will retry user detection in 60 minutes, or when reboot occurs."
            exit
        } else {
        $AGENT_USER_HOME = "$env:HOMEDRIVE\Users\$ExplorerUser"
        Write-Log "User home set by appending $ExplorerUser to home path ($AGENT_USER_HOME)"
        }
    } else {
        Write-Log "User home queried from WMI successfully ($AGENT_USER_HOME)"
    }
    Write-Log "Returning AGENT_USERNAME: $AGENT_USERNAME"
    Write-Log "Returning AGENT_USER_HOME: $AGENT_USER_HOME"
    Write-Host AGENT_USERNAME=$AGENT_USERNAME
    Write-Host AGENT_USER_HOME=$AGENT_USER_HOME
}

<# Helper functions below this point.#>
$PROC_LOG = "$env:HOMEDRIVE\ProgramData\CrashPlan\log\userDetect_Result.log"

function Check-Excluded-Users {
 [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [AllowNull()]
        [AllowEmptyString()] 
        [string]$username,
        [Parameter(Mandatory=$false, Position=1)]
        [AllowNull()]
        [AllowEmptyString()] 
        [string]$AGENT_USERNAME
    )
    $ExcludedUsers | ForEach-Object { if ([string]::IsNullOrEmpty($AGENT_USERNAME) -or $username -like $_ -or [string]::IsNullOrEmpty($username) -or $AGENT_USERNAME -like $_) {
        return $true
        }
    }
    return $false
}

function Write-Log {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$LogMessage
    )
    Write-Output $LogMessage
    Add-Content -Path $PROC_LOG -Value (Write-Output ("{0} - {1}" -f (Get-Date), $LogMessage))
}
Find-User