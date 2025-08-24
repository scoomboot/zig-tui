# Issue #006: Implement terminal core

## Summary
Implement the core Terminal struct that orchestrates raw mode, ANSI sequences, and provides high-level terminal operations.

## Description
Create the main Terminal implementation that combines raw mode handling and ANSI sequences to provide a complete terminal abstraction. This module should handle initialization, cleanup, and all terminal operations needed by the TUI library.

## Acceptance Criteria
- [ ] Create `lib/terminal/terminal.zig`
- [ ] Implement Terminal struct with:
  - [ ] Initialization and cleanup
  - [ ] Raw mode management
  - [ ] Screen clearing
  - [ ] Cursor control
  - [ ] Alternative screen buffer
  - [ ] Terminal size queries
- [ ] Handle cross-platform differences
- [ ] Implement proper error handling
- [ ] Add signal handling for cleanup
- [ ] Ensure thread safety where needed
- [ ] Create comprehensive tests
- [ ] Follow MCS style guidelines

## Dependencies
- Issue #004 (Implement raw mode)
- Issue #005 (Implement ANSI sequences)

## Implementation Notes
```zig
// terminal.zig — Core terminal abstraction
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const RawMode = @import("utils/raw_mode/raw_mode.zig").RawMode;
    const ansi = @import("utils/ansi/ansi.zig");
    const os = std.os;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    pub const TerminalError = error{
        InitFailed,
        NotATTY,
        GetSizeFailed,
        WriteFailed,
        RawModeFailed,
    };

    pub const Size = struct {
        rows: u16,
        cols: u16,
    };

    pub const CursorStyle = enum {
        default,
        block,
        underline,
        bar,
        blinking_block,
        blinking_underline,
        blinking_bar,
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    pub const Terminal = struct {
        allocator: std.mem.Allocator,
        raw_mode: RawMode,
        stdout: std.fs.File,
        stdin: std.fs.File,
        is_raw: bool,
        use_alt_screen: bool,
        cursor_visible: bool,
        size: Size,
        ansi_builder: ansi.Ansi,

        // ┌──────────────────────────── Initialization ────────────────────────────┐

            /// Initialize terminal with default settings
            pub fn init(allocator: std.mem.Allocator) !Terminal {
                const stdout = std.io.getStdOut();
                const stdin = std.io.getStdIn();

                // Check if we're connected to a terminal
                if (!os.isatty(stdout.handle)) {
                    return TerminalError.NotATTY;
                }

                var term = Terminal{
                    .allocator = allocator,
                    .raw_mode = try RawMode.init(),
                    .stdout = stdout,
                    .stdin = stdin,
                    .is_raw = false,
                    .use_alt_screen = false,
                    .cursor_visible = true,
                    .size = try querySize(),
                    .ansi_builder = ansi.Ansi.init(allocator),
                };

                // Set up signal handlers for cleanup
                try term.setupSignalHandlers();

                return term;
            }

            /// Clean up and restore terminal state
            pub fn deinit(self: *Terminal) void {
                // Exit raw mode if active
                if (self.is_raw) {
                    self.exitRawMode() catch {};
                }

                // Exit alternative screen if active
                if (self.use_alt_screen) {
                    self.exitAltScreen() catch {};
                }

                // Show cursor if hidden
                if (!self.cursor_visible) {
                    self.showCursor() catch {};
                }

                self.ansi_builder.deinit();
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Mode Control ────────────────────────────┐

            /// Enter raw mode for direct input handling
            pub fn enterRawMode(self: *Terminal) !void {
                if (self.is_raw) return;
                
                try self.raw_mode.enter();
                self.is_raw = true;
            }

            /// Exit raw mode and restore normal terminal behavior
            pub fn exitRawMode(self: *Terminal) !void {
                if (!self.is_raw) return;
                
                try self.raw_mode.exit();
                self.is_raw = false;
            }

            /// Switch to alternative screen buffer
            pub fn enterAltScreen(self: *Terminal) !void {
                if (self.use_alt_screen) return;
                
                try self.writeSequence(ansi.ALT_SCREEN);
                self.use_alt_screen = true;
            }

            /// Return to main screen buffer
            pub fn exitAltScreen(self: *Terminal) !void {
                if (!self.use_alt_screen) return;
                
                try self.writeSequence(ansi.MAIN_SCREEN);
                self.use_alt_screen = false;
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Screen Operations ────────────────────────────┐

            /// Clear entire screen
            pub fn clear(self: *Terminal) !void {
                try self.writeSequence(ansi.CLEAR_SCREEN);
                try self.setCursorPos(1, 1);
            }

            /// Clear current line
            pub fn clearLine(self: *Terminal) !void {
                try self.writeSequence(ansi.CLEAR_LINE);
            }

            /// Get terminal size
            pub fn getSize(self: *Terminal) !Size {
                self.size = try querySize();
                return self.size;
            }

            /// Flush output buffer
            pub fn flush(self: *Terminal) !void {
                // Stdout is unbuffered in raw mode, but flush anyway
                try self.stdout.sync();
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Cursor Control ────────────────────────────┐

            /// Set cursor position (1-based)
            pub fn setCursorPos(self: *Terminal, row: u16, col: u16) !void {
                self.ansi_builder.clear();
                try self.ansi_builder.moveTo(row, col);
                try self.writeSequence(self.ansi_builder.getSequence());
            }

            /// Hide cursor
            pub fn hideCursor(self: *Terminal) !void {
                if (!self.cursor_visible) return;
                
                try self.writeSequence(ansi.HIDE_CURSOR);
                self.cursor_visible = false;
            }

            /// Show cursor
            pub fn showCursor(self: *Terminal) !void {
                if (self.cursor_visible) return;
                
                try self.writeSequence(ansi.SHOW_CURSOR);
                self.cursor_visible = true;
            }

            /// Set cursor style
            pub fn setCursorStyle(self: *Terminal, style: CursorStyle) !void {
                const seq = switch (style) {
                    .default => ansi.CSI ++ "0 q",
                    .block => ansi.CSI ++ "2 q",
                    .underline => ansi.CSI ++ "4 q",
                    .bar => ansi.CSI ++ "6 q",
                    .blinking_block => ansi.CSI ++ "1 q",
                    .blinking_underline => ansi.CSI ++ "3 q",
                    .blinking_bar => ansi.CSI ++ "5 q",
                };
                try self.writeSequence(seq);
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Internal Helpers ────────────────────────────┐

            fn writeSequence(self: *Terminal, seq: []const u8) !void {
                _ = try self.stdout.write(seq);
            }

            fn querySize() !Size {
                // Platform-specific size query
                // Using ioctl on Unix, GetConsoleScreenBufferInfo on Windows
                if (@hasDecl(os.system, "winsize")) {
                    var ws: os.system.winsize = undefined;
                    if (os.system.ioctl(os.STDOUT_FILENO, os.system.TIOCGWINSZ, @ptrToInt(&ws)) != 0) {
                        return TerminalError.GetSizeFailed;
                    }
                    return Size{
                        .rows = ws.ws_row,
                        .cols = ws.ws_col,
                    };
                } else {
                    // Windows implementation
                    return Size{ .rows = 24, .cols = 80 }; // Default fallback
                }
            }

            fn setupSignalHandlers(self: *Terminal) !void {
                // Set up handlers for SIGINT, SIGTERM, etc.
                // Ensure terminal is restored on exit
            }

        // └──────────────────────────────────────────────────────────────────┘

    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Test initialization and cleanup
- Test raw mode enter/exit
- Test alternative screen buffer
- Test cursor operations
- Test screen clearing
- Test size detection
- Verify terminal restoration on crash
- Cross-platform testing

## Estimated Time
4 hours

## Priority
🔴 Critical - Core functionality

## Category
Terminal Core

## Integration Note (2025-08-24)
⚠️ **IMPORTANT**: The current terminal.zig implementation uses the old function-based raw_mode API (`enable_raw_mode()`, `restore_mode()`, `Termios`). This needs to be updated to use the new RawMode struct that was implemented in Issue #004. The terminal module should:
- Create and manage a RawMode instance
- Use `RawMode.init()`, `enter()`, and `exit()` methods
- Remove direct Termios handling
- Follow the implementation pattern shown in the Implementation Notes section below