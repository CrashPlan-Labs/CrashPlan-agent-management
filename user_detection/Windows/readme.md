###Overview

The scripts in this repo contain user detection methods commonly used by CrashPlan's Professional Services team
for detection on Windows platforms.  All scripts contain user blacklists to assist IT teams with ensuring that the 
CrashPlan installation is set up for the correct end user, and not the support staff setting up the Windows endpoint
for the first time.

### Win_Azure_ADSI_Combined_Userdetect.bat
  * The purpose of this script is to detect which user is running explorer.exe, and then determine the
  user's email from the directory. For Azure, we look at one of two registry keys. For on-prem domains, we perform
  an ADSI search.  This is the default script for CrashPlan's Professional Services team.
    - This script requires an active connection to a Windows domain

### UserDetect_Explorer_AppendDomain.bat
  * This script is used to detect which user is running explorer.exe, and then append the domain of the email 
  address to the end.  The home directory is discovered by adding the username to the Users directory
  path in Windows.

### UserDetect_Registry_AppendDomain.bat
  * This script is used to detect which user last logged in using the LastLoggedOnUser registry value in HKLM, 
  and then append the domain of the email address to the end.  The home directory is discovered by adding the username 
  to the Users directory path in Windows.

### UserDetect_FirstLastName_ActiveDirectory.bat
  * This script is used find the real name of an Active Directory user, bring both the first and last name together with
  a period, and then append the domain of the email address to the end.
    - This script requires an active connection to a domain

### UserDetect_FirstLastName_NoActiveDirectory.bat
  * This script is used find the real name of an Active Directory user, bring both the first and last name together with
  a period, and then append the domain of the email address to the end.
    - This script requires the Full Name field for a local account to be populated with a users first name and last name
    separated with a space.

### UserDetect_ReadFromFile_User.bat
  * This script reads a text file (in this script, the default location of the file is C:\Temp\CrashPlan_User.txt) for the user
  email address, and the home directory is discovered by adding the username to the Users directory path in Windows.