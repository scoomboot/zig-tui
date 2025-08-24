#!/bin/bash

# session-style-check.sh — Automatic MCS compliance check at session end
#
# This script is triggered by the Stop hook to check all files
# edited during the Claude Code session for MCS compliance.

TRACK_SCRIPT="/home/fisty/code/zig-tui/.claude/scripts/track-edits.sh"
MCS_REPORT="/tmp/claude_mcs_session_report.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}         MCS Session Compliance Check Starting...          ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Get session ID
SESSION_ID=$($TRACK_SCRIPT session)
echo -e "${YELLOW}Session ID:${NC} $SESSION_ID"

# Get count of edited files
FILE_COUNT=$($TRACK_SCRIPT count)

if [ "$FILE_COUNT" -eq "0" ]; then
    echo -e "${GREEN}✓ No .zig files were edited in this session.${NC}"
    echo -e "${GREEN}  No style check needed.${NC}"
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    exit 0
fi

echo -e "${YELLOW}Files edited:${NC} $FILE_COUNT"
echo ""

# Get list of edited files
EDITED_FILES=$($TRACK_SCRIPT list)

echo -e "${BLUE}Files to check:${NC}"
echo "$EDITED_FILES" | while read -r file; do
    if [ -n "$file" ]; then
        echo "  • $file"
    fi
done
echo ""

# Create a formatted message for Claude to process
cat > "$MCS_REPORT" << EOF
═══════════════════════════════════════════════════════════
              MCS COMPLIANCE CHECK REQUEST
═══════════════════════════════════════════════════════════

This is an automated end-of-session style check.

FILES TO CHECK:
$EDITED_FILES

Please use the maysara-style-enforcer agent to:
1. Check each file for MCS compliance
2. Report any violations found
3. Provide a summary of compliance status

Focus on these key MCS aspects:
- File header format
- Section demarcation (╔══ SECTION ══╗)
- Code indentation (4 spaces within sections)
- Function documentation format
- Test naming conventions
- Error handling patterns

Provide actionable feedback for any violations found.
═══════════════════════════════════════════════════════════
EOF

# Output the report request
cat "$MCS_REPORT"

echo ""
echo -e "${YELLOW}⚠️  IMPORTANT:${NC} Run '/mcs-check --session' to perform the actual style check."
echo -e "${YELLOW}   The edited files have been tracked and are ready for review.${NC}"
echo ""

# Optionally clear the session files after reporting
# Uncomment the following line if you want to auto-clear after each session
# $TRACK_SCRIPT clear

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Session style check preparation complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"