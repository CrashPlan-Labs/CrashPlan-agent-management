#!/bin/sh
#fill in these three vairables into the script. Create an API client with at minimum the computer Read permission
CP_Console="EditFromTemplate_CrashPlan_Server_Name"
clientID="EditFromTemplate_CrashPlan_clientId"
secret="EditFromTemplate_CrashPlan_client_secret"

if [ "$CP_Console" == "" ] || [ "$clientID" == "" ] || [ "$secret" == "" ];then
    echo "<result>Please ensure all variables are set in the extension attribute script.</result>"
else
    token=`/usr/bin/curl -X POST -u "$clientID:$secret" -H "Accept: application/json" "$CP_Console/api/v3/oauth/token?grant_type=client_credentials" | /usr/bin/sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p'`
    if [ "$token" == "" ];then
        echo "<result>Error with API client Authentication</result>"
    elif [ -f /Library/Application\ Support/CrashPlan/.identity ];then
        guid=$(/usr/bin/awk -F '=' '/guid/{print $2}' /Library/Application\ Support/CrashPlan/.identity)
        result=$(/usr/bin/curl  -X GET --header 'Authorization: Bearer '$token -H "Accept: application/json" "$CP_Console/api/computer/$guid?idType=guid")
        AlertStates=`echo $result | /usr/bin/sed -n 's/.*"alertStates":\["\([^"]*\)".*/\1/p'`
        if [ "$AlertStates" == "" ] ;then
            echo "<result>`echo $result | /usr/bin/sed -n 's/.*"description":"\([^"]*\)".*/\1/p'`</result>"
        else
            echo "<result>$AlertStates</result>"
        fi
    else
        echo "<result>Not installed</result>"
    fi
fi