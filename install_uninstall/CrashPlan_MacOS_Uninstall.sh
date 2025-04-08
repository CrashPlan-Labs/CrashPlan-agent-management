# The section below uninstalls CrashPlan, if it is installed on the system.
if [[ -e /Library/Application\ Support/CrashPlan/ ]]; then
	launchctl unload /Library/LaunchDaemons/com.crashplan.engine.plist
	launchctl unload /Library/LaunchDaemons/com.code42.service.plist
	/Library/Application\ Support/CrashPlan/Uninstall.app/Contents/Resources/uninstall.sh
fi

# The section below removes the CrashPlan identity file. Uncomment the lines below if you wish to do a complete uninstall.
# rm -r /Library/Application\ Support/CrashPlan/