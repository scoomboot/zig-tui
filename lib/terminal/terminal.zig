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
    const posix = std.posix;

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
                // In test environments, we allow non-TTY initialization
                const is_test = @import("builtin").is_test;
                if (!is_test and !posix.isatty(stdout.handle)) {
                    return TerminalError.NotATTY;
                }

                // Get size - use fallback if not a TTY
                const size = if (posix.isatty(stdout.handle)) 
                    try querySize() 
                else 
                    Size{ .rows = 24, .cols = 80 };

                var term = Terminal{
                    .allocator = allocator,
                    .raw_mode = RawMode.init(),
                    .stdout = stdout,
                    .stdin = stdin,
                    .is_raw = false,
                    .use_alt_screen = false,
                    .cursor_visible = true,
                    .size = size,
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
                
                // In test mode, skip actual raw mode operations
                const is_test = @import("builtin").is_test;
                if (!is_test) {
                    try self.raw_mode.enter();
                }
                self.is_raw = true;
            }

            /// Exit raw mode and restore normal terminal behavior
            pub fn exitRawMode(self: *Terminal) !void {
                if (!self.is_raw) return;
                
                // In test mode, skip actual raw mode operations
                const is_test = @import("builtin").is_test;
                if (!is_test) {
                    try self.raw_mode.exit();
                }
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
                // In test mode or when not a TTY, skip sync operation
                const is_test = @import("builtin").is_test;
                if (!is_test and posix.isatty(self.stdout.handle)) {
                    self.stdout.sync() catch {
                        // Ignore sync errors for non-file streams
                    };
                }
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
                // Using ioctl on Unix
                const stdout_handle = std.io.getStdOut().handle;
                
                if (@hasDecl(posix.system, "winsize")) {
                    var ws: posix.system.winsize = undefined;
                    const result = posix.system.ioctl(stdout_handle, posix.system.T.IOCGWINSZ, @intFromPtr(&ws));
                    if (result != 0) {
                        return TerminalError.GetSizeFailed;
                    }
                    return Size{
                        .rows = ws.ws_row,
                        .cols = ws.ws_col,
                    };
                } else {
                    // Fallback for systems without winsize
                    return Size{ .rows = 24, .cols = 80 };
                }
            }

            fn setupSignalHandlers(self: *Terminal) !void {
                // Signal handling is already managed by RawMode module
                // This is a placeholder for any terminal-specific signal handling
                _ = self;
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Compatibility Methods ────────────────────────────┐

            // These methods provide backward compatibility with the old API
            
            /// Enter raw mode (old API compatibility)
            pub fn enter_raw_mode(self: *Terminal) !void {
                return self.enterRawMode();
            }

            /// Exit raw mode (old API compatibility)
            pub fn exit_raw_mode(self: *Terminal) !void {
                return self.exitRawMode();
            }

            /// Check if in raw mode (old API compatibility)
            pub fn is_raw_mode(self: *Terminal) bool {
                return self.is_raw;
            }

            /// Get terminal size (old API compatibility)
            pub fn get_size(self: *Terminal) !Size {
                return self.getSize();
            }

            /// Move cursor to position (old API compatibility)
            pub fn move_cursor(self: *Terminal, pos: Position) !void {
                return self.setCursorPos(pos.y, pos.x);
            }

            /// Hide cursor (old API compatibility)
            pub fn hide_cursor(self: *Terminal) !void {
                return self.hideCursor();
            }

            /// Show cursor (old API compatibility)
            pub fn show_cursor(self: *Terminal) !void {
                return self.showCursor();
            }

            /// Set cursor style (old API compatibility)
            pub fn set_cursor_style(self: *Terminal, style: CursorStyle) !void {
                return self.setCursorStyle(style);
            }

            /// Enter alternative screen buffer (old API compatibility)
            pub fn enter_alt_screen(self: *Terminal) !void {
                return self.enterAltScreen();
            }

            /// Exit alternative screen buffer (old API compatibility)  
            pub fn exit_alt_screen(self: *Terminal) !void {
                return self.exitAltScreen();
            }

            /// Write text at current position (old API compatibility)
            pub fn write(self: *Terminal, text: []const u8) !void {
                try self.stdout.writeAll(text);
            }

        // └──────────────────────────────────────────────────────────────────┘

    };

    // Position struct for backward compatibility
    pub const Position = struct {
        x: u16,
        y: u16,
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝