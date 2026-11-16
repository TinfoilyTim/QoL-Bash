#!/usr/bin/env fish

set WATCH_DIR "$HOME/.local/share/goverlay/gameconfig"

echo "Watching $WATCH_DIR for new folders..."

# Monitor directory for creation events
inotifywait -m -e create --format "%w%f" "$WATCH_DIR" | while read -l NEW_ITEM
    # Small delay to ensure folder is fully created
    sleep 0.1 

    if test -d "$NEW_ITEM"
        set BASENAME (basename "$NEW_ITEM")

        # Only process if there is a space in the name
        if string match -q "* *" "$BASENAME"
            set NEW_NAME (string replace -a ' ' '' "$BASENAME")
            set TARGET_PATH "$WATCH_DIR/$NEW_NAME"

            if not test -e "$TARGET_PATH"
                ln -s "$NEW_ITEM" "$TARGET_PATH"
                echo "Success: Linked '$NEW_NAME' -> '$BASENAME'"
            end
        end
    end
end
