function main() {
	writeLog "Starting user detection..."
    local user=$(echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }')
	writeLog "local user name found ($user)"
	if [[ "$user" =~ ^(admin1|admin2|admin3)$ ]] || [[ -z "$user" ]]; then
        writeLog "Excluded or null username detected ($user). Will retry user detection in 60 minutes, or when reboot occurs."
        exit
	else
		local serialNumber=$(ioreg -l | grep IOPlatformSerialNumber | awk '{gsub(/"/, ""); print $4}')
  		local AGENT_USERNAME=${serialNumber}@domain.com
        writeLog "Grabbing hostname from system: $AGENT_USERNAME"
		local AGENT_USER_HOME=$(dscl . -read "/users/${user}" NFSHomeDirectory | cut -d ' ' -f 2)
		writeLog "Home directory read from dscl ($AGENT_USER_HOME)"
		writeLog "Returning AGENT_USERNAME=$AGENT_USERNAME"
		writeLog "Returning AGENT_USER_HOME=$AGENT_USER_HOME"
        echo "AGENT_USERNAME=$AGENT_USERNAME"
        echo "AGENT_USER_HOME=$AGENT_USER_HOME"
   fi
}
function writeLog () {
	echo "$(date) - $@"  >> /Library/Application\ Support/CrashPlan/log/userDetect_Result.log
}
main "$@"
