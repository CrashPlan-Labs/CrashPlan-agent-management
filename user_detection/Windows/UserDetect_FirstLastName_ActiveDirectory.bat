@echo off
setlocal

REM Gather user and home info.
for /f "TOKENS=1,2,*" %%a in ('tasklist /FI "IMAGENAME eq explorer.exe" /FO LIST /V') do if /i "%%a %%b"=="User Name:" set _currdomain_user=%%c
for /f "TOKENS=1,2 DELIMS=\" %%a in ("%_currdomain_user%") do set _currdomain=%%a & set currentuser=%%b
for /f "tokens=2*" %%a in ('net user "%currentuser%" /domain ^| find /i "Full Name"') do set DisplayName=%%b
set RealName=%DisplayName: =.%
set Domain=@domain.com

REM List of Excluded users that shouldn't be used for CrashPlan install.
FOR %%G IN ("system"
            "user1"
            "user2"
            "user3"
            "admin"
            "Administrator") DO (
            IF /I "%currentuser%"=="%%~G" GOTO NOMATCH
)

:MATCH
REM Echo Values for CrashPlan Installer
echo AGENT_USERNAME=%RealName%%DOMAIN%
echo AGENT_USER_HOME=%HOMEDRIVE%\Users\%currentuser%
GOTO :EOF

:NOMATCH
echo Excluded or null user detected (%currentuser%).  Will retry user detection in 60 minutes, or when reboot occurs.
GOTO :EOF