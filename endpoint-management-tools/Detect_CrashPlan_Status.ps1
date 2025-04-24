<# Detect_CrashPLan_Status.ps1
Used to determine the status of the CrashPlan service on an endpoint. Used for troubleshooting and to give context to a CrashPlan install.

Responses and Actions:

Settings:
Script can be configured to upload logs to a CrashPlan provided sharefile location, or a local network drive. 
To Modify uncomment items in the SendLogs function, then uncomment all the calls to SendLogs.

Exit code 0
Healthy, no action needed. Possible Values for the 'DetectionError' value:
    Healthy. Authorized and running.
        No Action.
    Healthy. Likely not yet registered.
        No Action

Install may not be healthy, action likely needed. Possible Values for the  'DetectionError' value:
    Unhealthy. Authorized and running but UserHome Path does not exist on the system.
        CrashPlan's user detection logic returned a userHome value that does not exist on the endpoint and so the :user vairable will not work. Trigger a reinstall to fix.
    Unhealthy. Authorized and running but Backup has not happened.
        Check settings for this system, confirm it has a valid user home, or that there are files in that location
    Unhealthy. Authorized and running; backup has not happened for days= X
        Check settings, get logs.
    Unhealthy. Not registered for days= X
        Check detection logic, check to make sure that we have a vaid possible userHome, or username.
Exit code 1
Install is not healthy, or there is no install. Remediation script will reinstall on the endpoint. Possible Values for the  'DetectionError' value:
    Unhealthy. Logs have not been updated for days=X
        Grab logs then uninstall/reinstall. Uninstall/Reinstall CrashPlan
    Unhealthy. CrashPlan Service is not running. Logs last updated= X
        Service Not Running, try starting the service or pulling logs and investigating,
    Unhealthy. CrashPlan is not a service on this endpoint; likely not installed.
        CrashPlan is not installed. Trigger an install if it should be. Confirm that a version of Code42 was not installed before installing CrashPlan.
#>
#$ErrorSystemPreference = "SilentlyContinue"
$MinDaysHealthy = 7
$DateFormat = 'yyyy-MM-dd'
#Test for all possible locations CrashPlan could be installed
if (Test-Path -Path "C:\ProgramData\CrashPlan\.identity" -PathType Leaf) {
    $CrashPlanBasePath = "C:\ProgramData\CrashPlan"
    $UserInstall = $false
    $Guid = $(Get-Content -Path "$CrashPlanBasePath\.identity" | Select-String 'guid').ToString().split("= ")[1]
}
else {
    get-childItem C:\Users | ForEach-Object {
        if ((Test-Path "C:\Users\$($_.Name)\AppData\Local\CrashPlan\.identity" -PathType Leaf)) {
            $CrashPlanBasePath = "C:\Users\$($_.Name)\AppData\Local\CrashPlan"
            $UserInstall = $true
            $Guid = $(Get-Content -Path "$CrashPlanBasePath\.identity" | Select-String 'guid').ToString().split("= ")[1]
        }
    }
}

function SendLogs($preFix) {
    #the link below can be used in a stand alone fashion to manually upload files to CrashPlan as well as with this script.
    $ShareFileLink = "Sharefile request link from CrashPlan Support"
    $ShareFile = $ShareFileLink.Split("-")[1]
    
    Copy-Item -Path "$CrashPlanBasePath\log\" -Destination "$CrashPlanBasePath\tmplog\" -Recurse

    $LogFile = "$preFix"+$(hostname) +"-"+ $(get-date -format FileDateUniversal) +".zip"
    $evtx_name="$preFix"+$(hostname)+"-System.evtx"
    $backupLogPath = "$CrashPlanBasePath\tmplog\$evtx_name"
    $EventViewerLog = Get-CimInstance Win32_NTEventlogFile | Where-Object LogfileName -EQ "System"
    Invoke-CimMethod -InputObject $EventViewerLog -MethodName BackupEventLog -Arguments @{ ArchiveFileName = $backupLogPath }

    Compress-Archive -Path "$CrashPlanBasePath\tmplog\*" -DestinationPath "$CrashPlanBasePath\$LogFile"
    $logZip=$CrashPlanBasePath+'\'+$LogFile

    ##Uncomment below to upload to a shared folder.
    #$Destination = "\\netshare\DESTINATION\CrashPlan_Remediation_Logs" + $TimeStamp
    #Copy-Item -Path $logZip -Destination $Destination -Force
    ##UnComment Below to upload to CrashPlan ShareFile
    #$shareFilePost=$(curl.exe -X POST -F File1=@"$logZip" "https://crashplan.sf-api.com/sf/v3/Shares($ShareFile)/Upload?Method=standard&raw=false&fileName=+$LogFile")
    #$chunkUri = ($shareFilePost |convertFrom-json).ChunkUri
    #curl.exe -k -F "File1=@$logZip" "$chunkUri"
    Remove-Item $CrashPlanBasePath\tmplog -Recurse
    Remove-Item $logZip
}

function Test-FileUnlocked  {    
    param (
    [string]$FullName
    )
    try {
        [IO.File]::OpenWrite($FullName).Close()
        return $true
    } catch {
        return $false
    }
}
function CheckCrashPlanInstall {
    if ( !$UserInstall) {
        $CrashPlanService = Get-Service -name 'CrashPlan Service' -ErrorAction silentlyContinue
        if (![string]::IsNullOrEmpty($CrashPlanService.Status)) {
            if ($CrashPlanService.Status -eq 'Running') {
                $CrashPlanRunning = $true
            }
        }
    }
    else {
        $CrashPlanService = Get-Process -name 'CrashPlanService' -ErrorAction silentlyContinue
        if (![string]::IsNullOrEmpty($CrashPlanService)) {
                 $CrashPlanRunning = $true
        }
    }
     #Get the Authorized status of the endpoint. true means that a user is assigned to the device. false could mean that it's in user detection mode
     $AppLogPath = "$CrashPlanBasePath\log\app.log"
     $ServiceLogPath = "$CrashPlanBasePath\log\service.log.0"
     $BackupLogPath = "$CrashPlanBasePath\log\backup_files.log.0"
     
     if ((Test-Path -Path $AppLogPath -PathType Leaf) -and (Test-FileUnlocked $AppLogPath)) {
         $AppLog = Get-Content -Path $AppLogPath
         $ServiceModel = $AppLog | Select-String 'ServiceModel.authorized'
         $Authorized = [System.Convert]::ToBoolean($("$ServiceModel".Replace(" ","").Split("=")[1]))
         if ($Authorized) {
             $RegisteredUser = $($($AppLog | Select-string 'USERS' -CaseSensitive -Context 1).Context.PostContext).Split(",")[1].Trim()
         }
         #userHome validation, does the path exist on disk.
         $UserHomeLine = $AppLog | Select-String 'userHome'
         $UserHome = ($UserHomeLine -split '[<>]')[2]
         if ([string]::IsNullOrEmpty($UserHome)) {
             $UserHomeValid = $false
         }
         else {
             $UserHomeValid = Test-Path -Path $UserHome
         }
     }
     if (Test-Path -Path $ServiceLogPath -PathType Leaf) {
         $ServiceLog = Get-Content -Path $ServiceLogPath
         #Get the last time the service log updated. If the service is running then the log will exist.             
         $ServiceLogLastUpdated = $(Get-Item -Path $ServiceLogPath).lastwritetime | Get-Date -Format ${DateFormat}
         $LogsLastUpdated =  $(NEW-TIMESPAN -Start $ServiceLogLastUpdated -End $(Get-Date)).Days
         $FirstDeployLine = $($ServiceLog | Select-String -pattern 'Deploy:: Retrieving deployment package' | Select-Object line -first 1)
         if ($null -ne $FirstDeployLine) {
             $FirstDeployDateFound = $FirstDeployLine -match '\d{2}\.\d{2}\.\d{2}'
             if ($FirstDeployDateFound) {
                 $FirstDeployDayString = $matches[0]
             }
             $FirstDeployDay = [datetime]::ParseExact($FirstDeployDayString, 'MM.dd.yy', [System.Globalization.CultureInfo]::GetCultureInfo('en-US')).ToString($DateFormat)
             $FirstDeployTimeSpan =  $(NEW-TIMESPAN -Start $FirstDeployDay -End $(Get-Date)).Days
         }
         $NothingToDoCount = $($ServiceLog | Select-String -pattern 'Periodic check: Nothing to do, indicate backup activity for all sets','scanDone. backupComplete=true' | Measure-Object | Select-Object -ExpandProperty Count)
      }
     if (Test-Path -Path $BackupLogPath -PathType Leaf) {
         $BackupLog = Get-Content -Path $BackupLogPath
         #Get Last Backup Time if the service is Authorized
         $LastBackupDate_line = $($BackupLog | Select-Object -Last 1)
         if ($LastBackupDate_line) {
             $BackupLogDateFound = $LastBackupDate_line -match '\d{2}\/\d{2}\/\d{2} \d{2}:\d{2}[AP]M'
             if ($BackupLogDateFound) {
                 $LastBackupDateString = $matches[0]
             }
             $LastBackupDate = [datetime]::ParseExact($LastBackupDateString, 'MM/dd/yy hh:mmtt', [System.Globalization.CultureInfo]::GetCultureInfo('en-US')).ToString($DateFormat)
         } 
        else {
            $LastBackupDate = "null"
        }
        if ($LastBackupDate -ne "null") {
            $BackupUpdated =  $(NEW-TIMESPAN -Start $LastBackupDate -End $(Get-Date)).Days
        }
    }
        if ($null -ne $CrashPlanService) {
            if ($CrashPlanRunning) {
                if ($LogsLastUpdated -lt $MinDaysHealthy) {
                    if ($Authorized) {
                        if (!$UserHomeValid) {
                            $DetectionError = "Unhealthy. Authorized and running. UserHome Path does not exist on the system."
                            $ErrorStatus = 0
                        }
                        if ($BackupUpdated -eq "null") {
                            #SendLogs("Auth_no_recent_backup-$guid-")
                            $DetectionError = "Unhealthy. Authorized and running. Backup has not happened."
                            $ErrorStatus = 0
                    }
                    if ($BackupUpdated -le $MinDaysHealthy) {
                        $DetectionError = "Healthy. Authorized and running."
                        $ErrorStatus = 0
                    }
                    else {
                        if ($NothingToDoCount -gt 10) {
                            #SendLogs("Auth_no_recent_backup-$guid-")
                            $DetectionError = "Healthy. Authorized and running; days since last file sent=" + $BackupUpdated+"; Nothing to do count= $NothingToDoCount."
                            $ErrorStatus = 0   
                        }
                        else {
                            #SendLogs("Auth_no_recent_backup-$guid-")
                            $DetectionError = "Unhealthy. Authorized and running; backup has not happened for days=$BackupUpdated."
                            $ErrorStatus = 0   
                        }
                    }
                        else {
                            if ($RegisteredUser){
                                $DetectionError = "Unhealthy. Running not Authorized. Logs have not been updated for days=$LogsLastUpdated."
                                $ErrorStatus = 0
                            }
                            else{
                                if ($FirstDeployTimeSpan -lt $MinDaysHealthy) {
                                    $DetectionError = "Healthy. Likely not yet registered."
                                    $ErrorStatus = 0
                                }
                                else {
                                    #SendLogs("Not_yet_registered-$guid-")
                                    $DetectionError = "Unhealthy. Not registered for days= $FirstDeployTimeSpan."
                                    $ErrorStatus = 0
                                }
                        }
                    }
                }
                else {
                    #SendLogs("Logs_not_updating-")
                    $DetectionError = "Unhealthy. Logs have not been updated for days=$LogsLastUpdated."
                    $ErrorStatus = 1
                }
            }
        }
        else {
            #SendLogs("service_not_running-$guid-")
            $CrashPlanRunning = $false  
            $DetectionError = "Unhealthy. CrashPlan Service is not running. Logs last updated=$ServiceLogLastUpdated"
            $ErrorStatus = 1
        }
    }
    else {
        $DetectionError = "CrashPlan is not a service on this endpoint; likely not installed."
        $ErrorStatus = 1
    }
    $PreRemediationDetectionOutput = "Running:$CrashPlanRunning, State:[$DetectionError], Authorized: $Authorized, Logged in:$RegisteredUser, UserHome:$UserHome, UserHome valid:$UserHomeValid, Last Backup:$LastBackupDate, Logs last written:$ServiceLogLastUpdated, GUID:$Guid"
    #if you often export this file to process with excel or Google sheets replace the above line with this one for easier parsing of the data.
    #$PreRemediationDetectionOutput = "$CrashPlanRunning, $DetectionError, $Authorized, $RegisteredUser, $UserHome, $UserHomeValid, $LastBackupDate, $ServiceLogLastUpdated, $Guid"

    return @($ErrorStatus,$PreRemediationDetectionOutput)
}

$Output = CheckCrashPlanInstall

$ErrorStatus = $Output[0]
$PreRemediationDetectionOutput = $Output[1]

Write-Output $PreRemediationDetectionOutput

exit $ErrorStatus
