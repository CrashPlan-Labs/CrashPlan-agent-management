# CrashPlan Endpoint Management Scripts

## Overview
These scripts detect the health status of CrashPlan installations across macOS and Windows endpoints. They support auto-remediation when paired with reinstall scripts elsewhere in the CrashPlan Labs repo.

## Scripts

### CrashPlan-LocalStats.sh
**Platform:** macOS  
**Primary Use:** JAMF extension attribute  
**Flexibility:** Can be modified for other deployment platforms

Parses local CrashPlan log files to determine health status. Monitors key conditions including:
- Device authorization status
- Backup recency (within configurable threshold, default 7 days)
- Log update frequency
- User home path validity

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

### Detect_CrashPlan_Status.ps1
**Platform:** Windows  
**Primary Use:** Intune integration (default support)

Parses local CrashPlan log files and evaluates health conditions. Monitors for:
- Service running status
- Device authorization and user registration
- Backup activity and log freshness
- User home path accessibility
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
Exit code 0 (healthy/no action needed) or 1 (remediation needed). Returns comma-separated values or structured text with full system details.

**Auto-Remediation:**
Use exit codes with Intune remediation scripts to automatically trigger reinstalls when unhealthy conditions are detected.

### CrashPlan-Alert_State.sh
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
| LocalStats & Detect_CrashPlan | Log-Based | Parses app, service, and backup logs for comprehensive health analysis |
| Alert_State | API-Based | Directly queries console for device alert state; independent of local logs |

## Remediation
Available remediation scripts for automated healing: https://github.com/CrashPlan-Labs/CrashPlan-agent-management/tree/main/install_uninstall

