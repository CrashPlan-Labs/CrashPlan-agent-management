function main () {
   	writeLog "Starting user detection..."
    local user=$(last | egrep 'console.*still' | egrep -v 'root|admin|reboot|shutdown|local|_mbsetupuser' | awk '{print $1}' | sort -u | head -n1)
	writeLog "User name found ($user)"
	if [[ "$user" =~ ^(admin1|admin2|admin3)$ ]] || [[ -z "$user" ]]; then
        writeLog "Excluded or null username detected ($user). Will retry user detection in 60 minutes, or when reboot occurs."
        exit
	else
        local AGENT_USERNAME="${user}@domain.com"
        writeLog "Username assembled by appending domain ($AGENT_USERNAME)"
		local AGENT_USER_HOME=$(dscl . -read "/users/${user}" NFSHomeDirectory | cut -d ' ' -f 2)
		writeLog "Home directory read from dscl ($AGENT_USER_HOME)"
		writeLog "Returning AGENT_USERNAME=$AGENT_USERNAME"
		writeLog "Returning AGENT_USER_HOME=$AGENT_USER_HOME"
        echo "AGENT_USERNAME=$AGENT_USERNAME"
        echo "AGENT_USER_HOME=$AGENT_USER_HOME"
    fi
}
function writeLog () {
	echo "$(date) - $@" >> /Library/Logs/CrashPlan/userDetect_Result.log
}
main "$@"
