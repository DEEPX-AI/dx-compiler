#!/bin/bash
SCRIPT_DIR=$(realpath "$(dirname "$0")")
COMPILER_PATH=$(realpath -s "${SCRIPT_DIR}/..")
DX_AS_PATH=$(realpath -s "${COMPILER_PATH}/..")
DOWNLOADER_PY="$COMPILER_PATH/scripts/downloader.py" # Assuming downloader.py is in compiler_path/scripts/

# load print_colored()
#   - usage: print_colored "message contents" "type"
#      - types: ERROR FAIL INFO WARNING DEBUG RED BLUE YELLOW GREEN
source "${COMPILER_PATH}/scripts/color_env.sh"
source "${COMPILER_PATH}/scripts/common_util.sh"

VERSION=""            # Required
MODULE_NAME=""        # Required for extraction/symlinking logic
DOWNLOAD_URL=""       # Required
ARCHIVE_MODE="n"      # default
USE_FORCE=0           # Internal flag for easier logic
ENABLE_DEBUG_LOGS=0   # New flag for debug logging

# --- Define OUTPUT_DIR and EXTRACT_ARGS based on ARCHIVE_MODE ---
OUTPUT_DIR=""
EXTRACT_ARGS=""

# Function to display help message
show_help() {
    print_colored "Usage: $(basename "$0") --module_name=<module name> --version=<version> --download_url=<url>" "YELLOW"
    print_colored "Example: $0 --module_name=dx_com --version=1.60.1 --download_url=https://developer.deepx.ai/?files=MjM2NA==" "YELLOW"
    print_colored "Options:" "GREEN"
    print_colored "  --module_name=<module name> : Specify module (dx_com)" "GREEN"
    print_colored "  --version=<version>         : Specify version (e.g., 1.60.1)" "GREEN"
    print_colored "  --download_url=<url>        : Specify the direct download URL for the module" "GREEN"
    print_colored "  [--archive_mode=<y|n>]      : Set archive mode (default: n)" "GREEN"
    print_colored "  [--force]                   : Force overwrite if the file already exists" "GREEN"
    print_colored "  [--verbose]                 : Enable verbose (debug) logging." "GREEN"
    print_colored "  [--help]                    : Show this help message" "GREEN"

    if [ "$1" == "error" ] && [[ -n "$2" ]]; then
        print_colored "ERROR: $2" "ERROR"
        exit 1
    fi
    exit 0
}

# Parse args
for i in "$@"; do
    case "$i" in
        --module_name=*)
            MODULE_NAME="${i#*=}"
            ;;
        --version=*)
            VERSION="${i#*=}"
            ;;
        --download_url=*)
            DOWNLOAD_URL="${i#*=}"
            ;;
        --archive_mode=*)
            ARCHIVE_MODE="${i#*=}"
            ;;
        --force)
            USE_FORCE=1
            ;;
        --verbose)
            ENABLE_DEBUG_LOGS=1
            ;;
        --help)
            show_help
            ;;
        *)
            show_help "error" "Invalid option '$i'"
            ;;
    esac
done

# Usage check
if [ -z "$VERSION" ]; then
    show_help "error" "--version is required."
fi

if [ -z "$MODULE_NAME" ]; then
    show_help "error" "--module_name is required."
fi

if [ -z "$DOWNLOAD_URL" ]; then
    show_help "error" "--download_url is required."
fi

# Set OUTPUT_DIR and EXTRACT_ARGS based on ARCHIVE_MODE here (as per original logic)
if [ "$ARCHIVE_MODE" = "y" ]; then
    OUTPUT_DIR="${DX_AS_PATH}/archives" # Final location for archive files
else
    OUTPUT_DIR="${COMPILER_PATH}/${MODULE_NAME}" # Final installation path for extracted module files
fi

# Ensure the determined OUTPUT_DIR exists (main installation target for both modes)
# For archive_mode, this is DX_AS_PATH/archives; for normal mode, it's COMPILER_PATH/${MODULE_NAME}
mkdir -p "$OUTPUT_DIR" || { print_colored "ERROR: Failed to create output directory '$OUTPUT_DIR'." "ERROR"; exit 1; }


# --- Define other Paths ---
TARGET_BASE_DIR="${DX_AS_PATH}/workspace/release"
# ARCHIVE_DOWNLOAD_DIR is where archives are stored within the workspace/release structure.
# This is independent of ARCHIVE_MODE for intermediate handling.
ARCHIVE_DOWNLOAD_DIR="${TARGET_BASE_DIR}/${MODULE_NAME}/download"
DOWNLOAD_TEMP_DIR="${COMPILER_PATH}/temp_downloads" # Temporary download directory for downloader.py
OLD_DOWNLOAD_DIR="${COMPILER_PATH}/download" # Refers to the original scripts/../download path


# --- Use DEEPX Portal Credentials from Environment Variables ---
# NO PROMPT HERE. Credentials MUST be provided via install.sh or env vars.
if [ -z "$DX_USERNAME" ] || [ -z "$DX_PASSWORD" ]; then
    print_colored "ERROR: DEEPX Portal credentials (DX_USERNAME, DX_PASSWORD) are not set in environment variables." "ERROR"
    print_colored "Please run install.sh directly or ensure these environment variables are exported." "ERROR"
    exit 1
fi

# --- Function to intelligently extract archives ---
# Checks for a top-level directory and uses appropriate --strip-components option.
extract_archive() {
    local archive_file="$1"
    local target_dir="$2"

    if [ ! -f "$archive_file" ]; then
        print_colored "ERROR: Archive file for extraction not found at '$archive_file'." "ERROR"
        return 1
    fi

    # Check the internal structure of the tar file to see if it has a top-level directory
    local first_entry
    first_entry=$(tar -tf "$archive_file" | head -n 1)

    # Normalize the first entry by removing leading ./ if present
    local normalized_entry="${first_entry#./}"
    
    # Extract based on the structure detected
    if [[ "$normalized_entry" == */* ]]; then
        if [[ "$first_entry" == ./* ]]; then
            print_colored "INFO: Detected top-level directory with ./ prefix. Using --strip-components=2 for extraction." "INFO"
            tar -xzf "$archive_file" --strip-components=2 -C "$target_dir"
        else
            print_colored "INFO: Detected top-level directory. Using --strip-components=1 for extraction." "INFO"
            tar -xzf "$archive_file" --strip-components=1 -C "$target_dir"
        fi
    else
        print_colored "INFO: No top-level directory detected in archive. Extracting as-is." "INFO"
        tar -xzf "$archive_file" -C "$target_dir"
    fi || { print_colored "ERROR: Failed to extract archive '$archive_file' to '$target_dir'." "ERROR"; return 1; }

    return 0
}

# --- generate_output (Move, (Optionally) Download, (Optionally) Extract, and handle final file placement) ---
# This function's return values:
# 1. Path to the final processed module (extracted directory or copied archive file)
# 2. Basename of the final processed module (directory name or archive filename)
generate_output() {
    print_colored "INFO: Generating output for '$MODULE_NAME' (Version: $VERSION)..." "INFO"

    local actual_downloaded_file_from_downloader="" # Path of the file actually downloaded by downloader.py (in temp dir)
    local archive_target_in_workspace="" # Path where the archive should permanently reside in workspace/release/MODULE_NAME/download/
    local final_module_output_path="" # Path where the module is extracted (normal mode) or archive is finally stored (archive mode)
    local final_module_basename="" # Basename of final_module_output_path


    # Function to set specific paths based on the actual downloaded filename's basename
    # (Sets path variables based on the filename determined by downloader.py)
    set_paths_from_downloaded_basename() {
         local source_basename="$1" # e.g., dx_com_M1A_v1.60.1.tar.gz
         local extracted_dir_name="" # Name of the folder created after extraction (e.g., dx_com_M1A_v1.60.1)

         # Determine the extracted directory name by removing .tar.gz or .tgz extensions
         if [[ "$source_basename" == *.tar.gz ]]; then # Matches both .tar and .gz
            extracted_dir_name="${source_basename%.tar.gz}" # Remove .tar.gz
         elif [[ "$source_basename" == *.tgz ]]; then # Matches both .tar and .gz
            extracted_dir_name="${source_basename%.tgz}" # Remove .tgz
         else # Fallback for other single extensions, or if no common archive extension
            extracted_dir_name="${source_basename%.*}" # Remove only the last extension
            # If it's a double extension like .tar.bz2, this will still leave .tar
         fi
 
         archive_target_in_workspace="${ARCHIVE_DOWNLOAD_DIR}/${source_basename}" # e.g., .../dx_com/download/dx_com_M1A_v1.60.1.tar.gz
 
         if [ "$ARCHIVE_MODE" = "y" ]; then
            # In archive mode, the final output path is directly in the archives directory (OUTPUT_DIR)
            final_module_output_path="${OUTPUT_DIR}/${source_basename}"
            final_module_basename="${source_basename}"
         else
            # In normal mode, the final output path is where the module will be extracted
            final_module_output_path="${TARGET_BASE_DIR}/${MODULE_NAME}/${extracted_dir_name}"
            final_module_basename="${extracted_dir_name}"
         fi
    }


    # --- Step 1: Check if file already exists in FINAL destination (SKIP logic) ---
    # This checks if we can skip downloading and processing altogether.
    local potential_filename_pattern="*${VERSION}*.tar.gz" # Pattern for expected filename
    local existing_archive_in_final_output_dir="" # Variable to hold path if found

    if [ "$ARCHIVE_MODE" = "y" ]; then
        # In ARCHIVE_MODE, the final destination is OUTPUT_DIR (DX_AS_PATH/archives)
        existing_archive_in_final_output_dir=$(find "$OUTPUT_DIR" -maxdepth 1 -name "$potential_filename_pattern" -print -quit 2>/dev/null)
        if [ -n "$existing_archive_in_final_output_dir" ] && [ "$USE_FORCE" -eq 0 ]; then
            print_colored "INFO: Archive for '$MODULE_NAME' (Version: $VERSION) already exists at '$existing_archive_in_final_output_dir'. Skipping download." "WARNING"
            actual_downloaded_file_from_downloader="$existing_archive_in_final_output_dir" # Use the existing file
            set_paths_from_downloaded_basename "$(basename "$actual_downloaded_file_from_downloader")"
            echo "$final_module_output_path" # Return values
            echo "$final_module_basename"
            return 0
        fi
    else
        # In Normal mode, we check for existence in ARCHIVE_DOWNLOAD_DIR first
        # and also if the extracted folder already exists
        local existing_archive_in_workspace_download=$(find "$ARCHIVE_DOWNLOAD_DIR" -maxdepth 1 -name "$potential_filename_pattern" -print -quit 2>/dev/null)

        # We need to know the *final extracted path* for skipping in normal mode.
        # Temporarily determine extracted name for skip check.
        local temp_extracted_dir_name=""
        local temp_output_target_path=""
        if [ -n "$existing_archive_in_workspace_download" ]; then
            # Get just the filename first
            local temp_basename=$(basename "$existing_archive_in_workspace_download")
            if [[ "$temp_basename" == *.tar.gz ]]; then
                temp_extracted_dir_name="${temp_basename%.tar.gz}"
            elif [[ "$temp_basename" == *.tgz ]]; then
                temp_extracted_dir_name="${temp_basename%.tgz}"
            else
                temp_extracted_dir_name="${temp_basename%.*}"
            fi

            temp_output_target_path="${TARGET_BASE_DIR}/${MODULE_NAME}/${temp_extracted_dir_name}"
        fi

        if [ -n "$existing_archive_in_workspace_download" ] && [ -d "$temp_output_target_path" ] && [ "$USE_FORCE" -eq 0 ]; then
            print_colored "Module '$MODULE_NAME' (Version: $VERSION) already extracted at '$temp_output_target_path'. Skipping download and extraction." "WARNING"
            actual_downloaded_file_from_downloader="$existing_archive_in_workspace_download" # Use the existing archive
            set_paths_from_downloaded_basename "$(basename "$actual_downloaded_file_from_downloader")"
            echo "$final_module_output_path" # Return values
            echo "$final_module_basename"
            return 0
        fi
    fi

    # --- Step 2: Download the file if not skipped ---
    if [ -z "$actual_downloaded_file_from_downloader" ] || [ "$USE_FORCE" -eq 1 ]; then
        # If --force, clean temporary download directory before downloading
        if [ "$USE_FORCE" -eq 1 ] && [ -d "$DOWNLOAD_TEMP_DIR" ]; then
            print_colored "INFO: --force option detected. Cleaning up temporary download directory: '$DOWNLOAD_TEMP_DIR'." "INFO"
            rm -rf "$DOWNLOAD_TEMP_DIR"/*
        fi
        
        mkdir -p "$DOWNLOAD_TEMP_DIR" || { print_colored "ERROR: Failed to create temporary download directory '$DOWNLOAD_TEMP_DIR'." "ERROR"; return 1; }

        print_colored "INFO: Attempting to download module '$MODULE_NAME' (Version: $VERSION) from '$DOWNLOAD_URL'..." "INFO"
        local download_cmd="python3 \"$DOWNLOADER_PY\" --username \"$DX_USERNAME\" --password \"$DX_PASSWORD\" --download-url \"$DOWNLOAD_URL\" --save-location \"$DOWNLOAD_TEMP_DIR\" --expected-version \"$VERSION\""
        print_colored "Executing download command: $download_cmd" "DEBUG"

        eval "$download_cmd 1>&2"
        local download_exit_code=$?

        if [ $download_exit_code -ne 0 ]; then
            print_colored "ERROR: Module download failed! Please check your credentials or download URL. See downloader.py output above." "ERROR"
            rm -rf "$DOWNLOAD_TEMP_DIR"
            return 1
        fi

        # downloader.py succeeded, find the file in temp directory
        for f in "$DOWNLOAD_TEMP_DIR"/*; do
            if [ -f "$f" ]; then
                actual_downloaded_file_from_downloader="$f"
                break
            fi
        done

        if [ -z "$actual_downloaded_file_from_downloader" ]; then
            print_colored "ERROR: Downloader created no file in '$DOWNLOAD_TEMP_DIR'. Downloader might have failed silently after reporting success." "ERROR"
            rm -rf "$DOWNLOAD_TEMP_DIR"
            return 1
        fi
        # Set paths based on the newly downloaded file's basename
        set_paths_from_downloaded_basename "$(basename "$actual_downloaded_file_from_downloader")"
    fi # End of download/skip block for current file

    print_colored "INFO: Processing archive file: '$(basename "$actual_downloaded_file_from_downloader")'." "INFO"


    # --- Step 3: Move downloaded file to its permanent archive location ---
    # This step moves the file from the temp download location to its final archive storage location.
    # It handles --force for overwriting the destination.
    
    local source_path_for_move="$actual_downloaded_file_from_downloader"
    local destination_path_for_move=""

    if [ "$ARCHIVE_MODE" = "y" ]; then
        # In ARCHIVE_MODE, the file's final location is directly in OUTPUT_DIR (DX_AS_PATH/archives)
        destination_path_for_move="$final_module_output_path"
    else
        # In normal mode, the file is moved to ARCHIVE_DOWNLOAD_DIR (workspace/release/MODULE_NAME/download)
        destination_path_for_move="$archive_target_in_workspace"
    fi

    # Check if file already exists at its final destination and --force is not set
    if [ -e "$destination_path_for_move" ] && [ "$USE_FORCE" -eq 0 ]; then
        print_colored "INFO: File already exists at its final archive location '$destination_path_for_move'. Skipping move from temp." "INFO"
        # If we downloaded to temp, and a file exists in target without force, remove the temp one.
        if [ "$(realpath "$source_path_for_move")" != "$(realpath "$destination_path_for_move")" ]; then
             rm -f "$source_path_for_move"
             print_colored "INFO: Removed temporary downloaded file: '$source_path_for_move'." "INFO"
        fi
    else
        # Create destination directory if it doesn't exist
        mkdir -p "$(dirname "$destination_path_for_move")" || { print_colored "ERROR: Failed to create destination directory '$(dirname "$destination_path_for_move")'." "ERROR"; return 1; }
        
        print_colored "INFO: Moving '$(basename "$source_path_for_move")' to its final archive location '$destination_path_for_move'." "INFO"
        mv -f "$source_path_for_move" "$destination_path_for_move" || { # Use -f for force overwrite
            print_colored "ERROR: Failed to move file to '$destination_path_for_move'." "ERROR"; rm -f "$source_path_for_move"; return 1;
        }
    fi
    # actual_downloaded_file_from_downloader now points to the file's new location
    actual_downloaded_file_from_downloader="$destination_path_for_move"


    # --- Step 4: Create symlink from OLD_DOWNLOAD_DIR (scripts/../download) to the archive's current location ---
    mkdir -p "$OLD_DOWNLOAD_DIR" || { print_colored "ERROR: Failed to create old download directory '$OLD_DOWNLOAD_DIR'." "ERROR"; return 1; }
    local archive_basename="$(basename "$actual_downloaded_file_from_downloader")" # Get actual archive filename with .tar.gz
    local old_download_symlink_path="${OLD_DOWNLOAD_DIR}/${archive_basename}" # Symlink using the actual archive filename

    if [ -L "$old_download_symlink_path" ] || [ -e "$old_download_symlink_path" ]; then
        if [ "$USE_FORCE" -eq 1 ]; then
            print_colored "--force detected. Removing existing '$old_download_symlink_path' for symlink." "WARNING"
            rm -rf "$old_download_symlink_path"
        else
            print_colored "Symlink/file already exists at '$old_download_symlink_path'. Skipping creation." "WARNING"
        fi
    fi
    
    if [ ! -e "$old_download_symlink_path" ]; then
        print_colored "Creating symlink '$old_download_symlink_path' -> '$actual_downloaded_file_from_downloader'." "INFO"
        ln -sfr "$actual_downloaded_file_from_downloader" "$old_download_symlink_path" || { # -sfr: symbolic, force, relative
            print_colored "Failed to create symlink at '$old_download_symlink_path'." "WARNING"
        }
    fi
    print_colored "Archive moved and symlink in old download dir established." "INFO"
    

    # --- Step 5: Extract the archive (only if not in archive_mode) ---
    if [ "$ARCHIVE_MODE" != "y" ]; then
        print_colored "Extracting '$(basename "$actual_downloaded_file_from_downloader")' to '$final_module_output_path'." "INFO"
        
        # If --force is used, remove existing extracted directory before extraction
        if [ "$USE_FORCE" -eq 1 ] && [ -d "$final_module_output_path" ]; then
            print_colored "--force option detected. Removing existing extracted directory: '$final_module_output_path'." "WARNING"
            rm -rf "$final_module_output_path"
        fi

        # Skip extraction if target already exists and not force
        if [ -d "$final_module_output_path" ] && [ "$USE_FORCE" -eq 0 ]; then
            print_colored "Extracted directory '$final_module_output_path' already exists. Skipping extraction." "WARNING"
        else
            mkdir -p "$final_module_output_path" || { print_colored "ERROR: Failed to create output directory for extraction '$final_module_output_path'." "ERROR"; return 1; }
            # Use the new function to intelligently extract the archive
            if [[ "$actual_downloaded_file_from_downloader" == *.tar.gz ]] || [[ "$actual_downloaded_file_from_downloader" == *.tgz ]]; then
                extract_archive "$actual_downloaded_file_from_downloader" "$final_module_output_path" || {
                    print_colored "ERROR: Failed to extract archive '$actual_downloaded_file_from_downloader' to '$final_module_output_path'." "ERROR"
                    return 1
                }
            elif [[ "$actual_downloaded_file_from_downloader" == *.AppImage ]]; then
                print_colored "INFO: file format is App Image: '$actual_downloaded_file_from_downloader'." "INFO"
                print_colored "INFO: add permission to execute" "INFO"
                sudo chmod +x "$actual_downloaded_file_from_downloader" || {
                    print_colored "ERROR: Failed to add permission to execute." "ERROR"
                    return 1
                }
                cp "$actual_downloaded_file_from_downloader" "$final_module_output_path" || {
                    print_colored "ERROR: Failed to move file to '$final_module_output_path'." "ERROR"
                    return 1
                }
            else
                print_colored "ERROR: Unsupported file format: '$actual_downloaded_file_from_downloader'." "ERROR"
                return 1
            fi
            print_colored "Extraction complete." "INFO"
        fi
    else # ARCHIVE_MODE is 'y'
        # In archive mode, no extraction takes place. The file is already in its final location.
        print_colored "Skipping archive extraction in archive mode. File directly saved to '$final_module_output_path'." "INFO"
        
        if [[ "$final_module_output_path" == *.AppImage ]]; then
            print_colored "INFO: file format is App Image: '$final_module_output_path'." "INFO"
            print_colored "INFO: add permission to execute" "INFO"
            sudo chmod +x "$final_module_output_path" || {
                print_colored "ERROR: Failed to add permission to execute." "ERROR"
                return 1
            }
        fi
    fi

    # Return paths for the final module symlink
    echo "$final_module_output_path" # Returns the path where the module is finally processed (extracted dir or archive file)
    echo "$final_module_basename"    # Returns the basename of that final path (extracted dir name or archive filename)
    return 0
}


# --- Final Module Symlink Creation Logic ---
create_module_symlink() {
    local target_for_symlink="$1" # final_module_output_path (extracted folder or archive file path)
    local basename_for_symlink="$2" # final_module_basename (extracted folder name or archive filename)

    # The final module symlink target (e.g., /home/user/git/dx-all-suite/dx-compiler/dx_com)
    # This is determined by the global OUTPUT_DIR variable, which depends on ARCHIVE_MODE.
    local final_module_symlink_target_dir="${OUTPUT_DIR}"

    if [ "$ARCHIVE_MODE" != "y" ]; then # Only create this symlink in normal (non-archive) mode
        print_colored "Creating final module symlink for '$MODULE_NAME'." "INFO"

        # If --force is used, remove existing symlink or directory
        if [ "$USE_FORCE" -eq 1 ] && ([ -L "$final_module_symlink_target_dir" ] || [ -d "$final_module_symlink_target_dir" ]); then
            print_colored "--force option detected. Removing existing module installation target: '$final_module_symlink_target_dir'." "INFO"
            rm -rf "$final_module_symlink_target_dir"
        fi

        # Ensure parent directory for symlink exists
        mkdir -p "$(dirname "$final_module_symlink_target_dir")" || { print_colored "ERROR: Failed to create parent directory for symlink '$final_module_symlink_target_dir'." "ERROR"; return 1; }

        # Remove any existing entry at the symlink target location to avoid ln creating symlink inside a directory
        if [ -L "$final_module_symlink_target_dir" ]; then
            print_colored "Removing existing symlink at '$final_module_symlink_target_dir'." "INFO"
            rm -f "$final_module_symlink_target_dir"
        elif [ -e "$final_module_symlink_target_dir" ]; then
            print_colored "Removing existing entry at '$final_module_symlink_target_dir' to create symlink." "WARNING"
            rm -rf "$final_module_symlink_target_dir"
        fi

        # Create symlink (e.g., COMPILER_PATH/MODULE_NAME -> extracted_module_path)
        ln -sfr "$target_for_symlink" "$final_module_symlink_target_dir" || {
            print_colored "Failed to create final symlink for '$MODULE_NAME' to '$target_for_symlink'." "ERROR"
            return 1
        }
        print_colored "Final symlink '$final_module_symlink_target_dir' -> '$(readlink -f "$target_for_symlink")' created successfully." "INFO"
    else # ARCHIVE_MODE is 'y'
        # In archive_mode, we only store the archive; no final module symlink is created under COMPILER_PATH/MODULE_NAME.
        print_colored "Skipping final module symlink creation in archive mode. Archive is at '$target_for_symlink'." "INFO"
    fi
    return 0
}


# --- Execution Flow ---

# Call generate_output to handle download, move to archive, and extract
GENERATED_OUTPUT_PATHS=$(generate_output)
if [ $? -ne 0 ]; then
    print_colored "GENERATED_OUTPUT_PATHS=$GENERATED_OUTPUT_PATHS" "DEBUG"
    print_colored "Module processing failed during generate_output step." "ERROR"
    rm -rf "$DOWNLOAD_TEMP_DIR" # Clean up temp directory
    exit 1
fi

# Parse the two paths returned by generate_output
FINAL_MODULE_PATH=$(echo "$GENERATED_OUTPUT_PATHS" | head -n 1) # Path to the final processed module (extracted dir or archive file)
FINAL_MODULE_BASENAME=$(echo "$GENERATED_OUTPUT_PATHS" | tail -n 1) # Basename of that final path (extracted dir name or archive filename)

# Create final module symlink
create_module_symlink "$FINAL_MODULE_PATH" "$FINAL_MODULE_BASENAME"
if [ $? -ne 0 ]; then
    print_colored "Final module symlink creation failed." "ERROR"
    exit 1
fi

# --- Cleanup temporary download directory ---
rm -rf "$DOWNLOAD_TEMP_DIR"
print_colored "Temporary download directory '$DOWNLOAD_TEMP_DIR' cleaned up." "INFO"

# --- Output archived file path for parent script (archive mode only) ---
if [ "$ARCHIVE_MODE" = "y" ]; then
    # Output to stdout for parent script to capture
    echo "ARCHIVED_FILE_PATH=${FINAL_MODULE_PATH}"
fi

print_colored "Module '$MODULE_NAME' (Version: $VERSION) installation completed successfully." "INFO"
exit 0
