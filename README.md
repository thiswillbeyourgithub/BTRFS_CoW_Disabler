# Btrfs COW Disabler

This script disables Copy-on-Write (COW) for files or directories on a Btrfs filesystem by copying the data to a new file with the `+C` attribute set.

## ⚠️ **Important Note**
This script **has not been thoroughly tested** and may contain bugs. Use it at your own risk. Always back up your data before running it.

**Personal Experience:** I used this script for a short period and it seemed to work fine, but I ultimately encountered issues with Btrfs itself and stopped using it in the long run. Your mileage may vary.

## Usage
```bash
./btrfs_cow_disabler.zsh <source_file_or_dir> <temporary_file>
```

- `<source_file_or_dir>`: The file or directory to disable COW for.
- `<temporary_file>`: A temporary file or location used during the process.

## How It Works
1. Creates a temporary file with the `+C` attribute (disables COW).
2. Copies the original file's data to the temporary file.
3. Verifies the checksum to ensure data integrity.
4. Atomically moves the temporary file back to the original location.

## Requirements
- `zsh` shell
