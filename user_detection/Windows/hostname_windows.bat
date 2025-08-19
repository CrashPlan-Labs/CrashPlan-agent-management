#!/bin/zsh

# Get the hostname of the machine
computername=$(hostname)

# Set the agent username and user home directory
AGENT_USERNAME="${computername}@domain.com"
AGENT_USER_HOME="/Users/"

# Check if the username is empty
if [ -z "$computername" ]; then
    exit 1
fi

# Print the values
echo "AGENT_USERNAME=$AGENT_USERNAME"
echo "AGENT_USER_HOME=$AGENT_USER_HOME"
