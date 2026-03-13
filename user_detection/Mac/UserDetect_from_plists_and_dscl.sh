#!/bin/bash
#UserDetect_from_plists_and_dscl.sh
#for Endpoint Backup Agents
#The following script is helpful if you use main MacOS MDMs for device management. 
#The script reads a plist on the local machine that is populated with the email associated with the device from the MDM.  
#It checks for JAMF Connect Plist, Kandji Global Variable Plist, Okta Network User Plist, or the CrashPlan Plist
#last updated Mar 13, 2026
function main () { 
    # Define admin usernames
    ADMIN_USERS=("admin1" "admin2" "admin3")

    userrealname=$(id -P $(stat -f%Su /dev/console) | cut -d : -f 8)
    user=$(echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }')
    jamfplistuser=$(defaults read "/Users/$user/Library/Preferences/com.jamf.connect.state" DisplayName)
    jamfplistsystemuser=$(defaults read "/Library/Managed Preferences/com.jamf.connect.state" DisplayName)
    crashplanplistuser=$(defaults read "/Library/Managed Preferences/com.crashplan.email" crashplanActivationEmail)
    kandjiplistuser=$(defaults read "/Library/Managed Preferences/io.kandji.globalvariables" EMAIL)
    kandjiplisteuser=$(defaults read "/Library/Managed Preferences/io.kandji.extensions" EMAIL)
    kandjidscluser=$(dscl . -read /Users/$user dsAttrTypeNative:io.kandji.KandjiLogin.LinkedAccount 2>/dev/null | awk -F ': ' '{print $2}')
    oktanetworkuser=$(dscl . -read /Users/$user dsAttrTypeStandard:NetworkUser 2>/dev/null | awk -F ': ' '{print $2}')
    dLocalHostName=$(scutil --get LocalHostName)

    currentdate=$(date)
    AGENT_USERNAME=""
    writeLog "---"
    writeLog "-----------------------------------User Detection Run Start-----------------------------------"
    writeLog "---"
    writeLog "Running user detection script: UserDetect_from_plists_and_dscl.sh"
    writeLog "Starting user detection...version 2026-03-13"
    writeLog "$currentdate"
    writeLog "LocalHostName found ($dLocalHostName)"
    writeLog "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    writeLog "userrealname: ($userrealname)"
    writeLog "local user: ($user)"
    writeLog "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    writeLog "jamfplistuser: ($jamfplistuser)"
    writeLog "jamfplistsystemuser: ($jamfplistsystemuser)"
    writeLog "kandjiplistuser: ($kandjiplistuser)"
    writeLog "kandjiplisteuser: ($kandjiplisteuser)"
    writeLog "kandjidscluser: ($kandjidscluser)"
    writeLog "oktanetworkuser: ($oktanetworkuser)"
    writeLog "crashplanplistuser: ($crashplanplistuser)"
    writeLog "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    if [[ ! $jamfplistuser =~ "@" ]] || [[ $jamfplistuser =~ "com.jamf.connect.state" ]]; then 
    	jamfplistuser="" 
    fi
    if [[ ! $jamfplistsystemuser =~ "@" ]] || [[ $jamfplistsystemuser =~ "com.jamf.connect.state.plist" ]]; then 
    	jamfplistsystemuser="" 
    fi
    if [[ ! $kandjiplistuser =~ "@"  ]] || [[ $jamfplistuser =~ "io.kandji.globalvariables.plist" ]]; then 
    	kandjiplistuser="" 
    fi    
    if [[ ! $kandjiplisteuser =~ "@"  ]] || [[ $jamfplistuser =~ "io.kandji.globalvariables.plist" ]]; then 
    	kandjiplisteuser="" 
    fi    
    if [[ ! $kandjidscluser =~ "@"  ]] || [[ $jamfplistuser =~ "dsAttrTypeNative:io.kandji.KandjiLogin.LinkedAccount" ]]; then 
    	kandjidscluser="" 
    fi    
    if [[ ! $oktanetworkuser =~ "@"  ]] || [[ $jamfplistuser =~ "doesn't exist" ]]; then 
    	oktanetworkuser="" 
    fi
    if [[ ! $crashplanplistuser =~ "@"  ]] || [[ $jamfplistuser =~ "doesn't exist" ]]; then 
    	crashplanplistuser="" 
    fi
    for userhome in /Users/*; do
        writeLog "Users: ($userhome)"
    done

    writeLog "~"
    # Check if user is in admin list
    is_admin=0
    for admin in "${ADMIN_USERS[@]}"; do
        if [[ "$user" == "$admin" ]]; then
            is_admin=1
            break
        fi
    done
    if [[ $is_admin -eq 1 ]] || [[ -z "$user" ]]; then
        writeLog "Excluded or null username detected ($user). Will retry user detection in 60 minutes, or when reboot occurs."
        exit
    fi
    
    #Start of Plist Logic
    if [[ -n "$jamfplistuser" ]]; then
        writeLog "Using JAMF Config Profile PLIST ($jamfplistuser)"
        AGENT_USERNAME="$jamfplistuser"
    elif [[ -n "$jamfplistsystemuser" ]]; then
        writeLog "Using JAMF Config Profile PLIST ($jamfplistsystemuser)"
        AGENT_USERNAME="$jamfplistsystemuser"
    elif [[ -n "$kandjiplistuser" ]]; then
        writeLog "Using Kandji Config Profile PLIST ($kandjiplistuser)"
        AGENT_USERNAME="$kandjiplistuser"
    elif [[ -n "$kandjiplisteuser" ]]; then
        writeLog "Using Kandji Config Profile PLIST ($kandjiplisteuser)"
        AGENT_USERNAME="$kandjiplisteuser"
    elif [[ -n "$kandjidscluser" ]]; then
        writeLog "Using Kandji Config Profile PLIST ($kandjidscluser)"
        AGENT_USERNAME="$kandjidscluser"
    elif [[ -n "$oktanetworkuser" ]]; then
        writeLog "Using Okta Config Profile PLIST ($oktanetworkuser)"
        AGENT_USERNAME="$oktanetworkuser"
    elif [[ -n "$crashplanplistuser" ]]; then
        writeLog "Using JAMF Connect PLIST ($crashplanplistuser)"
        AGENT_USERNAME="$crashplanplistuser"
    elif [[ -z "$jamfplistuser" && -z "$jamfplistsystemuser" && -z "$kandjiplistuser" && -z "$kandjiplisteuser" && -z "$kandjidscluser" && -z "$oktanetworkuser" && -z "$crashplanplistuser" ]]; then
        # none of the plist lookups returned a value
        writeLog "Known MDM variables empty"
    fi

    writeLog "Username read from plist ($AGENT_USERNAME)"
    AGENT_USER_HOME=$(dscl . -read "/users/${user}" NFSHomeDirectory | cut -d ' ' -f 2)
    writeLog "Home directory read from dscl ($AGENT_USER_HOME)"
    writeLog "~"
    writeLog "Returning AGENT_USERNAME=$AGENT_USERNAME"
    writeLog "Returning AGENT_USER_HOME=$AGENT_USER_HOME"
    writeLog "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "AGENT_USERNAME=$AGENT_USERNAME"
    echo "AGENT_USER_HOME=$AGENT_USER_HOME"
}
function writeLog () {
    echo "$(date) - $@" >> /Library/Application\ Support/CrashPlan/log/userDetect_Result.log
    echo "$@"
}
main "$@"
