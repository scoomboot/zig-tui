# MCS Style Enforcement Automation

<div align="center">
    <p style="font-size: 20px;">
        <i>Automated Maysara Code Style Compliance for Zig Projects</i>
    </p>
</div>

<div align="center">
    <img src="https://raw.githubusercontent.com/maysara-elshewehy/SuperZIG-assets/refs/heads/main/dist/img/md/line.png" alt="line" style="display: block; margin-top:20px;margin-bottom:20px;width:500px;"/>
</div>

## Overview

This document describes the automated MCS (Maysara Code Style) enforcement system integrated with Claude Code. The system provides both manual and automatic style checking for Zig files, ensuring consistent code quality throughout development.

## Features

### 🎯 Automatic File Tracking
- Tracks all `.zig` files edited during a Claude Code session
- Maintains a session-specific list of modified files
- Automatically triggered via PostToolUse hooks

### 🔍 On-Demand Style Checking
- Slash command `/mcs-check` for manual style verification
- Flexible targeting: specific files, session files, or entire project
- Immediate feedback on style violations

### 🚀 Session-End Compliance Check
- Automatic style check preparation when Claude Code session ends
- Comprehensive report of all edited files
- Option to run full compliance check before committing changes

### 🤖 AI-Powered Style Analysis
- Leverages the `maysara-style-enforcer` agent
- Detailed violation reports with severity levels
- Corrected code snippets and explanations

<div align="center">
    <img src="https://raw.githubusercontent.com/maysara-elshewehy/SuperZIG-assets/refs/heads/main/dist/img/md/line.png" alt="line" style="display: block; margin-top:20px;margin-bottom:20px;width:500px;"/>
</div>

## Installation & Setup

The MCS automation system is already configured in this project. Here's what's included:

### Directory Structure
```
.claude/
├── agents/
│   └── maysara-style-enforcer.md    # Style enforcement agent
├── commands/
│   └── mcs-check.md                 # Slash command for style checking
├── scripts/
│   ├── track-edits.sh               # File tracking script
│   └── session-style-check.sh       # Session-end check script
└── settings.json                     # Hooks configuration
```

### Configuration Files

#### 1. **settings.json**
Configures automatic hooks for file tracking and session-end checks:
- PostToolUse hooks track edits to `.zig` files
- Stop hook triggers session-end compliance check

#### 2. **track-edits.sh**
Manages the list of edited files:
- Maintains session-specific tracking
- Filters for `.zig` files only
- Provides list, count, and clear operations

#### 3. **session-style-check.sh**
Prepares compliance report at session end:
- Lists all edited files
- Formats report for style checking
- Provides visual feedback

<div align="center">
    <img src="https://raw.githubusercontent.com/maysara-elshewehy/SuperZIG-assets/refs/heads/main/dist/img/md/line.png" alt="line" style="display: block; margin-top:20px;margin-bottom:20px;width:500px;"/>
</div>

## Usage Guide

### Manual Style Checking

Use the `/mcs-check` slash command with various options:

```bash
# Check files edited in current session (default)
/mcs-check

# Explicitly check session files
/mcs-check --session
/mcs-check -s

# Check all .zig files in project
/mcs-check --all
/mcs-check -a

# Check specific files
/mcs-check src/parser.zig src/lexer.zig

# Check files matching a pattern
/mcs-check src/**/*.zig
```

### Automatic Tracking

Files are automatically tracked when you:
- Edit existing `.zig` files
- Create new `.zig` files
- Modify multiple files with MultiEdit

### Session-End Review

When your Claude Code session ends:
1. The Stop hook triggers automatically
2. Session style check script runs
3. You see a summary of edited files
4. Run `/mcs-check --session` to perform the actual check

### Managing Tracked Files

Use the tracking script directly for advanced operations:

```bash
# List tracked files
.claude/scripts/track-edits.sh list

# Count tracked files
.claude/scripts/track-edits.sh count

# Clear tracking (new session)
.claude/scripts/track-edits.sh clear

# Get session ID
.claude/scripts/track-edits.sh session
```

<div align="center">
    <img src="https://raw.githubusercontent.com/maysara-elshewehy/SuperZIG-assets/refs/heads/main/dist/img/md/line.png" alt="line" style="display: block; margin-top:20px;margin-bottom:20px;width:500px;"/>
</div>

## MCS Compliance Report Format

The style enforcer generates detailed reports including:

### Report Sections
1. **File Status**: COMPLIANT or NON-COMPLIANT
2. **Violations Found**: Detailed list with:
   - Rule reference from MCS.md
   - Line number and current code
   - Corrected version
   - Explanation
   - Severity level

### Severity Levels
- **CRITICAL**: Breaks compilation or functionality
- **HIGH**: Major style violation
- **MEDIUM**: Minor style issue  
- **LOW**: Suggestion for improvement

### Example Report
```
MCS COMPLIANCE REPORT
=====================
File: src/parser.zig
Status: NON-COMPLIANT

VIOLATIONS FOUND:
----------------
1. [2.1 File Header]: Missing standardized file header
   Line 1: // Simple comment
   Should be: // parser.zig — Core parser implementation
              //
              // repo   : https://github.com/...
              // docs   : https://...
              // author : https://github.com/...
              //
              // Developed with ❤️ by Maysara.
   Reason: All files must begin with the standard MCS header
   Severity: HIGH

SUMMARY:
--------
Total violations: 1
Critical: 0 | High: 1 | Medium: 0 | Low: 0
```

<div align="center">
    <img src="https://raw.githubusercontent.com/maysara-elshewehy/SuperZIG-assets/refs/heads/main/dist/img/md/line.png" alt="line" style="display: block; margin-top:20px;margin-bottom:20px;width:500px;"/>
</div>

## Customization

### Modify Tracking Behavior

Edit `.claude/scripts/track-edits.sh` to:
- Change file extension filters
- Modify tracking location
- Add custom logging

### Adjust Hook Behavior

Edit `.claude/settings.json` to:
- Enable/disable automatic tracking
- Change timeout values
- Add additional hooks

### Customize Style Checking

Edit `.claude/commands/mcs-check.md` to:
- Add new command options
- Change default behavior
- Modify output format

<div align="center">
    <img src="https://raw.githubusercontent.com/maysara-elshewehy/SuperZIG-assets/refs/heads/main/dist/img/md/line.png" alt="line" style="display: block; margin-top:20px;margin-bottom:20px;width:500px;"/>
</div>

## Troubleshooting

### Files Not Being Tracked

1. Ensure hooks are enabled in settings.json
2. Verify file has `.zig` extension
3. Check tracking script permissions: `chmod +x .claude/scripts/*.sh`
4. Restart Claude Code session for hook changes

### Style Check Not Running

1. Verify agent exists: `.claude/agents/maysara-style-enforcer.md`
2. Check MCS.md is accessible: `docs/MCS.md`
3. Ensure slash command is properly formatted
4. Try manual execution: `/mcs-check --session`

### Session-End Hook Not Triggering

1. Verify Stop hook in settings.json
2. Check script permissions
3. Look for error messages in Claude Code output
4. Test manually: `.claude/scripts/session-style-check.sh`

<div align="center">
    <img src="https://raw.githubusercontent.com/maysara-elshewehy/SuperZIG-assets/refs/heads/main/dist/img/md/line.png" alt="line" style="display: block; margin-top:20px;margin-bottom:20px;width:500px;"/>
</div>

## Best Practices

### During Development

1. **Regular Checks**: Run `/mcs-check` periodically during development
2. **Pre-Commit**: Always check style before committing changes
3. **Fix Immediately**: Address CRITICAL and HIGH violations immediately
4. **Document Exceptions**: If deviating from MCS, document why

### Code Review

1. **PR Checks**: Run `/mcs-check --all` before creating pull requests
2. **Review Reports**: Include MCS compliance reports in PR descriptions
3. **Team Standards**: Ensure all team members use the automation

### Continuous Improvement

1. **Update MCS.md**: Document new patterns as they emerge
2. **Refine Agent**: Improve style enforcer based on false positives/negatives
3. **Share Feedback**: Report issues or suggestions for the automation system

<div align="center">
    <img src="https://raw.githubusercontent.com/maysara-elshewehy/SuperZIG-assets/refs/heads/main/dist/img/md/line.png" alt="line" style="display: block; margin-top:20px;margin-bottom:20px;width:500px;"/>
</div>

## Integration with CI/CD

For continuous integration, you can:

1. **GitHub Actions**: Add style check to workflow
2. **Pre-commit Hooks**: Run local style checks before commits
3. **Build Pipeline**: Fail builds on CRITICAL violations

Example GitHub Action step:
```yaml
- name: Check MCS Compliance
  run: |
    # Install Claude Code CLI
    # Run style check on changed files
    claude-code --command "/mcs-check ${{ steps.changed-files.outputs.all }}"
```

<div align="center">
    <img src="https://raw.githubusercontent.com/maysara-elshewehy/SuperZIG-assets/refs/heads/main/dist/img/md/line.png" alt="line" style="display: block; margin-top:20px;margin-bottom:20px;width:500px;"/>
</div>

## Conclusion

The MCS automation system ensures consistent code style across your Zig project with minimal manual effort. By combining automatic tracking, on-demand checking, and session-end reviews, it maintains high code quality standards while staying out of your way during active development.

For questions or improvements, please refer to:
- Main style guide: [docs/MCS.md](./MCS.md)
- Style enforcer agent: [.claude/agents/maysara-style-enforcer.md](../.claude/agents/maysara-style-enforcer.md)
- Project settings: [.claude/settings.json](../.claude/settings.json)

<div align="center">
    <img src="https://raw.githubusercontent.com/maysara-elshewehy/SuperZIG-assets/refs/heads/main/dist/img/md/line.png" alt="line" style="display: block; margin-top:20px;margin-bottom:20px;width:500px;"/>
</div>

<div align="center">
    <a href="https://github.com/maysara-elshewehy">
        <img src="https://img.shields.io/badge/MCS Automation by-Maysara-orange"/>
    </a>
</div>