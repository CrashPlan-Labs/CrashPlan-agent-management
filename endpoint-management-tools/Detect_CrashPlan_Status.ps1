<# Detect_CrashPLan_Status.ps1
Used to determine the status of the CrashPlan service on an endpoint. Used for troubleshooting and to give context to a CrashPlan install.

Responses and Actions:

Settings:
Script can be configured to upload logs to a CrashPlan provided sharefile location, or a local network drive. 
To Modify uncomment items in the SendLogs function, then uncomment all the calls to SendLogs.

Exit code 0
Healthy, no action needed. Possible Values for the 'State' or 'errorStatus' value:
    Healthy. Authorized and running.
        No Action.
    Healthy. Likely not yet registered.
        No Action
    Healthy. First installed today.
        No Action.

Exit code 1
Install is not healthy, action likely needed. Possible Values for the 'State' or 'errorStatus' value:

Unhealthy. Authorized and running but UserHome Path does not exist on the system.
    CrashPlan's user detection logic returned a userHome value that does not exist on the endpoint and so the :user vairable will not work. Trigger a reinstall to fix.
Unhealthy. Authorized and running but Backup has not happened.
    Check settings for this system, confirm it has a valid user home, or that there are files in that location
Unhealthy. Authorized and running; backup has not happened for days= X
    Check settings, get logs.
Unhealthy. Not registered for days= X
    Check detection logic, check to make sure that we have a vaid possible userHome, or username.
Unhealthy. Logs have not been updated for days=X
    Grab logs then uninstall/reinstall. Uninstall/Reinstall CrashPlan
Unhealthy. CrashPlan Service is not running. Logs last updated= X
    Service Not Running, try starting the service or pulling logs and investigating
Unhealthy. CrashPlan is not a service on this endpoint; likely not installed.
    CrashPlan is not installed. Trigger an install if it should be. Confirm that a version of Code42 was not installed before installing CrashPlan.
#>

#$ErrorSystemPreference = "SilentlyContinue"

#Test for all possible locations CrashPlan could be installed
if (Test-Path -Path C:\ProgramData\CrashPlan\log\app.log -PathType Leaf) {
    $CrashPlanBasePath = "C:\ProgramData\CrashPlan"
    $UserInstall = $False
}
else {
    get-childItem C:\Users | ForEach-Object {
        if ((Test-path "C:\Users\${_}\AppData\Local\CrashPlan")) {
            $CrashPlanBasePath = "C:\Users\$_\AppData\Local\CrashPlan"
            $UserInstall = $True
        }
    }
}

function SendLogs($preFix) {
    #the link below can be used in a stand alone fashion to manually upload files to CrashPlan as well as with this script.
    $ShareFileLink = "Sharefile request link from CrashPlan Support"
    $ShareFile = $ShareFileLink.Split("-")[1]
    
    Copy-Item -path $CrashPlanBasePath\log\ -Destination $CrashPlanBasePath\tmplog\ -Recurse

    $LogFile = "$preFix"+$(hostname) +"-"+ $(get-date -format FileDateUniversal) +".zip"
    $evtx_name="$preFix"+$(hostname)+"System.evtx"
    $backupLogPath = "$CrashPlanBasePath\tmplog\$evtx_name"
    $logfile = Get-CimInstance Win32_NTEventlogFile | Where-Object LogfileName -EQ "System"
    Invoke-CimMethod -InputObject $logfile -MethodName BackupEventLog -Arguments @{ ArchiveFileName = $backupLogPath }
    
    Compress-Archive -Path $CrashPlanBasePath\tmplog\* -DestinationPath $CrashPlanBasePath\$LogFile
    $logZip=$CrashPlanBasePath+'\'+$LogFile

    ##Uncomment below to upload to a shared folder.
    #$Destination = "\\netshare\DESTINATION\CrashPlan_Remediation_Logs" + $TimeStamp
    #Copy-Item -Path $logZip -Destination $Destination -Force
    ##UnComment Below to upload to CrashPlan ShareFile
    #$shareFilePost=$(curl.exe -X POST -F File1=@"$logZip" "https://crashplan.sf-api.com/sf/v3/Shares($ShareFile)/Upload?Method=standard&raw=false&fileName=+$LogFile")
    #$chunkUri = ($shareFilePost | convertFrom-json).ChunkUri
    #curl.exe -k -F "File1=@$logZip" "$chunkUri"

    Remove-Item $CrashPlanBasePath\tmplog -Recurse
    Remove-Item $logZip
}
function CheckCrashPlanInstall {

    $MinDaysHealthy = 7
    if ( !$UserInstall) {
        $CrashPlanService = Get-Service -name 'CrashPlan Service'
        if (![string]::IsNullOrEmpty($CrashPlanService.Status)) {
            if ($CrashPlanService.Status -eq 'Running') {
                $CrashPlanRunning = $true
            }
        }
    }
    else {
        $CrashPlanService = Get-Process -name 'CrashPlanService'
        if ($CrashPlanService -ne $null) {
                 $CrashPlanRunning = $true
        }
    }
    #Get the Authorized status of the endpoint. True means that a user is assigned to the device. False could mean that it's in user detection mode
    $AppLog = "$CrashPlanBasePath\log\app.log"
    $ServiceLog = "$CrashPlanBasePath\log\service.log.0"
    $BackupLog = "$CrashPlanBasePath\log\backup_files.log.0"
    if (Test-Path -Path $AppLog -PathType Leaf) {
                $serviceModel = Get-Content $AppLog | Select-String 'ServiceModel.authorized'
                $Guid = $(Get-Content "$CrashPlanBasePath\.identity" | Select-String 'guid').ToString().split("= ")[1]
                $Authorized = [System.Convert]::ToBoolean($("$serviceModel".Replace(" ","").Split("=")[1]))
                $RegisteredUser = $($(Select-string -Path $AppLog 'USERS' -CaseSensitive -Context 1).Context.PostContext).Split(",")[1].Trim()

                #userHome validation, does the path exist on disk.
                $UserHomeLine = Get-Content $AppLog | Select-String 'userHome'
                $UserHome = ($UserHomeLine -split '[<>]')[2]
                $UserHomeValid = Test-Path -Path $UserHome
    }
    if (Test-Path -Path $ServiceLog -PathType Leaf) {
             #Get the last time the service log updated. If the service is running then the log will exist.             
            $ServiceLogLastUpdated = $(Get-Item -Path $ServiceLog).lastwritetime.Date | Get-Date -Format yyyy-MM-dd
            $LogsLastUpdated =  $(NEW-TIMESPAN -Start $ServiceLogLastUpdated -End $(Get-Date)).Days
            $FirstStartLine = $(get-content $ServiceLog | Select-String -pattern 'STARTED CrashPlan Agent' | Select-Object line -first 1)
            if ($FirstStartLine -ne $null) {
                $FirstStartDay = $FirstStartLine.Line.substring(1,16) | Get-Date
                $FirstStartTimeSpan =  $(NEW-TIMESPAN -Start $FirstStartDay -End $(Get-Date)).Days
            }
            $NothingToDoCount = $(get-content $CrashPlanBasePath\log\service.log.0 | Select-String -pattern 'Periodic check: Nothing to do, indicate backup activity for all sets','scanDone. backupComplete=true' | Measure-Object | Select-Object -ExpandProperty Count)
     }
    if (Test-Path -Path $BackupLog -PathType Leaf) {
        #Get Last Backup Time if the service is Authorized
        $LastBackupDate_line = $(Get-Content $BackupLog | Select-Object -Last 1)
        if ($LastBackupDate_line) {
            $LastBackupDate = $LastBackupDate_line.substring(2,16) | Get-Date -Format yyyy-MM-dd
        }
        else {
            $LastBackupDate = "null"
        }
        if ($LastBackupDate -ne "null") {
            $BackupUpdated =  $(NEW-TIMESPAN -Start $LastBackupDate -End $(Get-Date)).Days
        }
    }
    if ($CrashPlanService -ne $null) {
        if ($CrashPlanRunning) {
            if ($LogsLastUpdated -lt $MinDaysHealthy) {
                if ($Authorized) {
                    if ($UserHome) {
                        if ($UserHomeValid = $false) {
                            $PreRemediationDetectionError = "Unhealthy. Authorized and running. UserHome Path does not exist on the system."
                            $errorStatus = 1
                        }
                    }
                    if ($BackupUpdated -eq "null") {
                        if (($FirstStartTimeSpan -eq 1) -or ($FirstStartTimeSpan -eq 0)) {
                            $PreRemediationDetectionError = "Healthy. First installed today."
                            $errorStatus = 0
                        }
                        else {
                            #SendLogs("Auth_no_recent_backup-$guid-")
                            $PreRemediationDetectionError = "Unhealthy. Authorized and running. Backup has not happened."
                            $errorStatus = 1
                        }
                    }
                    if ($BackupUpdated -le $MinDaysHealthy) {
                        $PreRemediationDetectionError = "Healthy. Authorized and running."
                        $errorStatus = 0
                    }
                    else {
                        #SendLogs("Auth_no_recent_backup-$guid-")
                        $PreRemediationDetectionError = "Unhealthy. Authorized and running; backup has not happened for days=" + $BackupUpdated +," Nothing to do count= $NothingToDoCount \."
                        $errorStatus = 0                    }
                }
                else {
                    if ($FirstStartTimeSpan -lt $MinDaysHealthy) {
                        $PreRemediationDetectionError = "Healthy. Likely not yet registered."
                        $errorStatus = 0
                    }
                    else {
                        #SendLogs("Not_yet_registered-$guid-")
                        $PreRemediationDetectionError = "Unhealthy. Not registered for days= $FirstStartTimeSpan."
                        $errorStatus = 1
                    }
                }
            }
            else {
                #SendLogs("Logs_not_updating-")
                $PreRemediationDetectionError = "Unhealthy. Logs have not been updated for days=$LogsLastUpdated."
                $errorStatus = 1
            }
        }
        else {
            #SendLogs("service_not_running-$guid-")  
            $PreRemediationDetectionError = "Unhealthy. CrashPlan Service is not running. Logs last updated= $ServiceLogLastUpdated  ."
            $errorStatus = 1
        }
    }
    else {
        $PreRemediationDetectionError = "CrashPlan is not a service on this endpoint; likely not installed."
        $errorStatus = 1
    }
    $PreRemediationDetectionOutput = "Running:$CrashPlanRunning, State:[$PreRemediationDetectionError] Logged in:$RegisteredUser, UserHome:$UserHome, UserHome valid:$UserHomeValid, Last Backup:$LastBackupDate, Logs last written:$ServiceLogLastUpdated, GUID:$Guid"
    return @($errorStatus,$PreRemediationDetectionOutput,$PreRemediationDetectionError)
}

$Output = CheckCrashPlanInstall

$errorStatus = $Output[0]
$PreRemediationDetectionOutput = $Output[1]
$PreRemediationDetectionError = $Output[2]

Write-Error $PreRemediationDetectionError
Write-Output $PreRemediationDetectionOutput
exit $errorStatus