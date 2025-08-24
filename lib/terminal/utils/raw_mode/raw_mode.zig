// raw_mode.zig — Terminal raw mode handling for Unix-like systems
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══ PACK ══╗

    const std = @import("std");
    const builtin = @import("builtin");
    const os = std.os;

// ╚══════════╝

// ╔══ CORE ══╗

    /// Termios structure for terminal settings
    pub const Termios = if (builtin.os.tag == .windows)
        struct {
            // Windows console mode placeholder
            mode: u32,
        }
    else
        os.linux.termios;
    
    /// Enable raw mode and return original termios
    pub fn enable_raw_mode() !Termios {
        if (builtin.os.tag == .windows) {
            // Windows implementation placeholder
            return Termios{ .mode = 0 };
        } else {
            return enable_raw_mode_unix();
        }
    }
    
    /// Restore terminal to original mode
    pub fn restore_mode(original: Termios) !void {
        if (builtin.os.tag == .windows) {
            // Windows implementation placeholder
            // TODO: Implement Windows restore mode
            return error.NotImplemented;
        } else {
            try restore_mode_unix(original);
        }
    }
    
    // ┌────────────── UNIX IMPLEMENTATION ──────────────┐
    
        fn enable_raw_mode_unix() !Termios {
            const stdin_fd = std.io.getStdIn().handle;
            
            // Get current terminal settings
            const original = try os.tcgetattr(stdin_fd);
            
            // Create raw mode settings
            var raw = original;
            
            // Input flags
            raw.iflag.IGNBRK = false;
            raw.iflag.BRKINT = false;
            raw.iflag.PARMRK = false;
            raw.iflag.ISTRIP = false;
            raw.iflag.INLCR = false;
            raw.iflag.IGNCR = false;
            raw.iflag.ICRNL = false;
            raw.iflag.IXON = false;
            
            // Output flags
            raw.oflag.OPOST = false;
            
            // Control flags
            raw.cflag.CSIZE = .CS8;
            raw.cflag.PARENB = false;
            
            // Local flags
            raw.lflag.ECHO = false;
            raw.lflag.ECHONL = false;
            raw.lflag.ICANON = false;
            raw.lflag.ISIG = false;
            raw.lflag.IEXTEN = false;
            
            // Control characters
            raw.cc[@intFromEnum(os.linux.V.MIN)] = 1;
            raw.cc[@intFromEnum(os.linux.V.TIME)] = 0;
            
            // Apply raw mode settings
            try os.tcsetattr(stdin_fd, .FLUSH, raw);
            
            return original;
        }
        
        fn restore_mode_unix(original: Termios) !void {
            const stdin_fd = std.io.getStdIn().handle;
            try os.tcsetattr(stdin_fd, .FLUSH, original);
        }

    // └───────────────────────────────────────────────┘
    
    // ┌────────────── HELPER FUNCTIONS ──────────────┐
    
        /// Check if terminal is in raw mode
        pub fn is_raw_mode() bool {
            if (builtin.os.tag == .windows) {
                // Windows implementation placeholder
                return false;
            } else {
                const stdin_fd = std.io.getStdIn().handle;
                const termios = os.tcgetattr(stdin_fd) catch return false;
                
                // Check if canonical mode is disabled
                return !termios.lflag.ICANON;
            }
        }
        
        /// Set terminal read timeout
        pub fn set_read_timeout(timeout_deciseconds: u8) !void {
            if (builtin.os.tag == .windows) {
                // Windows implementation placeholder
                // TODO: Implement Windows timeout setting
                return error.NotImplemented;
            } else {
                const stdin_fd = std.io.getStdIn().handle;
                var termios = try os.tcgetattr(stdin_fd);
                
                termios.cc[@intFromEnum(os.linux.V.TIME)] = timeout_deciseconds;
                termios.cc[@intFromEnum(os.linux.V.MIN)] = 0;
                
                try os.tcsetattr(stdin_fd, .NOW, termios);
            }
        }
        
        /// Set minimum characters for read
        pub fn set_read_min_chars(min_chars: u8) !void {
            if (builtin.os.tag == .windows) {
                // Windows implementation placeholder
                // TODO: Implement Windows min chars setting
                return error.NotImplemented;
            } else {
                const stdin_fd = std.io.getStdIn().handle;
                var termios = try os.tcgetattr(stdin_fd);
                
                termios.cc[@intFromEnum(os.linux.V.MIN)] = min_chars;
                
                try os.tcsetattr(stdin_fd, .NOW, termios);
            }
        }

    // └───────────────────────────────────────────────┘

// ╚══════════╝