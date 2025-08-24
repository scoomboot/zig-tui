---
name: mcs-check
description: Check code compliance with Maysara Code Style (MCS) guidelines
enabled-tools:
  - Task
  - Bash
  - Read
  - Grep
  - Glob
---

# MCS Style Check Command

Analyze code for compliance with the Maysara Code Style guidelines defined in @docs/MCS.md.

## Processing Arguments: $ARGUMENTS

!echo "Starting MCS compliance check..."

## Determine Files to Check

Based on the arguments provided:
- If argument contains specific file paths → check those files
- If argument is "--session" or "-s" → check all files edited in current session
- If argument is "--all" or "-a" → check all .zig files in the project
- If no arguments → check files edited in current session (default)

## Get List of Files

!if [ "$ARGUMENTS" = "--session" ] || [ "$ARGUMENTS" = "-s" ] || [ -z "$ARGUMENTS" ]; then
    # Check session edited files
    echo "Checking files edited in current session..."
    /home/fisty/code/zig-tui/.claude/scripts/track-edits.sh list
elif [ "$ARGUMENTS" = "--all" ] || [ "$ARGUMENTS" = "-a" ]; then
    # Check all .zig files
    echo "Checking all .zig files in project..."
    find /home/fisty/code/zig-tui -name "*.zig" -type f | grep -v ".zig-cache" | head -20
else
    # Check specific files
    echo "Checking specified files: $ARGUMENTS"
    echo "$ARGUMENTS"
fi

## Launch Style Enforcer Agent

Now use the @agent-maysara-style-enforcer to analyze the identified files for MCS compliance.

The agent should:
1. Load the MCS guidelines from @docs/MCS.md
2. Analyze each file systematically
3. Report violations with severity levels
4. Provide corrected code snippets
5. Generate a comprehensive compliance report

## Summary

After the style check is complete, provide:
- Total number of files checked
- Number of compliant vs non-compliant files
- Summary of violations by severity
- Recommendations for fixing critical issues

## Usage Examples

```bash
# Check files edited in current session (default)
/mcs-check

# Explicitly check session files
/mcs-check --session

# Check all .zig files in project
/mcs-check --all

# Check specific files
/mcs-check src/parser.zig src/lexer.zig

# Check files matching a pattern
/mcs-check src/**/*.zig
```