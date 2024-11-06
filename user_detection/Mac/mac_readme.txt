###Overview

The scripts in this repo contain user detection methods commonly used by CrashPlan's Professional Services team
for detection on Mac platforms.  A Majority of the scripts contain error checking logic to assist IT teams with ensuring that the 
CrashPlan installation is set up for the correct end user, and not the support staff setting up the endpoint
for the first time.

### Email_prompt_for_email.sh
  * The purpose of this script is as an alternative when no other scripts work and the end user has to manually input their email address. The script will create a pop-up 
  at install time prompting the user to input their email address, which will then auto register the user in CrashPlan and start the backup. 

### UserDetect_scutil_user_plus_domain.sh
  * This script utilises scutil to detect the logged in user. The clients email domain needs to be appended to the resulting username to get a valid username for cloud deployments.
  * Known admin/helpdesk user accounts should be added to the blacklist to prevent the installer from creating a user for those admin accounts. (admin1/2/3)
  * The clients domain needs to replace the currently inserted dummy domain

### UserDetect_and_modify_firstname_dot_lastname.sh
  * This script will detect the locally logged in users first and last name and then edit the string to create a username of firstname.lastname. 
  * Known admin/helpdesk user accounts should be added to the blacklist to prevent the installer from creating a user for those admin accounts. (admin1/2/3)
  * The clients domain needs to replace the currently inserted dummy domain

### UserDetect_and_modify_firstinitial_dot_lastname.sh
  * This script will detect the locally logged in users first and last name and then edit the string to create a username of firstinitial.lastname. 
  * Known admin/helpdesk user accounts should be added to the blacklist to prevent the installer from creating a user for those admin accounts. (admin1/2/3)
  * The clients domain needs to replace the currently inserted dummy domain

### UserDetect_from_text.sh
  *  This script will read the username from a text file, by default located at /tmp/CrashPlantest.txt (can be modified)
  To be used when no other logical way of finding the username can be determined and no user interaction is desired.
  * The clients domain needs to replace the currently inserted dummy domain
  * Known admin/helpdesk user accounts should be added to the blacklist to prevent the installer from creating a user for those admin accounts. (admin1/2/3)

### UserDetect_last_plus_domain.sh
  * This script uses and alternate method to finding the logged in user than the python method most commonly used. The script will
  check the last known logged in users and narrow down the list to the currently logged in user. 
  * The clients domain needs to replace the currently inserted dummy domain
  * Known admin/helpdesk user accounts should be added to the blacklist to prevent the installer from creating a user for those admin accounts. (admin1/2/3)

### UserDetect_using_DSCL.sh
  * This script grabs the users email address from the domain records stored on the machine. 
  * The mac needs to be domain bound for this to work
  * Known admin/helpdesk user accounts should be added to the blacklist to prevent the installer from creating a user for those admin accounts. (admin1/2/3)
