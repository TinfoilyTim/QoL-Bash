#!/usr/bin/env fish

# ==============================================================================
# Configuration
# ==============================================================================
# Add all directories you want to observe here
set OBSERVED_PATHS \
    "/path/to/source1" \
    "/path/to/source2"

# Directory where symlinks will be created/managed
set TARGET_DIR "/path/to/target"

# Add folder names (exact match) that you want the script to ignore
set IGNORE_DIRS \
    ".git" \
    "lost+found" \
    "temp_downloads"

# ==============================================================================
# Prerequisites & Setup
# ==============================================================================
if not type -q inotifywait
    echo "[ERROR] 'inotifywait' is not installed. Please install inotify-tools."
    exit 1
end

# Ensure target directory exists
mkdir -p "$TARGET_DIR"

# Normalize path strings (remove trailing slashes)
set normalized_obs
for obs in $OBSERVED_PATHS
    set -a normalized_obs (string replace -r '/$' '' -- "$obs")
end

# ==============================================================================
# Function: Update or Create Symlink for a Folder Name
# ==============================================================================
function update_symlink
    set folder_name $argv[1]

    # Check if this folder name is in our ignore list
    if contains -- "$folder_name" $IGNORE_DIRS
        return
    end

    set found_path ""

    # Search across all observed paths for this folder name (first match wins)
    for obs in $normalized_obs
        if test -d "$obs/$folder_name"
            set found_path "$obs/$folder_name"
            break
        end
    end

    set target_link "$TARGET_DIR/$folder_name"

    if test -n "$found_path"
        # Check if symlink already exists and points to the correct location
        if test -L "$target_link"
            set current_target (readlink "$target_link")
            if test "$current_target" = "$found_path"
                return # Already correct, no action needed
            end
            rm -f "$target_link"
        else if test -e "$target_link"
            # Remove any blocking regular file/directory
            rm -rf "$target_link"
        end

        # Create the new/updated symlink
        ln -s "$found_path" "$target_link"
        echo "[INFO] Symlink updated: $target_link -> $found_path"
    else
        # Folder no longer exists in any observed path; remove stale symlink
        if test -L "$target_link"
            rm -f "$target_link"
            echo "[INFO] Removed stale symlink: $target_link"
        end
    end
end

# ==============================================================================
# 1. Initial Scan of Existing Directories
# ==============================================================================
echo "[INFO] Performing initial scan of observed paths..."
for obs in $normalized_obs
    if test -d "$obs"
        for dir in "$obs"/*/
            # Skip if glob didn't match anything
            test -d "$dir"; or continue
            set folder_name (basename "$dir")
            update_symlink "$folder_name"
        end
    else
        echo "[WARNING] Observed path does not exist: $obs"
    end
end

# ==============================================================================
# 2. Live Monitoring via inotifywait
# ==============================================================================
echo "[INFO] Starting real-time monitoring on observed paths..."
# Note: Omitting -r (recursive) watches only top-level events, saving resources
inotifywait -m -e create,moved_to,moved_from,delete --format '%w|%f' $normalized_obs | while read -l line
    # Split output on the pipe delimiter (handles spaces in folder names safely)
    set parts (string split -m 1 '|' -- "$line")
    set event_path (string replace -r '/$' '' -- "$parts[1]")
    set file_name "$parts[2]"

    # Ignore empty filenames
    test -z "$file_name"; and continue

    # Verify the event occurred inside one of our observed paths
    if contains -- "$event_path" $normalized_obs
        update_symlink "$file_name"
    end
end