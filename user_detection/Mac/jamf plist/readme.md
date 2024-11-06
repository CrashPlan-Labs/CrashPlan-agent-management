To use, first put macuserdetection-plist into the CrashPlan console in the deployment policy.

Then, in JAMF, create a new Configuration Profile or edit and existing one (for example if you've already imported CrashPlan's sample access mobileconfig).

Then, go to Custom Settings (or Application & Custom Settings, depending on JAMF version), and upload the com.crashplan.email.plist.

Next, scope the PPPC to the users (see note), and deploy as normal.

See https://www.jamf.com/blog/help-users-activate-microsoft-office-365-and-configure-outlook-in-one-click/ for JAMF's documentation on this approach.

Earlier versions of JAMF put the plist in `~/Library/Preferences/`, but later versions put it in `/Library/Managed Preferences/`. You may need to update the script depending on their JAMF version/confinguration.

(note: It may be that scoping to machines doesn't work and you need to scope to users. This may depend on the environment as well, so be careful)

This will probably also work with InTune as well using the info here:
https://docs.microsoft.com/en-us/mem/intune/configuration/custom-settings-macos
https://docs.microsoft.com/en-us/mem/intune/apps/app-configuration-policies-use-ios#tokens-used-in-the-property-list