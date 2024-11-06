#!/bin/sh
#To be used when needing to manually install CrashPlan and want to use a deployment policy.  
#Must be run as root.
#Change the DEPLOYMENT_OPTIONS, to the one for your deployment policy. 
#Modify the completeUninstall if you want to remove the .identity file.

DEPLOYMENT_OPTIONS="OPTIONS_FROM_FROM_CONSOLE"

#Create Directory if it does not exist  
mkdir -p "/usr/local/crashplan/tmp/"
mkdir -p "/usr/local/crashplan/log/"
file="/usr/local/crashplan/tmp/scriptInstall.log"

#Download the latest-linux client.
echo "Downloading the latest linux client" | tee -a "$file"
if [ ! -f "/usr/local/crashplan/tmp/latest-linux.tgz" ];
then
    curl -L https://download.crashplan.com/installs/agent/latest-linux.tgz --output "/usr/local/crashplan/tmp/latest-linux.tgz"
fi
tar fax "/usr/local/crashplan/tmp/latest-linux.tgz"

#If CrashPlan was already installed, uninstall
if [ -d /usr/local/crashplan/bin ];
then
	echo "Found a previous install of CrashPlan. Uninstalling." | tee -a "$file"
	echo "Uninstalling via uninstall.sh" | tee -a "$file"
	/usr/local/crashplan/tmp/crashplan-install/uninstall.sh -i "/usr/local/crashplan" -y -l "/usr/local/crashplan/log/uninstall.log"
else
	echo "Could not find a previous install." | tee -a "$file"
fi

#Trigger install of the app
/usr/local/crashplan/tmp/crashplan-install/install.sh -q -l "/usr/local/crashplan/log/install.log" -d "$DEPLOYMENT_OPTIONS" || exit "$?"

echo "Successfully installed CrashPlan"| tee -a "$file"
echo ""

# move logs to CrashPlan log dir
cp $file "/usr/local/crashplan/log/scriptInstall.log"
if [ -f ${WORK_DIR}/uninstall.log ];
then
	mv ${WORK_DIR}/uninstall.log /usr/local/crashplan/log
fi

rm -r /usr/local/crashplan/tmp/
echo "Finished install and cleanup" | tee -a "/usr/local/crashplan/log/scriptInstall.log"
