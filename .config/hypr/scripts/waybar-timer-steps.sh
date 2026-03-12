#!/bin/bash

TIMER_FILE="/var/tmp/waybar_timer"

case "$1" in
    up)
        # Check whether the timer file exists and is NOT "READY"
        if [ -f "$TIMER_FILE" ] && [ "$(cat "$TIMER_FILE")" != "READY" ]; then
            # Read current timer value from file
            CURRENT_TIMER=$(cat "$TIMER_FILE")
        else
            # If the file does not exist or is "READY", use current timestamp
            CURRENT_TIMER=$(date +%s)
        fi

        # If timer is not "READY", add 5 minutes to current value
        if [ "$CURRENT_TIMER" != "READY" ]; then
            NEW_TIMER=$((CURRENT_TIMER + 5 * 60))
            # Write new timer value to file
            echo $NEW_TIMER > "$TIMER_FILE"
        fi

        # Output updated timer value in MM:SS format
        echo $(date -d @$CURRENT_TIMER +%M:%S)
        ;;

    down)
        # Check whether the timer file exists
        if [ -f "$TIMER_FILE" ] && [ "$(cat "$TIMER_FILE")" != "READY" ]; then
            # Read current timer value from file
            CURRENT_TIMER=$(cat "$TIMER_FILE")
        else
            # If the file does not exist or is "READY", use current timestamp
            CURRENT_TIMER=$(date +%s)
        fi

        # Subtract 5 minutes from current timer value
        NEW_TIMER=$((CURRENT_TIMER - 5 * 60))

        # Check whether new timer value is lower than current timer value
        if [ "$NEW_TIMER" -lt "$CURRENT_TIMER" ]; then
            # Write new timer value to file
            echo "$NEW_TIMER" > "$TIMER_FILE"
            # Output updated timer value in MM:SS format
            echo $(date -d @"$NEW_TIMER" +%M:%S)
        else
            # If not lower, write "READY" to timer file
            echo "READY" > "$TIMER_FILE"
        fi
        ;;

    *)
        echo "Invalid option selected. Please choose up or down."
        ;;
esac
