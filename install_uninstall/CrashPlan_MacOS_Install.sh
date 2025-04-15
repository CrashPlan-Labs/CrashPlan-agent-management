#!/bin/sh
#CrashPlan_MacOS_Install.sh
#To be used when needing to manually install CrashPlan and want to use a deployment policy.  
#Must be run as root.
#Change the DEPLOYMENT_POLICY_TOKEN, URL, and other options to the one for your deployment policy. 

deployProperties=""

#Create Directory if it does not exist  
mkdir -p /Library/Application\ Support/CrashPlan/
file="/Library/Application Support/CrashPlan/CrashPlanScriptInstall.log"

#If CrashPlan was already installed, try to uninstall from all possible locations
echo "Checking standard locations for CrashPlan." | tee -a "$file"
 if [[ -e /Library/Application\ Support/CrashPlan/ ]]; then
    if [ -e /Library/LaunchDaemons/com.CrashPlan.service.plist ]; then
        launchctl unload /Library/LaunchDaemons/com.CrashPlan.service.plist
        chmod -R 755 "/Library/Application Support/CrashPlan/"
        /Library/Application\ Support/CrashPlan/Uninstall.app/Contents/Resources/uninstall.sh > /dev/null
    elif [ -e /Library/LaunchDaemons/com.crashplan.engine.plist ]; then
        launchctl unload /Library/LaunchDaemons/com.crashplan.engine.plist
        chmod -R 755 "/Library/Application Support/CrashPlan/"
        /Library/Application\ Support/CrashPlan/Uninstall.app/Contents/Resources/uninstall.sh > /dev/null
    fi   
fi

# The section below uninstalls CrashPlan, if it is installed on the system per-user for any user on the system
echo "Checking for user-based installs for all users on the machine." | tee -a "$file"
for user in /Users/*; do
    echo "Checking user folder: $user" | tee -a "$file" 
    if [[ -e "$user/Library/Application Support/CrashPlan/" ]]; then
        if [ -e "$user/Library/LaunchAgents/com.code42.service.plist" ]; then
            launchctl unload "$user/Library/LaunchAgents/com.code42.service.plist"
            chmod -R 755 "$user/Library/Application Support/CrashPlan/"
            "$user/Library/Application Support/CrashPlan/Uninstall.app/Contents/Resources/uninstall.sh" > /dev/null
        elif [ -e "$user/Library/LaunchAgents/com.crashplan.engine.plist" ]; then
            launchctl unload "$user/Library/LaunchAgents/com.crashplan.engine.plist"
            chmod -R 755 "$user/Library/Application Support/CrashPlan/"
            "$user/Library/Application Support/CrashPlan/Uninstall.app/Contents/Resources/uninstall.sh" > /dev/null
        fi
        if [[ $completeUninstall == true ]]
        then
        #Clean up user's CrashPlan folder
            echo "Complete Uninstall being processed .... removing .identify file from user folder: $user" | tee -a "$file" 
            rm -r "$user/Library/Application Support/CrashPlan/"
        fi
    fi

done
#make CrashPlan folder since we are building things back up for the install
mkdir -p /Library/Application\ Support/CrashPlan/

echo "Downloading the latest mac client for Macs." | tee -a "$file"
appNewVersion=$( curl https://download.crashplan.com/installs/agent/latest-mac.dmg  -s -L -I -o /dev/null -w '%{url_effective}' | cut -d "/" -f7 )
echo "Installing version $appNewVersion" | tee -a "$file"
curl -L "https://download.crashplan.com/installs/agent/latest-mac.dmg" --output "/Library/Application Support/CrashPlan/CrashPlanInstaller.dmg"

#Create deployment.properties file
echo "$deployProperties" > /Library/Application\ Support/CrashPlan/deploy.properties | tee -a "$file"
#Trigger install of the .dmg
echo "Installing the new version." | tee -a "$file"
hdiutil attach "/Library/Application Support/CrashPlan/CrashPlanInstaller.dmg" -quiet -nobrowse
while ! test -f /Volumes/CrashPlan/Install\ CrashPlan.pkg
do
	sleep 3
	printf "."
done

installer -package /Volumes/CrashPlan/Install\ CrashPlan.pkg -target /

CrashPlanRunning="$(/usr/bin/pgrep "CrashPlanService")"

until [[ -n $(/usr/bin/pgrep "CrashPlanService") ]];do
    sleep 10
	printf "waiting for CrashPlan to Start."
done

echo "Successfully installed CrashPlan."| tee -a "$file"
echo ""
hdiutil detach /Volumes/CrashPlan

rm "/Library/Application Support/CrashPlan/CrashPlanInstaller.dmg"
echo "Finished install and cleanup." | tee -a "$file"

mv "$file" /Library/Application\ Support/CrashPlan/log/CrashPlan/CrashPlanScriptInstall.log
echo "Install log file can be found in //Library/Application\ Support/CrashPlan/log/" | tee -a "$file"