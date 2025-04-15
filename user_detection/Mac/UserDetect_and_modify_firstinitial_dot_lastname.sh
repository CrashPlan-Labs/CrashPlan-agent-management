function main() {
	writeLog "Starting user detection..."
    local user=$(echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }')
	writeLog "User name found ($user)"
	if [[ "$user" =~ ^(admin1|admin2|admin3)$ ]] || [[ -z "$user" ]]; then
        writeLog "Excluded or null username detected ($user). Will retry user detection in 60 minutes, or when reboot occurs."
        exit
	else
		realname="$(dscl . -read /Users/$user RealName | cut -d: -f2)"
		if [[ ($realname =~ ',') ]]; then
			writeLog "Real name contains a comma, assuming last, first format."
			realname="$(echo $realname | sed -e 's/[[:space:]]*//g' |  grep -v "^$" | tr '[:upper:]' '[:lower:]' | awk -F , '{print substr($2,1,1) "." $1}')"
		else
			realname="$(echo $realname | sed -e 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^\(.\)[^ ]* /\1./' | grep -v "^$" | tr '[:upper:]' '[:lower:]')"
		fi
        local AGENT_USERNAME="$realname@domain.com"
        writeLog "Email assembled from real name: $AGENT_USERNAME"
		local AGENT_USER_HOME=$(dscl . -read "/users/${user}" NFSHomeDirectory | cut -d ' ' -f 2)
		writeLog "Home directory read from dscl ($AGENT_USER_HOME)"
		writeLog "Returning AGENT_USERNAME=$AGENT_USERNAME"
		writeLog "Returning AGENT_USER_HOME=$AGENT_USER_HOME"
        echo "AGENT_USERNAME=$AGENT_USERNAME"
        echo "AGENT_USER_HOME=$AGENT_USER_HOME"
    fi
}
function writeLog () {
	echo "$(date) - $@" >> /Library/Application\ Support/CrashPlan/log/userDetect_Result.log
}
main "$@"
