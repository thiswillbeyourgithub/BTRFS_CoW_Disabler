#!/bin/zsh

# Exit on any error
set -e

# Logging function
log() {
    local message=$1
    echo "$message"
    logger -t btrfs_cow_disabler "$message"
}

# New function to check for C attribute
check_cow_attribute() {
    local file=$1
    if lsattr "$file" 2>/dev/null | grep -q "[[:space:]]C[[:space:]]"; then
        return 1  # Has C attribute
    fi
    return 0  # Doesn't have C attribute
}

# Function to disable COW for a single file
disable_cow_file() {
    local file=$1
    local tmp_file="${file}.tmp_cow_disable"
    
    if [ -e "$tmp_file" ]; then
        log "Error: Temporary file $tmp_file already exists"
        return 1
    fi

    if check_cow_attribute "$file"; then
        log "File $file already has COW disabled (C attribute present)"
        return 0
    fi
    
    log "Converting $file..."
    
    log "Computing hash for $file..."
    # Get original hash
    local original_hash=$(sha256sum "$file" | cut -d' ' -f1)
    
    # Create temp file with COW disabled
    touch "$tmp_file"
    chattr +C "$tmp_file"
    
    # Copy contents
    if ! dd if="$file" of="$tmp_file" bs=1M status=progress; then
        log "Error: Failed to copy $file"
        rm -f "$tmp_file"
        return 1
    fi
    
    # Verify checksum
    log "Computing check hash for $file..."
    local new_hash=$(sha256sum "$tmp_file" | cut -d' ' -f1)
    log "Verifying checksum - Original: $original_hash, New: $new_hash"
    if [[ "$original_hash" != "$new_hash" ]]; then
        log "Error: Checksum mismatch!"
        rm -f "$tmp_file"
        return 1
    fi
    
    # Atomic move
    if ! mv -f "$tmp_file" "$file"; then
        log "Error: Failed to atomically move file"
        rm -f "$tmp_file"
        return 1
    fi
    
    log "Conversion complete for $file"
    return 0
}

# Check if source exists
if [ $# -ne 1 ]; then
    log "Usage: $0 <file_or_directory>"
    log "Disables COW (Copy-on-Write) for a file or directory on Btrfs filesystem"
    exit 1
fi

FILE=$1

if [ ! -e "$FILE" ]; then
    log "Error: $FILE doesn't exist"
    exit 1
fi

# Handle directories
if [ -d "$FILE" ]; then
    log "Processing directory $FILE..."
    
    # Check if directory already has COW disabled
    if check_cow_attribute "$FILE"; then
        log "Disabling COW for directory $FILE"
        if ! chattr +C "$FILE"; then
            log "Error: Failed to disable COW on directory $FILE"
            exit 1
        fi
        log "Successfully disabled COW for directory $FILE"
    else
        log "Directory $FILE already has COW disabled"
    fi
    
    log "Processing files recursively..."
    while IFS= read -r f; do
        if [ -f "$f" ]; then
            if ! disable_cow_file "$f"; then
                exit 1
            fi
        fi
    done < <(find "$FILE" -type f)
    log "Directory processing complete."
    exit 0
fi

# Handle single file
if ! disable_cow_file "$FILE"; then
    exit 1
else
    exit 0
fi
