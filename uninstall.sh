#!/bin/bash
SCRIPT_DIR=$(realpath "$(dirname "$0")")
DOWNLOAD_DIR="$SCRIPT_DIR/download"

pushd "$SCRIPT_DIR"

# Function to delete symlinks and their target files
delete_symlinks() {
    local dir="$1"
    for symlink in "$dir"/*; do
        if [ -L "$symlink" ]; then  # Check if the file is a symbolic link
            real_file=$(readlink -f "$symlink")  # Get the actual file path the symlink points to

            # If the original file exists, delete it
            if [ -e "$real_file" ]; then
                echo "Deleting original file: $real_file"
                rm -rf "$real_file"
                if [ $? -ne 0 ]; then
                    echo "Uninstalling dx-compiler failed!"
                    exit 1
                fi

            fi

            # Delete the symbolic link
            echo "Deleting symlink: $symlink"
            rm -rf "$symlink"
            if [ $? -ne 0 ]; then
                echo "Uninstalling dx-compiler failed!"
                exit 1
            fi
        fi
    done
}

echo "Uninstalling dx-compiler ..."

# Remove symlinks from DOWNLOAD_DIR and SCRIPT_DIR
delete_symlinks "$DOWNLOAD_DIR"
delete_symlinks "$SCRIPT_DIR"

# Remove the download directory
rm -rf "$DOWNLOAD_DIR"
if [ $? -ne 0 ]; then
    echo "Uninstalling dx-compiler failed!"
    exit 1
fi

echo "Uninstalling dx-compiler done"

popd
exit 0
