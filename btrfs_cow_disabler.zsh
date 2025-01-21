#!/bin/zsh

# Exit on any error
set -e

# Logging function
log() {
    local message=$1
    echo "$message"
    logger -t btrfs_cow_disabler "$message"
}

# Add usage message
if [ $# -ne 2 ]; then
    log "Usage: $0 <source_file_or_dir> <temporary_file>"
    log "Disables COW (Copy-on-Write) for a file or directory on Btrfs filesystem"
    exit 1
fi

FILE=$1
TMP=$2

# Check if source exists
if [ ! -e "$FILE" ]; then
    log "Error: $FILE doesn't exist"
    exit 1
fi

# Check if temporary location is writable
if ! touch "$TMP" 2>/dev/null; then
    log "Error: Cannot write to temporary location $TMP"
    exit 1
fi
rm -f "$TMP"

# Handle directories
if [ -d "$FILE" ]; then
    log "Processing directory $FILE..."
    for f in "$FILE"/*; do
        if [ -f "$f" ]; then
            log "Converting file $f..."
            TMP_FILE="${TMP}_$(basename "$f")"
            original_hash=$(get_sha256 "$f")
            touch "$TMP_FILE"
            chattr +C "$TMP_FILE"
            
            if ! dd if="$f" of="$TMP_FILE" bs=1M status=progress; then
                log "Error: Failed to copy $f"
                rm -f "$TMP_FILE"
                exit 1
            fi
            
            new_hash=$(get_sha256 "$TMP_FILE")
            if [[ "$original_hash" != "$new_hash" ]]; then
                log "Error: Checksum mismatch for $f! Original: $original_hash, New: $new_hash"
                rm -f "$TMP_FILE"
                exit 1
            fi
            
            if ! mv -f "$TMP_FILE" "$f"; then
                log "Error: Failed to atomically move file $f"
                rm -f "$TMP_FILE"
                exit 1
            fi
        fi
    done
    log "Directory processing complete."
    exit 0
fi

# Calculate SHA256 checksum
get_sha256() {
    sha256sum "$1" | cut -d' ' -f1
}

# Handle single file
log "Converting $FILE (via $TMP)..."
original_hash=$(get_sha256 "$FILE")
touch "$TMP"
chattr +C "$TMP"

if ! dd if="$FILE" of="$TMP" bs=1M status=progress; then
    log "Error: Failed to copy $FILE"
    rm -f "$TMP"
    exit 1
fi

# Verify checksum
new_hash=$(get_sha256 "$TMP")
if [[ "$original_hash" != "$new_hash" ]]; then
    log "Error: Checksum mismatch! Original: $original_hash, New: $new_hash"
    rm -f "$TMP"
    exit 1
fi

# Atomic move
if ! mv -f "$TMP" "$FILE"; then
    log "Error: Failed to atomically move file"
    rm -f "$TMP"
    exit 1
fi

log "Conversion complete."
exit 0
