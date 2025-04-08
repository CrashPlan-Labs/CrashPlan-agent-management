#!/bin/zsh
#set -x #echo on

#This script parses CrashPlan logs for values, and performs some logic with them to determine the status of the CrashPlan install.

#The Following are the possible values for CrashPlan_message. These are states that CrashPlan can be in. Some of them have actions that can be taken to resolve the issue.
    #Message: "Healthy. Recent Backup." 
    #Action: None. CrashPlan is functioning correctly.
    #Message: "Unhealthy, userHome path doesn't exist."
    #Action: CrashPlan has likely detected the wrong user. Confirm that the detected user is accurate for the machine, and that your userHome detection logic is valid. Then Uninstall/Reinstall.
    #Message: "Unhealthy. System is Authorized, No recent backup."
    #Action: Confirm settings are correct, then pull logs and determine issues.
    #Message: "Unhealthy. Logs not updating."
    #Action: Confirm settings are correct, then pull logs and determine issues. If CrashPlan is also not running then after confirming no systematic issues Uninstall/Reinnstall.
    #Message: "Healthy. System is likely not yet registered."
    #Action: None. Device was installed recently and has not yet detected a user.
    #Message: "Unhealthy. System not yet registered."
    #Action: Determine why user detection is failing. Then resolve
    #Message: "Unhealthy. System is Deauthorized."
    #Action: Reauthorize the device, Uninstall, or Uninstall/Reinstall CrashPlan

#Regex for matching within jamf:
    #.*\[Healthy. Recent Backup.\].* 
    #.*\[Unhealthy, userHome path doesn't exist.\].*
    #.*\[Unhealthy. System is Authorized, No recent backup.\].*
    #.*\[Unhealthy. Logs not updating.\].*
    #.*\[Healthy. System is likely not yet registered.\].*
    #.*\[Unhealthy. System not yet registered.\].*
    #.*\[Unhealthy. System is Deauthorized.\].*

#Define min_days_healthy as the amount of days an agent can be unregistered, not be backing up, or have the logs not being updated for before switching to an error state.
min_days_healthy=7

# CrashPlan Application Path
CrashPlanPath="/Applications/CrashPlan.app"
guid=$(/usr/bin/awk -F '=' '/guid/{print $2}' /Library/Application\ Support/CrashPlan/.identity 2>/dev/null)

if [[ -d "$CrashPlanPath" ]]; then
    CrashPlan_base_log_directory_pre116="/Library/Logs/CrashPlan/"
    CrashPlan_base_log_directory_116="/Library/Application Support/CrashPlan/log/"
    if [[ -d "$CrashPlan_base_log_directory_pre116" ]]; then 
         CrashPlan_base_log_directory=$CrashPlan_base_log_directory_pre116
    else
        CrashPlan_base_log_directory=$CrashPlan_base_log_directory_116
    fi
else 
    for user in /Users/*; do
        if [[ -e "$user/Applications/CrashPlan.app" ]]; then
            CrashPlanPath="$user/Applications/CrashPlan.app"
            CrashPlan_base_log_directory_pre116="$user/Library/Logs/CrashPlan/"
            CrashPlan_base_log_directory_116="$user/Library/Application Support/CrashPlan/log/"
            if [[ -d "$CrashPlan_base_log_directory_pre116" ]]; then 
                CrashPlan_base_log_directory=$CrashPlan_base_log_directory_pre116
            else
                CrashPlan_base_log_directory=$CrashPlan_base_log_directory_116
            fi
            guid=$(/usr/bin/awk -F '=' '/guid/{print $2}' "$user"/Library/Application\ Support/CrashPlan/.identity 2>/dev/null)
            userInstall=". User based install."
        fi
    done
fi

# Sets value of CrashPlan Log files, change if running against local logs.
CrashPlanAppLog="${CrashPlan_base_log_directory}app.log"
CrashPlanServiceLog="${CrashPlan_base_log_directory}service.log.0"
CrashPlanBackupLog="${CrashPlan_base_log_directory}backup_files.log.0"
# Check if CrashPlan is installed before anything else, but record if a guid was found.
if [[ ! -d "$CrashPlanPath" ]]; then
    if [ -n "${guid}" ];then
        echo "<result>Not Installed${userInstall}</result>"
    else 
        echo "<result>Not Installed, but CrashPlan .identiy found guid:${guid}${userInstall}</result>"
    fi
    exit 0
fi
# Checks if CrashPlan Client is Running
CrashPlanRunning="$(/usr/bin/pgrep "CrashPlanService")"
#get values from the App Log. checking to see if the log they are in exists first.
if [ -f "${CrashPlanAppLog}" ];then
    #Get the Authorized status of the endpoint. True means that a user is assigned to the device. False could mean that it's in user detection mode
    Authorized=$(/usr/bin/awk '/ServiceModel.authorized/{print $3}' "$CrashPlanAppLog")
    #Not currently used. If value is 0, no user is activly logged in to CrashPlan, but the agent could be deactivated
    CrashPlanLoggedIn="$(/usr/bin/awk '/USERS/{getline; gsub("\,",""); print $1; exit }' "$CrashPlanAppLog")"
    #Gets CrashPlan username, this can be filled if Authorized  is false and Logged in is 0.
    CrashPlan_username="$(/usr/bin/awk '/USERS/{getline; gsub("\,",""); print $2; exit }' "$CrashPlanAppLog")"
    CrashPlan_userHome="$(/usr/bin/awk -F'[<>]' '/userHome/{print $3}' "$CrashPlanAppLog")"
    if [ -e "$CrashPlan_userHome" ]; then
        CrashPlan_userHome_valid="true"
    else
        CrashPlan_userHome_valid="false"
    fi
fi
#Find out if today is the first few days the agent was installed to be used if user detection is still running. 
# Also Grab the most recent day the service log was written to to indicate last time the service was running.
if [ -f "$CrashPlanServiceLog" ];then
    #Get the last time the service log updated. If the service is running then the log will exist, and be updated today.
    first_start_day=$(/usr/bin/awk '/STARTED CrashPlan Agent/{print substr($0,2,8);exit}' "$CrashPlanServiceLog")
    #If we don't have a first started value in the log then we are probably good so grab the first line from the service.log.0 and use that date
    if [ "${first_start_day}" = "" ];then
        first_start_day=$(/usr/bin/awk '/^\[/{print substr($0,2,8);exit}' "$CrashPlanServiceLog")
    fi
    first_start_day_seconds=$(/bin/date -jf "%m.%d.%y" "$first_start_day" +%s)
    days_since_first_start=$(($(( $(date +%s)   - $first_start_day_seconds)) / 86400))
    service_log_update_seconds=$(/bin/date -r "${CrashPlanServiceLog}" +%s)
    service_log_update_date=$(/bin/date -r "${CrashPlanServiceLog}" +%d-%b-%Y)
    days_since_logs_updated=$(($(( $(date +%s)   - $service_log_update_seconds)) / 86400))
fi
#Grab the last time the backup files log was written to as a successfully proxy for when backup last happened on an agent.
if [ -f "${CrashPlanBackupLog}" ];then 
    lastBackupDate_seconds=$(/bin/date -r "${CrashPlanBackupLog}" +%s) # $(cat /Library/Logs/CrashPlan/service.log.{2..0} 2>/dev/null | egrep 'Backup STOPPED|Backup COMPLETED'| tail -n 1)
    lastBackupDate_date=$(/bin/date -r "${CrashPlanBackupLog}" +%d-%b-%Y)
    days_since_last_backup=$(($(( $(date +%s)   - $lastBackupDate_seconds)) / 86400))
else
    days_since_last_backup="unknown"
fi
if [[ -n "${CrashPlanRunning}" ]];then
    CrashPlan_status="On${userInstall}"
else
    CrashPlan_status="Off${userInstall}"
fi
CrashPlan_message=""
#CrashPlan message
if [ "${Authorized}" = 'true' ];then
    if [ "$days_since_logs_updated" -lt "$min_days_healthy" ];then
        if [ "$days_since_last_backup" -le "$min_days_healthy" ];then
            if [ "$CrashPlan_userHome_valid" = 'true' ];then
                CrashPlan_message="Healthy. Recent Backup." 
            else
                CrashPlan_message="Unhealthy, userHome path does not exist."
            fi
        else
            CrashPlan_message="Unhealthy. System is Authorized, No recent backup."
        fi
    else
        CrashPlan_message="Unhealthy. Logs not updating."
    fi
else
    if [ "${CrashPlan_username}" = "" ];then
        if [ "$days_since_first_start" -lt "$min_days_healthy" ];then
            CrashPlan_message="Healthy. System is likely not yet registered."
        else 
            CrashPlan_message="Unhealthy. System not yet registered."
        fi
    else
        CrashPlan_message="Unhealthy. System is Deauthorized."
    fi
fi
echo "<result>Status: ${CrashPlan_status}\n Message:[${CrashPlan_message}]\n Logged in: ${CrashPlan_username}, UserHome:${CrashPlan_userHome}, UserHome valid: ${CrashPlan_userHome_valid}\n Last Backup:${lastBackupDate_date}\n Logs last written:${service_log_update_date}\nGuid: ${guid}</result>"