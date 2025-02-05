#Uninstall_CrashPlan.ps1

# This function taken from https://xkln.net/blog/please-stop-using-win32product-to-find-installed-software-alternatives-inside/
function Get-InstalledApplications() {
    # Empty array to store applications
    $Apps = @()
    #Process registry to find CrashPlan 
    $32BitPath = "SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    $64BitPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    Write-Host "Processing global hive"
    $Apps += Get-ItemProperty "HKLM:\$32BitPath"
    $Apps += Get-ItemProperty "HKLM:\$64BitPath"

    Write-Host "Processing current user hive"
    $Apps += Get-ItemProperty "Registry::\HKEY_CURRENT_USER\$32BitPath"
    $Apps += Get-ItemProperty "Registry::\HKEY_CURRENT_USER\$64BitPath"

    Write-Host "Collecting hive data for all users"
    $AllProfiles = Get-CimInstance Win32_UserProfile | Select-Object LocalPath, SID, Loaded, Special | Where-Object {$_.SID -like "S-1-5-21-*"}
    $MountedProfiles = $AllProfiles | Where-Object {$_.Loaded -eq $true}
    $UnmountedProfiles = $AllProfiles | Where-Object {$_.Loaded -eq $false}

    Write-Host "Processing mounted hives"
    $MountedProfiles | ForEach-Object {
        $Apps += Get-ItemProperty -Path "Registry::\HKEY_USERS\$($_.SID)\$32BitPath"
        $Apps += Get-ItemProperty -Path "Registry::\HKEY_USERS\$($_.SID)\$64BitPath"
    }
    Write-Host "Processing unmounted hives"
    $UnmountedProfiles | ForEach-Object {
        $Hive = "$($_.LocalPath)\NTUSER.DAT"
        Write-Host " -> Mounting hive at $Hive"
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
                Write-host "Stop-CrashPlanServices: Successfully stopped process $processName."
            } else {
                Write-host "Stop-CrashPlanServices: Service $processName does not exist or is not running."
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
                Write-host "Stop-CrashPlanServices: Successfully stopped service $Service."
            } else {
                Write-host "Stop-CrashPlanServices: Service $Service does not exist or is not running."
            }
        }
        return $true
    } catch {
        Write-Host "Stop-CrashPlanServices: Failed to stop service $Service or kill process $ProcessName. $_"
        return $false
    }
}

function Uninstall-CrashPlan() {
    #To also Uninstall versions before 11.x change to (CrashPlan|Code42)
    Get-InstalledApplications | Where-Object DisplayName -Match "(CrashPlan)" | ForEach-Object {
        if ($_.QuietUninstallString) {
            Write-Host "Uninstalling $($_.DisplayName) using Quiet Uninstall String"
            Write-Host $_.QuietUninstallString
            & cmd.exe /c $_.QuietUninstallString
        }
        elseif ($_.UninstallString -like 'msiexec*') {
            Write-Host "Uninstalling $($_.DisplayName) using msiexec /quiet /norestart"
            Write-Host $_.uninstallString
            & cmd.exe /c $_.UninstallString /quiet /norestart 
        }
        else {
            Write-Host "Uninstalling $($_.DisplayName) using provided uninstall string"
            Write-Host $_.uninstallString
            & cmd.exe /c $_.UninstalString
        }
    }
}

function Remove-CrashPlanDataFolders {
    #delete user level CrashPlan Directories
    get-childItem C:\Users | ForEach-Object $path {
        Write-Host "Trying C:\Users\$_\AppData\Local\CrashPlan"
        if ((Test-path C:\Users\$_\AppData\Local\CrashPlan)) {
            Write-Host "Found a user level CrashPlan Install or folder. Removing Directory."
            Remove-Item C:\Users\$_\AppData\Local\CrashPlan -Recurse -Force
        }
    }
    #Delete system level CrashPlan directories
    if ((Test-path C:\ProgramData\CrashPlan)) {
        Write-Host "Found a system level CrashPlan Install or old folder."
        Remove-Item C:\programData\CrashPlan -Recurse -Force
    }
}

#Script must be run as an administrator. This will make the script exit if it is not.
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup("Not running as administrator!",0,"CrashPlan pre-Install",0x1)
    Write-Host "Not running as administrator!"
    exit
}

Write-Host "Starting CrashPlan Uninstall script."
#stop CrashPlan Services.
Stop-CrashPlanServices
Uninstall-CrashPlan
#Uncomment the function call below if you want to delete CrashPlan directories after the install. Only used if you want to perminantly remove CrashPlan
#Remove-CrashPlanDataFolders

Write-Host "Script Finished"