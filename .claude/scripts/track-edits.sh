#!/bin/bash

# track-edits.sh — Track edited files during Claude Code session
#
# This script maintains a list of files edited during the current session
# for later style checking with the Maysara Code Style enforcer.

EDITED_FILES_LIST="/tmp/claude_mcs_edited_files.txt"
SESSION_ID_FILE="/tmp/claude_mcs_session_id.txt"

# Function to initialize or get session ID
get_session_id() {
    if [ -f "$SESSION_ID_FILE" ]; then
        cat "$SESSION_ID_FILE"
    else
        # Generate new session ID based on timestamp
        SESSION_ID="session_$(date +%Y%m%d_%H%M%S)"
        echo "$SESSION_ID" > "$SESSION_ID_FILE"
        echo "$SESSION_ID"
    fi
}

# Function to add a file to the edited list
add_edited_file() {
    local file_path="$1"
    
    # Only track .zig files
    if [[ "$file_path" == *.zig ]]; then
        # Initialize session if needed
        get_session_id > /dev/null
        
        # Add to list if not already present
        if [ -f "$EDITED_FILES_LIST" ]; then
            if ! grep -Fxq "$file_path" "$EDITED_FILES_LIST"; then
                echo "$file_path" >> "$EDITED_FILES_LIST"
            fi
        else
            echo "$file_path" > "$EDITED_FILES_LIST"
        fi
        
        echo "Tracked: $file_path"
    fi
}

# Function to get all edited files
get_edited_files() {
    if [ -f "$EDITED_FILES_LIST" ]; then
        cat "$EDITED_FILES_LIST"
    else
        echo ""
    fi
}

# Function to clear the edited files list
clear_edited_files() {
    rm -f "$EDITED_FILES_LIST"
    rm -f "$SESSION_ID_FILE"
    echo "Cleared edited files list"
}

# Function to get count of edited files
count_edited_files() {
    if [ -f "$EDITED_FILES_LIST" ]; then
        wc -l < "$EDITED_FILES_LIST"
    else
        echo "0"
    fi
}

# Main script logic - parse JSON input from hooks
main() {
    local action="${1:-add}"
    
    case "$action" in
        add)
            # Read JSON from stdin and extract file path
            if [ -p /dev/stdin ]; then
                # Parse JSON input from hook
                FILE_PATH=$(jq -r '.tool_input.file_path // .tool_input.edits[0].file_path // ""' 2>/dev/null)
                if [ -n "$FILE_PATH" ]; then
                    add_edited_file "$FILE_PATH"
                fi
            elif [ -n "$2" ]; then
                # Direct file path provided as argument
                add_edited_file "$2"
            fi
            ;;
        list)
            get_edited_files
            ;;
        count)
            count_edited_files
            ;;
        clear)
            clear_edited_files
            ;;
        session)
            get_session_id
            ;;
        *)
            echo "Usage: $0 {add|list|count|clear|session} [file_path]"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"