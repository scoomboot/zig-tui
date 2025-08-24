// terminal.zig — Core terminal operations and management
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══ PACK ══╗

    const std = @import("std");
    const ansi = @import("utils/ansi/ansi.zig");
    const raw_mode = @import("utils/raw_mode/raw_mode.zig");

// ╚══════════╝

// ╔══ CORE ══╗

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
    
    /// Main terminal structure
    pub const Terminal = struct {
        allocator: std.mem.Allocator,
        raw_mode_enabled: bool,
        original_termios: ?raw_mode.Termios,
        stdout: std.fs.File,
        stdin: std.fs.File,
        
        /// Initialize terminal
        pub fn init(allocator: std.mem.Allocator) !Terminal {
            return Terminal{
                .allocator = allocator,
                .raw_mode_enabled = false,
                .original_termios = null,
                .stdout = std.io.getStdOut(),
                .stdin = std.io.getStdIn(),
            };
        }
        
        /// Deinitialize terminal
        pub fn deinit(self: *Terminal) void {
            if (self.raw_mode_enabled) {
                self.exit_raw_mode() catch {};
            }
        }
        
        /// Enter raw mode
        pub fn enter_raw_mode(self: *Terminal) !void {
            if (self.raw_mode_enabled) return;
            
            self.original_termios = try raw_mode.enable_raw_mode();
            self.raw_mode_enabled = true;
        }
        
        /// Exit raw mode
        pub fn exit_raw_mode(self: *Terminal) !void {
            if (!self.raw_mode_enabled) return;
            
            if (self.original_termios) |termios| {
                try raw_mode.restore_mode(termios);
            }
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
        }
        
        /// Show cursor
        pub fn show_cursor(self: *Terminal) !void {
            try ansi.show_cursor(self.stdout);
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

// ╚══════════╝