#CrashPlan_Windows_Install.ps1

#Declare arguments and enter options. Modifications of options are only here at the beginning of the script.
#CrashPlan Arguments are found in the Admin console under client management/Deployment 
$CrashPlanArguments=''
#Change $CrashPlanMSI to a different path if you want to use a local installer and not one downloaded from the internet
$CrashPlanMSI = "C:\ProgramData\CrashPlan\CrashPlan.msi"
#defining download location for latest CrashPlan client. Not used if $CrashPlanMSI is changed.
$latestWindowsClient="https://download.crashplan.com/installs/agent/latest-win64.msi"
#Log file location
$ProcLog = "C:\ProgramData\CrashPlan\CrashPlan_Script_install.log"

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
        foreach ($ProcessName in $Processes) {
            # Check if the process exists and kill it
            $Process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
            if ($Process) {
                Stop-Process -Name $ProcessName -Force -ErrorAction Stop
                while (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue) {
                    Start-Sleep -Seconds 1
                }
                Write-Log "Stop-CrashPlanServices: Successfully stopped process $ProcessName."
            } else {
                Write-Log "Stop-CrashPlanServices: Service $ProcessName does not exist or is not running."
            }
        }
        foreach ($Service in $Services) {
            # Check if the service exists and is running
            $svc = Get-Service -Name $Service -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -eq 'Running') {
                # Attempt to stop the service
                Stop-Service -Name $Service -Force -ErrorAction Stop
                # Wait until the service is stopped
                $svc.WaitForStatus('Stopped', [TimeSpan]::FromMinutes(1))
                Write-Log "Stop-CrashPlanServices: Successfully stopped service $Service."
            } else {
                Write-Log "Stop-CrashPlanServices: Service $Service does not exist or is not running."
            }
        }
        return $true
    } catch {
        Write-Log "Stop-CrashPlanServices: Failed to stop service $Service or kill process $ProcessName. $_"
        return $false
    }
}

function Uninstall-CrashPlan() {
    Get-InstalledApplications | Where-Object DisplayName -Match "(CrashPlan|Code42)" | ForEach-Object {
        if ($_.QuietUninstallString) {
            Write-Log "Uninstalling $($_.DisplayName), $($_.DisplayVersion)  using Quiet Uninstall String"
            Write-Log $_.QuietUninstallString
            & cmd.exe /c $_.QuietUninstallString
        }
        elseif ($_.UninstallString -like 'msiexec*') {
            Write-Log "Uninstalling $($_.DisplayName), $($_.DisplayVersion) using msiexec /quiet /norestart"
            Write-Log $_.uninstallString
            & cmd.exe /c $_.UninstallString /quiet /norestart 
        }
        else {
            Write-Log "Uninstalling $($_.DisplayName), $($_.DisplayVersion) using provided uninstall string"
            Write-Log $_.uninstallString
            & cmd.exe /c $_.UninstalString
        }
    }
    Get-ChildItem "C:\ProgramData\CrashPlan\" -Exclude "log",".identity","CrashPlan_Script_reinstall.log" | Remove-Item -Recurse -Force
}

if(!(Test-Path -Path "C:\ProgramData\CrashPlan\" )){
    New-Item -ItemType directory -Path "C:\ProgramData\CrashPlan\" 
    Write-Log "Created Log Directory"
}

Write-Log "Starting CrashPlan Remediation script."

#stop CrashPlan Services.
Stop-CrashPlanServices
#always start by uninstalling CrashPlan
Uninstall-CrashPlan

#Download CrashPlan.
#Set the security protocol to TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if( $CrashPlanMSI -eq "C:\ProgramData\CrashPlan\CrashPlan.msi")
{
    Write-Log "Downloading CrashPlan MSI"
    $client = New-Object System.Net.WebClient
    $client.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    $client.DownloadFile($latestWindowsClient, $CrashPlanMSI)
}

#trigger CrashPlan install.
Write-Log "Installing CrashPlan"
Write-Log "/i $CrashPlanMSI $CrashPlanArguments"
$InstallLog =  "C:\ProgramData\CrashPlan\install.msi.log"
$InstallArgs = "/i $CrashPlanMSI $CrashPlanArguments /l*v $InstallLog"

Start-Process "msiexec.exe" -Wait -ArgumentList $InstallArgs -NoNewWindow
start-sleep 30
Write-Log "Removing $CrashPlanMSI "
Remove-item $CrashPlanMSI

$CrashPlanInstalled = Get-InstalledApplications | Where-Object DisplayName -Match "(CrashPlan)"
if ($CrashPlanInstalled){
    write-Log "$($CrashPlanInstalled.DisplayName) $($CrashPlanInstalled.DisplayVersion) is now installed"
}
else{
    Write-Log "CrashPlan was not installed."
}

if(Test-Path -Path "C:\ProgramData\CrashPlan\log\" ){
    Move-Item $ProcLog "C:\ProgramData\CrashPlan\log\CrashPlan_Script_install.log"
    Move-Item $InstallLog "C:\ProgramData\CrashPlan\log\install.msi.log"
}