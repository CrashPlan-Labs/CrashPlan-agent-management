#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory = $false)]
    [string]$LogPrefix = "CrashPlan"
)

if (Test-Path -Path "C:\ProgramData\CrashPlan\.identity" -PathType Leaf) {
    $CrashPlanBasePath = "C:\ProgramData\CrashPlan"
    $UserInstall = $false
    $Guid = (Get-Content -Path "$CrashPlanBasePath\.identity" | Select-String 'guid').ToString().split("= ")[1]
} else {
    Get-ChildItem C:\Users | ForEach-Object {
        if (Test-Path "C:\Users\$($_.Name)\AppData\Local\CrashPlan\.identity" -PathType Leaf) {
            $CrashPlanBasePath = "C:\Users\$($_.Name)\AppData\Local\CrashPlan"
            $UserInstall = $true
            $Guid = (Get-Content -Path "$CrashPlanBasePath\.identity" | Select-String 'guid').ToString().split("= ")[1]
        }
    }
}
function SendLogs($preFix) {
    # The link below can be used in a standalone fashion to manually upload files to CrashPlan as well as with this script.
    $ShareFileLink = "Sharefile request link from CrashPlan Support"
    $ShareFile = $ShareFileLink.Split("-")[1]

    Copy-Item -Path "$CrashPlanBasePath\log\" -Destination "$CrashPlanBasePath\tmplog\" -Recurse

    $LogFile = "$preFix" + $(hostname) + "-" + $(Get-Date -Format FileDateUniversal) + ".zip"
    $evtx_name = "$preFix" + $(hostname) + "-System.evtx"
    $backupLogPath = "$CrashPlanBasePath\tmplog\$evtx_name"
    $EventViewerLog = Get-CimInstance Win32_NTEventlogFile | Where-Object LogfileName -EQ "System"
    Invoke-CimMethod -InputObject $EventViewerLog -MethodName BackupEventLog -Arguments @{ ArchiveFileName = $backupLogPath }

    Compress-Archive -Path "$CrashPlanBasePath\tmplog\*" -DestinationPath "$CrashPlanBasePath\$LogFile"
    $logZip = $CrashPlanBasePath + '\' + $LogFile

    # Uncomment below to upload to a shared folder.
    # $Destination = "\\netshare\DESTINATION\CrashPlan_Remediation_Logs" + $TimeStamp
    # Copy-Item -Path $logZip -Destination $Destination -Force

    # Uncomment below to upload to CrashPlan ShareFile
    # $shareFilePost = (curl.exe -X POST -F File1=@"$logZip" "https://crashplan.sf-api.com/sf/v3/Shares($ShareFile)/Upload?Method=standard&raw=false&fileName=+$LogFile")
    # $chunkUri = ($shareFilePost | ConvertFrom-Json).ChunkUri
    # curl.exe -k -F "File1=@$logZip" "$chunkUri"

    Remove-Item $CrashPlanBasePath\tmplog -Recurse
    Remove-Item $logZip
}

SendLogs -preFix $LogPrefix