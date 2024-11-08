#CrashPlan_Windows_Install.ps1

#Declare arguments and enter options. Modifications of options are only here at the beginning of the script.
#CrashPlan Arguments are found in the Admin console under client management/Deployment 
$CrashPlanArguments=''
#Change $CrashPlanMSI to a different path if you want to use a local installer and not one downloaded from the internet
$CrashPlanMSI = "C:\ProgramData\CrashPlan\CrashPlan.msi"
#defining download location for latest CrashPlan client. Not used if $CrashPlanMSI is changed.
$latestWindowsClient="https://download.crashplan.com/installs/agent/latest-win64.msi"
#Log file location
$ProcLog = "C:\ProgramData\CrashPlan\CrashPlan_Script_reinstall.log"

#helper functions
function Write-Log {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$LogMessage
    )
    Add-Content -Path $ProcLog -Value (Write-Output ("{0} - {1}" -f (Get-Date), $LogMessage))
    write-host $LogMessage
}

# This function taken from https://xkln.net/blog/please-stop-using-win32product-to-find-installed-software-alternatives-inside/
function Get-InstalledApplications() {
    # Empty array to store applications
    $Apps = @()
    #Process registry to find CrashPlan 
    $32BitPath = "SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $64BitPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    Write-Log "Processing global hive"
    $Apps += Get-ItemProperty "HKLM:\$32BitPath"
    $Apps += Get-ItemProperty "HKLM:\$64BitPath"

    Write-Log "Processing current user hive"
    $Apps += Get-ItemProperty "Registry::\HKEY_CURRENT_USER\$32BitPath"
    $Apps += Get-ItemProperty "Registry::\HKEY_CURRENT_USER\$64BitPath"

    Write-Log "Collecting hive data for all users"
    $AllProfiles = Get-CimInstance Win32_UserProfile | Select-Object LocalPath, SID, Loaded, Special | Where-Object {$_.SID -like "S-1-5-21-*"}
    $MountedProfiles = $AllProfiles | Where-Object {$_.Loaded -eq $true}
    $UnmountedProfiles = $AllProfiles | Where-Object {$_.Loaded -eq $false}

    Write-Log "Processing mounted hives"
    $MountedProfiles | ForEach-Object {
        $Apps += Get-ItemProperty -Path "Registry::\HKEY_USERS\$($_.SID)\$32BitPath"
        $Apps += Get-ItemProperty -Path "Registry::\HKEY_USERS\$($_.SID)\$64BitPath"
    }
    Write-Log "Processing unmounted hives"
    $UnmountedProfiles | ForEach-Object {
        $Hive = "$($_.LocalPath)\NTUSER.DAT"
        Write-Log " -> Mounting hive at $Hive"
        if (Test-Path $Hive) {
            REG LOAD HKU\temp $Hive
            $Apps += Get-ItemProperty -Path "Registry::\HKEY_USERS\temp\$32BitPath"
            $Apps += Get-ItemProperty -Path "Registry::\HKEY_USERS\temp\$64BitPath"
            # Run manual GC to allow hive to be unmounted
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            REG UNLOAD HKU\temp
        } else {
            Write-Warning "Unable to access registry hive at $Hive"
        }
    }
    Write-Output $Apps
}

function Stop-CrashPlanServices {
    # Services to stop
    $Services = @("CrashPlanService", "Code42Service")
    $Processes = @("CrashPlanService","CrashPlanDesktop")
 
    try {
        foreach ($processName in $Processes) {
            # Check if the process exists and kill it
            $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($process) {
                Stop-Process -Name $processName -Force -ErrorAction Stop
                while (Get-Process -Name $processName -ErrorAction SilentlyContinue) {
                    Start-Sleep -Seconds 1
                }
                Write-host "Stop-CrashPlanServices: Successfully stopped process $processName."
            } else {
                Write-host "Stop-CrashPlanServices: Service $processName does not exist or is not running."
            }
        }
        foreach ($service in $Services) {
            # Check if the service exists and is running
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -eq 'Running') {
                # Attempt to stop the service
                Stop-Service -Name $service -Force -ErrorAction Stop
                # Wait until the service is stopped
                $svc.WaitForStatus('Stopped', [TimeSpan]::FromMinutes(1))
                Write-host "Stop-CrashPlanServices: Successfully stopped service $service."
            } else {
                Write-host "Stop-CrashPlanServices: Service $service does not exist or is not running."
            }
        }
        return $true
    } catch {
        Write-Log "Stop-CrashPlanServices: Failed to stop service $service or kill process $processName. $_"
        return $false
    }
}

function Uninstall-CrashPlan() {
    Get-InstalledApplications | Where-Object DisplayName -Match "(CrashPlan)" | ForEach-Object {
        if ($_.QuietUninstallString) {
            Write-Log "Uninstalling $($_.DisplayName) using Quiet Uninstall String"
            Write-Log $_.QuietUninstallString
            & cmd.exe /c $_.QuietUninstallString
        }
        elseif ($_.UninstallString -like 'msiexec*') {
            Write-Log "Uninstalling $($_.DisplayName) using msiexec /quiet /norestart"
            Write-Log $_.uninstallString
            & cmd.exe /c $_.UninstallString /quiet /norestart 
        }
        else {
            Write-Log "Uninstalling $($_.DisplayName) using provided uninstall string"
            Write-Log $_.uninstallString
            & cmd.exe /c $_.UninstalString
        }
    }
}

if(!(Test-Path -Path "C:\ProgramData\CrashPlan\log\" )){
    New-Item -ItemType directory -Path "C:\ProgramData\CrashPlan\log\" 
    Write-Log "Created Log Directory"
}

#Script must be run as an administrator. This will make the script exit if it is not.
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup("Not running as administrator!",0,"CrashPlan pre-Install",0x1)
    Write-Log "Not running as administrator!"
    exit
}
Write-Log "Starting CrashPlan Reinstall script."
#stop CrashPlan Services.
Stop-CrashPlanServices
#always start by uninstlling CrashPlan
Uninstall-CrashPlan

#Download latest version of CrashPlan.
#Set the security protocol to TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if( $CrashPlanMSI -eq "C:\ProgramData\CrashPlan\CrashPlan.msi")
{
    Write-Log "Downloading latest version of CrashPlan MSI"
    $client = New-Object System.Net.WebClient
    $client.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    $client.DownloadFile($latestWindowsClient, $CrashPlanMSI)
    $cleanup = $true
}

#trigger CrashPlan install.
Write-Log "Installing CrashPlan for Cloud"
Write-Log "/i $CrashPlanMSI $CrashPlanArguments"
$installArgs = "/i $CrashPlanMSI $CrashPlanArguments"
Start-Process "msiexec.exe" -Wait -ArgumentList $installArgs

#wait for the install to complete and CrashPlan to start (by looking at the last write time of the history log) before continuing and removing data.
while ($true) {
    if (Test-Path "C:\ProgramData\CrashPlan\log\history.log.0") {
        $LastWriteTime = (Get-Item "C:\ProgramData\CrashPlan\log\history.log.0").LastWriteTime
        $TimeSinceUpdate = (New-TimeSpan -Start $LastWriteTime -End (Get-Date)).TotalSeconds
        
        if ($TimeSinceUpdate -le 10) {
            Write-Log "File exists and has been updated recently."
            break
        } else {
            Write-Log "File exists but has not been updated recently. Waiting..."
        }
    } else {
        Write-Log "log does not exist. Waiting..."
    }
    Start-Sleep -Seconds 5
}

if ($cleanup -eq $true)
{
    Write-Log "Removing $CrashPlanMSI file"
    Remove-item $CrashPlanMSI
}

Move-Item -Path $ProcLog -Destination "C:\ProgramData\CrashPlan\log\CrashPlan_Script_reinstall.log" -Force
Write-Log "Script Finished, Closing"