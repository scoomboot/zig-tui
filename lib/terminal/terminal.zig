// terminal.zig — Core terminal operations and management
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const ansi = @import("utils/ansi/ansi.zig");
    const raw_mode = @import("utils/raw_mode/raw_mode.zig");

// ╚════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    /// Terminal error types
    pub const TerminalError = error{
        NotATTY,
        RawModeFailed,
        WriteFailed,
        GetSizeFailed,
    };
    
    /// Terminal size structure
    pub const Size = struct {
        width: u16,
        height: u16,
    };
    
    /// Terminal cursor position
    pub const Position = struct {
        x: u16,
        y: u16,
    };
    
    /// Cursor style options
    pub const CursorStyle = enum {
        default,
        block,
        underline,
        bar,
        blinking_block,
        blinking_underline,
        blinking_bar,
    };

// ╚════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗
    
    /// Main terminal structure
    pub const Terminal = struct {
        allocator: std.mem.Allocator,
        raw_mode_enabled: bool,
        raw_mode_handler: ?raw_mode.RawMode,
        stdout: std.fs.File,
        stdin: std.fs.File,
        use_alt_screen: bool,
        cursor_visible: bool,
        
        /// Initialize terminal
        pub fn init(allocator: std.mem.Allocator) !Terminal {
            return Terminal{
                .allocator = allocator,
                .raw_mode_enabled = false,
                .raw_mode_handler = null,
                .stdout = std.io.getStdOut(),
                .stdin = std.io.getStdIn(),
                .use_alt_screen = false,
                .cursor_visible = true,
            };
        }
        
        /// Deinitialize terminal
        pub fn deinit(self: *Terminal) void {
            // Restore terminal state
            if (self.use_alt_screen) {
                self.exit_alt_screen() catch {};
            }
            if (!self.cursor_visible) {
                self.show_cursor() catch {};
            }
            if (self.raw_mode_enabled) {
                self.exit_raw_mode() catch {};
            }
        }
        
        /// Enter raw mode
        pub fn enter_raw_mode(self: *Terminal) !void {
            if (self.raw_mode_enabled) return;
            
            var handler = raw_mode.RawMode.init();
            try handler.enter();
            self.raw_mode_handler = handler;
            self.raw_mode_enabled = true;
        }
        
        /// Check if in raw mode
        pub fn is_raw_mode(self: *Terminal) bool {
            return self.raw_mode_enabled;
        }
        
        /// Exit raw mode
        pub fn exit_raw_mode(self: *Terminal) !void {
            if (!self.raw_mode_enabled) return;
            
            if (self.raw_mode_handler) |*handler| {
                try handler.exit();
            }
            self.raw_mode_handler = null;
            self.raw_mode_enabled = false;
        }
        
        /// Get terminal size
        pub fn get_size(self: *Terminal) !Size {
            _ = self;
            // Placeholder implementation
            return Size{
                .width = 80,
                .height = 24,
            };
        }
        
        /// Clear the screen
        pub fn clear(self: *Terminal) !void {
            try ansi.clear_screen(self.stdout);
        }
        
        /// Move cursor to position
        pub fn move_cursor(self: *Terminal, pos: Position) !void {
            try ansi.move_cursor(self.stdout, pos.x, pos.y);
        }
        
        /// Hide cursor
        pub fn hide_cursor(self: *Terminal) !void {
            try ansi.hide_cursor(self.stdout);
            self.cursor_visible = false;
        }
        
        /// Show cursor
        pub fn show_cursor(self: *Terminal) !void {
            try ansi.show_cursor(self.stdout);
            self.cursor_visible = true;
        }
        
        /// Set cursor style
        pub fn set_cursor_style(self: *Terminal, style: CursorStyle) !void {
            const code = switch (style) {
                .default => "\x1B[0 q",
                .block => "\x1B[2 q",
                .underline => "\x1B[4 q",
                .bar => "\x1B[6 q",
                .blinking_block => "\x1B[1 q",
                .blinking_underline => "\x1B[3 q",
                .blinking_bar => "\x1B[5 q",
            };
            try self.stdout.writeAll(code);
        }
        
        /// Enter alternative screen buffer
        pub fn enter_alt_screen(self: *Terminal) !void {
            if (self.use_alt_screen) return;
            try ansi.enter_alt_screen(self.stdout);
            self.use_alt_screen = true;
        }
        
        /// Exit alternative screen buffer
        pub fn exit_alt_screen(self: *Terminal) !void {
            if (!self.use_alt_screen) return;
            try ansi.exit_alt_screen(self.stdout);
            self.use_alt_screen = false;
        }
        
        /// Write text at current position
        pub fn write(self: *Terminal, text: []const u8) !void {
            try self.stdout.writeAll(text);
        }
        
        /// Flush output
        pub fn flush(self: *Terminal) !void {
            // File handles are unbuffered by default in Zig
            _ = self;
        }
    };

// ╚════════════════════════════════════════════════════════════════════════════════════╝