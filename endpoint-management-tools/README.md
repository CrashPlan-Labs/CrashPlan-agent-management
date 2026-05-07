# CrashPlan Endpoint Management Scripts

## Overview
These scripts detect the health status of CrashPlan installations across macOS and Windows endpoints. They support auto-remediation when paired with reinstall scripts elsewhere in the CrashPlan Labs repo.

## Scripts

### CrashPlan-Local-Health-Attribute.sh
**Platform:** macOS  
**Primary Use:** JAMF extension attribute  
**Flexibility:** Can be modified for other deployment platforms

Parses local CrashPlan log files to determine health status. Monitors key conditions including:
- Device authorization status
- Backup recency (within configurable threshold, default 7 days)
- Log update frequency
- userHome path validity

Returns detailed information suitable for inventory and reporting.

**Installation:**
- **JAMF:** Add as an Extension Attribute script, set to run as root
- **Manual/MDM Alternative:** Execute directly via SSH or configuration management tool

**Configuration:**
- **Health Threshold:** Change `min_days_healthy=7` at the top of the script to adjust the number of days before marking unhealthy
- No API credentials required

**Output:**
XML-formatted status and details including authorization state, backup date, and GUID.

**Auto-Remediation:**
Pair with CrashPlan reinstall scripts to automatically remediate unhealthy installations detected via JAMF policies.

**Health States:**

| Message | Action |
|---------|--------|
| **Healthy. Recent Backup.** | None. CrashPlan is functioning correctly. |
| **Healthy. System is likely not yet registered.** | None. Device was installed recently and has not yet detected a user. |
| **Unhealthy. Logs not updating.** | Confirm settings are correct, then pull logs and determine issues. If CrashPlan is also not running, perform Uninstall/Reinstall. |
| **Unhealthy. System is Authorized, No recent backup.** | Confirm settings are correct, then pull logs and determine issues. |
| **Unhealthy, userHome path does not exist.** | CrashPlan has likely detected the wrong user. Confirm detection logic is valid. Then Uninstall/Reinstall. |
| **Unhealthy. System not yet registered.** | Determine why user detection is failing, then resolve. |
| **Unhealthy. System is Deauthorized.** | Reauthorize the device, or perform Uninstall/Reinstall. |

**JAMF Regex Patterns:**
```
.*\[Healthy. Recent Backup.\].*
.*\[Unhealthy, userHome path does not exist.\].*
.*\[Unhealthy. System is Authorized, No recent backup.\].*
.*\[Unhealthy. Logs not updating.\].*
.*\[Healthy. System is likely not yet registered.\].*
.*\[Unhealthy. System not yet registered.\].*
.*\[Unhealthy. System is Deauthorized.\].*
```

### CrashPlan-Detect-Health-Status.ps1
**Platform:** Windows  
**Primary Use:** Intune integration (default support)

Parses local CrashPlan log files and evaluates health conditions. Monitors for:
- Service running status
- Device authorization and user registration
- Backup activity and log freshness
- userHome path accessibility
- Excluded user patterns

Returns exit codes (0 = healthy/no action needed, 1 = remediation needed) suitable for Intune detection scripts.

**Installation:**
- **Intune:** Add as a Detection Script in device compliance policy
- **Configuration Manager:** Deploy as a detection method
- **Group Policy:** Execute via scheduled task (run as SYSTEM)

**Configuration:**
- **Health Threshold:** Change `$MinDaysHealthy = 7` at the top of the script to adjust the number of days before marking unhealthy
- **Excluded Users:** Configure `$ExcludedUsers` array to mark specific user accounts as unhealthy (e.g., excluded service accounts)

**Output:**
Exit Code 0 (healthy/no action needed) or 1 (remediation needed). Returns comma-separated values or structured text with full system details.

**Auto-Remediation:**
Use exit codes with Intune remediation scripts to automatically trigger reinstalls when unhealthy conditions are detected.

**Exit Codes and Health States:**

**Exit Code 0 - Healthy (No action needed)**
- Healthy. Authorized and running.
- Healthy. Likely not yet registered.

**Exit Code 0 or 1 - Monitor (Action may be needed)**
- Unhealthy. Authorized and running but userHome path does not exist on the system → Trigger a reinstall to fix.
- Unhealthy. Authorized and running but Backup has not happened → Check settings and userHome validity.
- Unhealthy. Authorized and running; backup has not happened for days=X → Check settings and pull logs.
- Unhealthy. Not registered for days=X → Check detection logic and userHome configuration.
- Unhealthy. Running not Authorized. Logs have not been updated for days=X → Check settings and pull logs.

**Exit Code 1 - Unhealthy (Remediation needed)**
- Unhealthy. Logs have not been updated for days=X → Grab logs, then Uninstall/Reinstall.
- Unhealthy. CrashPlan Service is not running. Logs last updated=X → Start service or investigate logs.
- Unhealthy. CrashPlan is not a service on this endpoint; likely not installed. → Trigger install if needed.
- Unhealthy. Deauthorized. → Grab logs, then Uninstall/Reinstall.
- Unhealthy. Found excluded user. → Trigger reinstall to fix.

**Log Upload Configuration:**
The script supports optional log uploading via ShareFile or local network shares. To enable:

As part of remediation workflows you can optionally collect logs by invoking the `CrashPlan-Collect-Logs.ps1` collector (see the "Log Collection" section below).

### CrashPlan-API-Alert-Attribute.sh
**Platform:** macOS  
**Primary Use:** Simple API-based status check

Queries the CrashPlan console API to retrieve device alert states. Uses OAuth client credentials to authenticate and fetch real-time device health from the console.

Advantages:
- No dependency on local log parsing
- Centralized monitoring via console
- Lightweight compared to log analysis

**Prerequisites:** CrashPlan API client credentials with Computer Read permission

**Installation:**
- Store API credentials securely (environment variables, MDM profiles, or secure vaults)
- Execute via JAMF as an Extension Attribute or as a standalone script
- Requires network connectivity to CrashPlan console

**Configuration:**
- **Console URL:** Set `CP_Console` to your CrashPlan console URL
- **API Credentials:** Set `clientID` and `secret` with OAuth credentials from the CrashPlan console (requires Computer Read permission)

**Output:**
XML-formatted response containing alert state or error message from the API.

## Key Differences

| Script | Method | Details |
|--------|--------|---------|
| CrashPlan-Local-Health-Attribute.sh & CrashPlan-Detect-Health-Status.ps1 | Log-Based | Parses app, service, and backup logs for comprehensive health analysis |
| CrashPlan-API-Alert-Attribute.sh | API-Based | Directly queries console for device alert state; independent of local logs |

## Remediation
Available remediation scripts for automated healing: https://github.com/CrashPlan-Labs/CrashPlan-agent-management/tree/main/install_uninstall

## Log Collection

Use `CrashPlan-Collect-Logs.ps1` to collect and package CrashPlan logs and system event information for troubleshooting. This collector is standalone and can be run on-demand or invoked from remediation workflows.

Quick usage:

Manual (on-demand):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "CrashPlan-Collect-Logs.ps1" -LogPrefix "Investigation-"
```

Invoke from detection/remediation (example):

```powershell
Start-Process -FilePath pwsh -ArgumentList '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$PSScriptRoot\CrashPlan-Collect-Logs.ps1"" -LogPrefix "Remediate-"' -Wait
```

Notes:
- The collector accepts `-LogPrefix` (defaults to "CrashPlan") and writes a zip named with the prefix and hostname.
- The collector can be used independently of remediation scripts or integrated into remediation workflows as needed.

