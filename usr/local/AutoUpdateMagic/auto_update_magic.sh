#!/bin/bash

if [[ -e /Applications/Utilities/cocoaDialog.app ]]; then
CD="/Applications/Utilities/cocoaDialog.app/Contents/MacOS/cocoaDialog"
else
echo "no cocoaDialog found"
exit 1
fi

Today=`date`
echo "Today value: $Today"
CurrentDate=${Today:8:2}

# Quick and dirty format of date
if [[ "$CurrentDate" = " 1" ]]; then
  CurrentDate="01"
elif [[ "$CurrentDate" = " 2" ]]; then
  CurrentDate="02"
elif [[ "$CurrentDate" = " 3" ]]; then
  CurrentDate="03"
elif [[ "$CurrentDate" = " 4" ]]; then
  CurrentDate="04"
elif [[ "$CurrentDate" = " 5" ]]; then
  CurrentDate="05"
elif [[ "$CurrentDate" = " 6" ]]; then
  CurrentDate="06"
elif [[ "$CurrentDate" = " 7" ]]; then
  CurrentDate="07"
elif [[ "$CurrentDate" = " 8" ]]; then
  CurrentDate="08"
elif [[ "$CurrentDate" = " 9" ]]; then
  CurrentDate="09"
fi

echo "CurrentDate value: $CurrentDate"

ScriptPath="/usr/local/AutoUpdateMagic"

if [[ -e "$ScriptPath"/apps.txt ]]; then
################################## SETTINGS ###################################

# Add a line here for each auto update custom trigger. This is almost always
# the same as the recipe's name. Trigger and recipe names may contain spaces.
#TRIGGERS=`cat "$ScriptPath"/apps.txt`

# For each recipe above, add a corresponding line here for each "blocking
# application" (apps/processes that must not be open if the app is to be
# updated automatically). You can add multiple comma-separated applications per
# line. Use `pgrep -ix _____` to test whether the blocking behaves as expected.
BLOCKING_APPS=(
    # "Safari$, Firefox" # blocking apps for Flash
    # "Firefox" # blocking apps for Firefox
    # "Google Chrome" # blocking apps for Chrome
    # "Safari$, Firefox" # blocking apps for Java 7
    # "Safari$, Firefox" # blocking apps for Java 8
)

# Preference list that will be used to track last auto update timestamp.
# Omit ".plist" extension.
PLIST="/Library/Application Support/JAMF/com.jamfsoftware.jamfnation"

# Set DEBUG_MODE to true if you wish to do a "dry run." This means the custom
# triggers that cause the apps to actually update will be logged, but NOT
# actually executed. Set to false prior to deployment.
DEBUG_MODE=false


###############################################################################
######################### DO NOT EDIT BELOW THIS LINE #########################
###############################################################################


######################## VALIDATION AND ERROR CHECKING ########################

APPNAME=$(basename "$0" | sed "s/\.sh$//")

########### Let's make sure we have the right numbers of settings above.
#####if [[ ${#TRIGGERS[@]} != ${#BLOCKING_APPS[@]} ]]; then
#####    echo "[ERROR] Please carefully check the settings in the $APPNAME script. The number of parameters don't match." >&2
#####    exit 1001
#####fi

# Let's verify that DEBUG_MODE is set to true or false.
if [[ $DEBUG_MODE != true && $DEBUG_MODE != false ]]; then
    echo "[ERROR] DEBUG_MODE should be set to either true or false." >&2
    exit 1002
fi

# Locate the jamf binary.
PATH="/usr/sbin:/usr/local/bin:$PATH"
jamf=$(which jamf)
if [[ -z $jamf ]]; then
    echo "[ERROR] The jamf binary could not be found." >&2
    exit 1003
fi

# Verify that the JSS is available before starting.
$jamf checkJSSConnection -retry 0
if [[ $? -ne 0 ]]; then
    echo "[ERROR] Unable to communicate with the JSS right now." >&2
    exit 1004
fi


################################ MAIN PROCESS #################################

# Count how many recipes we need to process.
RECIPE_COUNT=`cat "$ScriptPath"/apps.txt | wc -l`
#${#TRIGGERS[@]}

# Save the default internal field separator.
OLDIFS=$IFS

# Inform user that we are looking for updates
$CD bubble --title "Looking for app updates" --text "Looking for app updates and installing if available" --icon info --alpha 0.8

# Read TRIGGERS line by line and process them in order
while read -r App; do

# Begin iterating through recipes.
#for (( i = 0; i < RECIPE_COUNT; i++ )); do

    echo " " # for some visual separation between apps in the log

    # Iterate through each recipe's corresponding blocking apps.
    echo "Checking for apps that would block the $App update..."
    IFS=","
    UPDATE_BLOCKED=false

    for BLOCKEDAPP in ${BLOCKING_APPS[$i]}; do

        # Strip leading spaces from app name.
        APP_CLEAN="$(echo "$BLOCKEDAPP" | sed 's/^ *//')"

        # Check whether the app is running.
        if pgrep -ix "$APP_CLEAN" &> /dev/null; then
            echo "    $APP_CLEAN is running. Skipping auto update."
            UPDATE_BLOCKED=true
            break
        else
            echo "    $APP_CLEAN is not running."
        fi

    done

    # Only run the auto-update policy if no blocking apps are running.
    if [[ $UPDATE_BLOCKED == false ]]; then
        if [[ $DEBUG_MODE == false ]]; then
            # echo "No apps are blocking the $App update. Calling policy trigger autoupdate-$App."
            $jamf policy -event "autoupdate-$App"
            echo "Getting entry from log file"
              AppUpdate=`cat /var/log/jamf.log | grep "Successfully installed $App" | grep "$CurrentDate"`
                echo "$AppUpdate"
              echo "Getting date from log file"
                AppUpdateDay=${AppUpdate:8:2}
                  echo "$AppUpdateDay"

                echo "Compare log file and todays date, if match, show message"
                if [[ $AppUpdateDay = $CurrentDate ]]; then
                  echo "Dates matches"
                  $CD bubble --title "$App updated" --text "Please restart the app to apply the latest version" --icon info --alpha 0.8
                fi
        else
            echo "[DEBUG] No apps are blocking the $App update. This is the point where we would run:"
            echo "    $jamf policy -event \"autoupdate-$App\""
        fi
    fi

#done # End iterating through recipes.
done <"$ScriptPath/apps.txt"

# Reset back to default internal field separator.
IFS=$OLDIFS

# Record the timestamp of the last auto update check.
if [[ $DEBUG_MODE == false ]]; then
    /usr/bin/defaults write "$PLIST" LastAutoUpdate -date "$(date)"
fi

else
  echo "No Apps-file found, closing script"
fi

exit 0
