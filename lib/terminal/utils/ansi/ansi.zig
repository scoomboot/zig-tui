// ansi.zig — ANSI escape sequence utilities
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══ PACK ══╗

    const std = @import("std");

// ╚══════════╝

// ╔══ CORE ══╗

    // ┌────────────── ESCAPE SEQUENCES ──────────────┐
    
        /// ESC character
        pub const ESC = "\x1B";
        
        /// Control Sequence Introducer
        pub const CSI = ESC ++ "[";
        
        /// Operating System Command
        pub const OSC = ESC ++ "]";

    // └───────────────────────────────────────────────┘
    
    // ┌────────────── CURSOR CONTROL ──────────────┐
    
        /// Move cursor to position (1-based)
        pub fn move_cursor(writer: anytype, x: u16, y: u16) !void {
            try writer.print("{s}{d};{d}H", .{ CSI, y + 1, x + 1 });
        }
        
        /// Move cursor up
        pub fn cursor_up(writer: anytype, n: u16) !void {
            try writer.print("{s}{d}A", .{ CSI, n });
        }
        
        /// Move cursor down
        pub fn cursor_down(writer: anytype, n: u16) !void {
            try writer.print("{s}{d}B", .{ CSI, n });
        }
        
        /// Move cursor forward
        pub fn cursor_forward(writer: anytype, n: u16) !void {
            try writer.print("{s}{d}C", .{ CSI, n });
        }
        
        /// Move cursor backward
        pub fn cursor_backward(writer: anytype, n: u16) !void {
            try writer.print("{s}{d}D", .{ CSI, n });
        }
        
        /// Save cursor position
        pub fn save_cursor(writer: anytype) !void {
            try writer.writeAll(CSI ++ "s");
        }
        
        /// Restore cursor position
        pub fn restore_cursor(writer: anytype) !void {
            try writer.writeAll(CSI ++ "u");
        }
        
        /// Hide cursor
        pub fn hide_cursor(writer: anytype) !void {
            try writer.writeAll(CSI ++ "?25l");
        }
        
        /// Show cursor
        pub fn show_cursor(writer: anytype) !void {
            try writer.writeAll(CSI ++ "?25h");
        }

    // └───────────────────────────────────────────────┘
    
    // ┌────────────── SCREEN CONTROL ──────────────┐
    
        /// Clear screen
        pub fn clear_screen(writer: anytype) !void {
            try writer.writeAll(CSI ++ "2J");
            try move_cursor(writer, 0, 0);
        }
        
        /// Clear from cursor to end of screen
        pub fn clear_to_end(writer: anytype) !void {
            try writer.writeAll(CSI ++ "J");
        }
        
        /// Clear from cursor to beginning of screen
        pub fn clear_to_beginning(writer: anytype) !void {
            try writer.writeAll(CSI ++ "1J");
        }
        
        /// Clear current line
        pub fn clear_line(writer: anytype) !void {
            try writer.writeAll(CSI ++ "2K");
        }
        
        /// Clear from cursor to end of line
        pub fn clear_to_eol(writer: anytype) !void {
            try writer.writeAll(CSI ++ "K");
        }

    // └───────────────────────────────────────────────┘
    
    // ┌────────────── COLOR AND STYLE ──────────────┐
    
        /// SGR (Select Graphic Rendition) codes
        pub const SGR = struct {
            pub const reset = 0;
            pub const bold = 1;
            pub const dim = 2;
            pub const italic = 3;
            pub const underline = 4;
            pub const blink = 5;
            pub const reverse = 7;
            pub const hidden = 8;
            pub const strikethrough = 9;
            
            // Foreground colors
            pub const fg_black = 30;
            pub const fg_red = 31;
            pub const fg_green = 32;
            pub const fg_yellow = 33;
            pub const fg_blue = 34;
            pub const fg_magenta = 35;
            pub const fg_cyan = 36;
            pub const fg_white = 37;
            pub const fg_default = 39;
            
            // Background colors
            pub const bg_black = 40;
            pub const bg_red = 41;
            pub const bg_green = 42;
            pub const bg_yellow = 43;
            pub const bg_blue = 44;
            pub const bg_magenta = 45;
            pub const bg_cyan = 46;
            pub const bg_white = 47;
            pub const bg_default = 49;
        };
        
        /// Set SGR parameters
        pub fn set_sgr(writer: anytype, codes: []const u8) !void {
            try writer.print("{s}", .{CSI});
            for (codes, 0..) |code, i| {
                if (i > 0) try writer.writeAll(";");
                try writer.print("{d}", .{code});
            }
            try writer.writeAll("m");
        }
        
        /// Reset all attributes
        pub fn reset_attributes(writer: anytype) !void {
            try writer.writeAll(CSI ++ "0m");
        }
        
        /// Set foreground color (256 colors)
        pub fn set_fg_256(writer: anytype, color: u8) !void {
            try writer.print("{s}38;5;{d}m", .{ CSI, color });
        }
        
        /// Set background color (256 colors)
        pub fn set_bg_256(writer: anytype, color: u8) !void {
            try writer.print("{s}48;5;{d}m", .{ CSI, color });
        }
        
        /// Set foreground color (RGB)
        pub fn set_fg_rgb(writer: anytype, r: u8, g: u8, b: u8) !void {
            try writer.print("{s}38;2;{d};{d};{d}m", .{ CSI, r, g, b });
        }
        
        /// Set background color (RGB)
        pub fn set_bg_rgb(writer: anytype, r: u8, g: u8, b: u8) !void {
            try writer.print("{s}48;2;{d};{d};{d}m", .{ CSI, r, g, b });
        }

    // └───────────────────────────────────────────────┘
    
    // ┌────────────── ALTERNATE SCREEN ──────────────┐
    
        /// Enter alternate screen
        pub fn enter_alt_screen(writer: anytype) !void {
            try writer.writeAll(CSI ++ "?1049h");
        }
        
        /// Exit alternate screen
        pub fn exit_alt_screen(writer: anytype) !void {
            try writer.writeAll(CSI ++ "?1049l");
        }

    // └───────────────────────────────────────────────┘

// ╚══════════╝