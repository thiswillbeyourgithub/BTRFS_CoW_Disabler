#!/bin/bash

# Add usage message
if [ $# -ne 2 ]; then
    echo "Usage: $0 <source_file_or_dir> <temporary_file>"
    echo "Disables COW (Copy-on-Write) for a file or directory on Btrfs filesystem"
    exit 1
fi

FILE=$1
TMP=$2

# Check if source exists
if [ ! -e "$FILE" ]; then
    echo "Error: $FILE doesn't exist" >&2
    exit 1
fi

# Check if temporary location is writable
if ! touch "$TMP" 2>/dev/null; then
    echo "Error: Cannot write to temporary location $TMP" >&2
    exit 1
fi
rm -f "$TMP"

# Handle directories
if [ -d "$FILE" ]; then
    echo "Processing directory $FILE..."
    for f in "$FILE"/*; do
        if [ -f "$f" ]; then
            echo "Converting file $f..."
            TMP_FILE="${TMP}_$(basename "$f")"
            touch "$TMP_FILE"
            chattr +C "$TMP_FILE"
            if ! dd if="$f" of="$TMP_FILE" bs=1M status=progress; then
                echo "Error: Failed to copy $f" >&2
                rm -f "$TMP_FILE"
                exit 1
            fi
            rm -f "$f"
            mv "$TMP_FILE" "$f"
        fi
    done
    echo "Directory processing complete."
    exit 0
fi

# Handle single file
echo "Converting $FILE (via $TMP)..."
touch "$TMP"
chattr +C "$TMP"
if ! dd if="$FILE" of="$TMP" bs=1M status=progress; then
    echo "Error: Failed to copy $FILE" >&2
    rm -f "$TMP"
    exit 1
fi
rm -f "$FILE"
mv "$TMP" "$FILE"
echo "Conversion complete."
exit 0
