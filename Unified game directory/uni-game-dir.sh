#!/usr/bin/env bash

# ==============================================================================
# Configuration
# ==============================================================================
# Add all directories you want to observe here
OBSERVED_PATHS=(
    "/path/to/source1"
    "/path/to/source2"
)

# Directory where symlinks will be created/managed
TARGET_DIR="/path/to/target"

# Add folder names (exact match) that you want the script to ignore
IGNORE_DIRS=(
    ".git"
    "lost+found"
    "temp_downloads"
)

# ==============================================================================
# Prerequisites & Setup
# ==============================================================================
if ! command -v inotifywait &> /dev/null; then
    echo "[ERROR] 'inotifywait' is not installed. Please install inotify-tools." >&2
    exit 1
fi

# Ensure target directory exists
mkdir -p "$TARGET_DIR"

# Normalize path strings (remove trailing slashes)
normalized_obs=()
for obs in "${OBSERVED_PATHS[@]}"; do
    normalized_obs+=("${obs%/}")
done

# ==============================================================================
# Function: Update or Create Symlink for a Folder Name
# ==============================================================================
update_symlink() {
    local folder_name="$1"

    # Check if this folder name is in our ignore list
    for ignore in "${IGNORE_DIRS[@]}"; do
        if [[ "$folder_name" == "$ignore" ]]; then
            return
        fi
    done

    local found_path=""

    # Search across all observed paths for this folder name (first match wins)
    for obs in "${normalized_obs[@]}"; do
        if [[ -d "$obs/$folder_name" ]]; then
            found_path="$obs/$folder_name"
            break
        fi
    done

    local target_link="$TARGET_DIR/$folder_name"

    if [[ -n "$found_path" ]]; then
        # Check if symlink already exists and points to the correct location
        if [[ -L "$target_link" ]]; then
            local current_target
            current_target=$(readlink "$target_link")
            if [[ "$current_target" == "$found_path" ]]; then
                return # Already correct, no action needed
            fi
            rm -f "$target_link"
        elif [[ -e "$target_link" ]]; then
            # Remove any blocking regular file/directory
            rm -rf "$target_link"
        fi

        # Create the new/updated symlink
        ln -s "$found_path" "$target_link"
        echo "[INFO] Symlink updated: $target_link -> $found_path"
    else
        # Folder no longer exists in any observed path; remove stale symlink
        if [[ -L "$target_link" ]]; then
            rm -f "$target_link"
            echo "[INFO] Removed stale symlink: $target_link"
        fi
    fi
}

# ==============================================================================
# 1. Initial Scan of Existing Directories
# ==============================================================================
echo "[INFO] Performing initial scan of observed paths..."
for obs in "${normalized_obs[@]}"; do
    if [[ -d "$obs" ]]; then
        for dir in "$obs"/*/; do
            # Skip if glob didn't match anything
            [[ -d "$dir" ]] || continue
            folder_name=$(basename "$dir")
            update_symlink "$folder_name"
        done
    else
        echo "[WARNING] Observed path does not exist: $obs"
    fi
done

# ==============================================================================
# 2. Live Monitoring via inotifywait
# ==============================================================================
echo "[INFO] Starting real-time monitoring on observed paths..."
# Note: Omitting -r (recursive) watches only top-level events, saving resources
inotifywait -m -e create,moved_to,moved_from,delete --format '%w|%f' "${normalized_obs[@]}" | while IFS='|' read -r event_path file_name; do
    event_path="${event_path%/}"
    
    # Ignore empty filenames
    [[ -z "$file_name" ]] && continue

    # Verify the event occurred inside one of our observed paths
    matched=false
    for obs in "${normalized_obs[@]}"; do
        if [[ "$event_path" == "$obs" ]]; then
            matched=true
            break
        fi
    done

    if [[ "$matched" == true ]]; then
        update_symlink "$file_name"
    fi
done