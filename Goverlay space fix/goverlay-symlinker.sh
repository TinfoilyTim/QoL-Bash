#!/usr/bin/env bash

WATCH_DIR="$HOME/.local/share/goverlay/gameconfig"

echo "Watching $WATCH_DIR for new folders..."

# Monitor directory for creation events
inotifywait -m -e create --format "%w%f" "$WATCH_DIR" | while read -r NEW_ITEM; do
    # Small delay to ensure folder is fully created
    sleep 0.1 

    if [[ -d "$NEW_ITEM" ]]; then
        BASENAME=$(basename "$NEW_ITEM")

        # Only process if there is a space in the name
        if [[ "$BASENAME" == *" "* ]]; then
            NEW_NAME="${BASENAME// /}"
            TARGET_PATH="$WATCH_DIR/$NEW_NAME"

            if [[ ! -e "$TARGET_PATH" ]]; then
                ln -s "$NEW_ITEM" "$TARGET_PATH"
                echo "Success: Linked '$NEW_NAME' -> '$BASENAME'"
            fi
        fi
    fi
done