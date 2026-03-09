#!/bin/bash
#macuserdetection-plist.sh
#for Endpoint Backup Agents
#The following script is helpful if you use main MacOS MDMs for device management. 
#The script reads a plist on the local machine that is populated with the email associated with the device from the MDM.  
#It checks for JAMF Connect Plist, Kandji Global Variable Plist, Okta Network User Plist, or the CrashPlan Plist
#last updated Mar 9, 2026
function main () { 
    userrealname=$(id -P $(stat -f%Su /dev/console) | cut -d : -f 8)
    user=$(echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }')
    jamfplistuser=$(defaults read "/Users/$user/Library/Preferences/com.jamf.connect.state" DisplayName)
    jamfplistsystemuser=$(defaults read "/Library/Managed Preferences/com.jamf.connect.state" DisplayName)
    crashplanplistuser=$(defaults read "/Library/Managed Preferences/com.crashplan.email" crashplanActivationEmail)
    kandjiplistuser=$(defaults read "/Library/Managed Preferences/io.kandji.globalvariables" EMAIL)
    kandjiplisteuser=$(defaults read "/Library/Managed Preferences/io.kandji.extensions" EMAIL)
    kandjiplistduser=$(dscl . -read /Users/$user dsAttrTypeNative:io.kandji.KandjiLogin.LinkedAccount 2>/dev/null | awk -F ': ' '{print $2}')
    oktanetworkuser=$(dscl . -read /Users/$user dsAttrTypeStandard:NetworkUser 2>/dev/null | awk -F ': ' '{print $2}')
    dLocalHostName=$(scutil --get LocalHostName)

    currentdate=$(date)
    AGENT_USERNAME=""
    AGENT_USERNAME="@logged in user ($user)"
    writeLog "---"
    writeLog "-----------------------------------User Detection Run Start-----------------------------------"
    writeLog "---"
    writeLog "Running user detection script: macuserdetection-plist.sh"
    writeLog "Starting user detection...version 2025-03-09"
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
    writeLog "kandjiplistduser: ($kandjiplistduser)"
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
    if [[ ! $kandjiplistduser =~ "@"  ]] || [[ $jamfplistuser =~ "dsAttrTypeNative:io.kandji.KandjiLogin.LinkedAccount" ]]; then 
    	kandjiplistduser="" 
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

    #Start of Plist Logic
    writeLog "~"
    if [[ "$user" =~ ^(admin1|admin2|admin3)$ ]] || [[ -z "$user" ]]; then
        writeLog "Excluded or null username detected ($user). Will retry user detection in 60 minutes, or when reboot occurs."
        exit
    else
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
      	elif [[ -n "$kandjiplistduser" ]]; then
      		writeLog "Using Kandji Config Profile PLIST ($kandjiplistduser)"
      		AGENT_USERNAME="$kandjiplistduser"
      	elif [[ -n "$oktanetworkuser" ]]; then
      		writeLog "Using Okta Config Profile PLIST ($oktanetworkuser)"
      		AGENT_USERNAME="$oktanetworkuser"
      	elif [[ -n "$crashplanplistuser" ]]; then
      	    writeLog "Using JAMF Connect PLIST ($crashplanplistuser)"
      	    AGENT_USERNAME="$crashplanplistuser"
      	elif [[ -z "$jamfplistuser" ]] && [[ -z "$crashplanplistuser" ]]; then
    		writeLog "Known PLISTs empty $crashplanplistuser($crashplanplistuser) $jamfplistuser($jamfplistuser)"
    		if [[ -z "$kandjiplistuser" ]] && [[ -z "$oktanetworkuser" ]]; then
    			writeLog "Known PLISTs empty $kandjiplistuser($kandjiplistuser) $oktanetworkuser($oktanetworkuser)"
    		fi
      	    AGENT_USERNAME="@PLIST(s) are empty"
      	fi
        writeLog "Username read from plist ($AGENT_USERNAME)"
        AGENT_USER_HOME=$(dscl . -read "/users/$user" NFSHomeDirectory | cut -d ' ' -f 2)
        writeLog "Home directory read from dscl ($AGENT_USER_HOME)"
        writeLog "Returning AGENT_USERNAME=$AGENT_USERNAME"
        writeLog "Returning AGENT_USER_HOME=$AGENT_USER_HOME"
        echo "AGENT_USERNAME=$AGENT_USERNAME"
        echo "AGENT_USER_HOME=$AGENT_USER_HOME"
    fi
}
function writeLog () {
    echo "$(date) - $@" >> /Library/Application\ Support/CrashPlan/log/userDetect_Result.log
    echo "$@"
}
main "$@"