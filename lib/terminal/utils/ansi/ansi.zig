// ansi.zig — ANSI escape sequence utilities
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const fmt = std.fmt;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // ┌──────────────────────────── Escape Sequences ────────────────────────────┐

        /// ESC character
        pub const ESC = "\x1b";
        
        /// Control Sequence Introducer
        pub const CSI = ESC ++ "[";
        
        /// Operating System Command
        pub const OSC = ESC ++ "]";
        
        /// Device Control String
        pub const DCS = ESC ++ "P";

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Common Sequences ────────────────────────────┐

        /// Reset all attributes
        pub const RESET = CSI ++ "0m";
        
        /// Clear entire screen and move cursor to home
        pub const CLEAR_SCREEN = CSI ++ "2J";
        
        /// Clear entire line
        pub const CLEAR_LINE = CSI ++ "2K";
        
        /// Clear from cursor to end of screen
        pub const CLEAR_TO_END = CSI ++ "J";
        
        /// Clear from cursor to beginning of screen
        pub const CLEAR_TO_BEGIN = CSI ++ "1J";
        
        /// Clear from cursor to end of line
        pub const CLEAR_TO_EOL = CSI ++ "K";
        
        /// Hide cursor
        pub const HIDE_CURSOR = CSI ++ "?25l";
        
        /// Show cursor
        pub const SHOW_CURSOR = CSI ++ "?25h";
        
        /// Save cursor position
        pub const SAVE_CURSOR = CSI ++ "s";
        
        /// Restore cursor position
        pub const RESTORE_CURSOR = CSI ++ "u";
        
        /// Enter alternate screen buffer
        pub const ALT_SCREEN = CSI ++ "?1049h";
        
        /// Return to main screen buffer
        pub const MAIN_SCREEN = CSI ++ "?1049l";
        
        /// Enable mouse tracking
        pub const MOUSE_ON = CSI ++ "?1000h";
        
        /// Disable mouse tracking
        pub const MOUSE_OFF = CSI ++ "?1000l";

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Type Definitions ────────────────────────────┐

        /// Color representation supporting multiple modes
        pub const Color = union(enum) {
            basic: u8,        // 0-7 (standard colors)
            extended: u8,     // 0-15 (includes bright variants)
            indexed: u8,      // 0-255 (256-color palette)
            rgb: struct { r: u8, g: u8, b: u8 }, // True color (24-bit)
            
            /// Convert color to foreground ANSI sequence
            pub inline fn toFgSequence(self: Color, buf: []u8) ![]u8 {
                return switch (self) {
                    .basic => |c| try fmt.bufPrint(buf, "{s}3{}m", .{ CSI, c }),
                    .extended => |c| if (c < 8)
                        try fmt.bufPrint(buf, "{s}3{}m", .{ CSI, c })
                    else
                        try fmt.bufPrint(buf, "{s}9{}m", .{ CSI, c - 8 }),
                    .indexed => |c| try fmt.bufPrint(buf, "{s}38;5;{}m", .{ CSI, c }),
                    .rgb => |rgb| try fmt.bufPrint(buf, "{s}38;2;{};{};{}m", 
                        .{ CSI, rgb.r, rgb.g, rgb.b }),
                };
            }
            
            /// Convert color to background ANSI sequence
            pub inline fn toBgSequence(self: Color, buf: []u8) ![]u8 {
                return switch (self) {
                    .basic => |c| try fmt.bufPrint(buf, "{s}4{}m", .{ CSI, c }),
                    .extended => |c| if (c < 8)
                        try fmt.bufPrint(buf, "{s}4{}m", .{ CSI, c })
                    else
                        try fmt.bufPrint(buf, "{s}10{}m", .{ CSI, c - 8 }),
                    .indexed => |c| try fmt.bufPrint(buf, "{s}48;5;{}m", .{ CSI, c }),
                    .rgb => |rgb| try fmt.bufPrint(buf, "{s}48;2;{};{};{}m", 
                        .{ CSI, rgb.r, rgb.g, rgb.b }),
                };
            }
        };
        
        /// Text style attributes
        pub const Style = struct {
            bold: bool = false,
            dim: bool = false,
            italic: bool = false,
            underline: bool = false,
            blink: bool = false,
            reverse: bool = false,
            hidden: bool = false,
            strikethrough: bool = false,
            
            /// Convert style to ANSI sequence
            pub inline fn toSequence(self: Style, buf: []u8) ![]u8 {
                var stream = std.io.fixedBufferStream(buf);
                const writer = stream.writer();
                
                if (self.bold) try writer.writeAll(CSI ++ "1m");
                if (self.dim) try writer.writeAll(CSI ++ "2m");
                if (self.italic) try writer.writeAll(CSI ++ "3m");
                if (self.underline) try writer.writeAll(CSI ++ "4m");
                if (self.blink) try writer.writeAll(CSI ++ "5m");
                if (self.reverse) try writer.writeAll(CSI ++ "7m");
                if (self.hidden) try writer.writeAll(CSI ++ "8m");
                if (self.strikethrough) try writer.writeAll(CSI ++ "9m");
                
                return buf[0..stream.pos];
            }
        };

    // └──────────────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    // ┌──────────────────────────── ANSI Builder ────────────────────────────┐

        /// Efficient ANSI sequence builder
        pub const Ansi = struct {
            buffer: std.ArrayList(u8),
            
            /// Initialize a new ANSI sequence builder
            ///
            /// __Parameters__
            /// - `allocator`: Memory allocator for buffer management
            ///
            /// __Return__
            /// - New Ansi builder instance
            pub inline fn init(allocator: std.mem.Allocator) Ansi {
                return .{
                    .buffer = std.ArrayList(u8).init(allocator),
                };
            }
            
            /// Clean up resources
            pub inline fn deinit(self: *Ansi) void {
                self.buffer.deinit();
            }
            
            /// Move cursor to absolute position (1-based indexing)
            ///
            /// __Parameters__
            /// - `row`: Target row (1-based)
            /// - `col`: Target column (1-based)
            pub inline fn moveTo(self: *Ansi, row: u16, col: u16) !void {
                try fmt.format(self.buffer.writer(), "{s}{};{}H", .{ CSI, row, col });
            }
            
            /// Move cursor up by n lines
            ///
            /// __Parameters__
            /// - `n`: Number of lines to move up
            pub inline fn moveUp(self: *Ansi, n: u16) !void {
                if (n == 0) return;
                try fmt.format(self.buffer.writer(), "{s}{}A", .{ CSI, n });
            }
            
            /// Move cursor down by n lines
            ///
            /// __Parameters__
            /// - `n`: Number of lines to move down
            pub inline fn moveDown(self: *Ansi, n: u16) !void {
                if (n == 0) return;
                try fmt.format(self.buffer.writer(), "{s}{}B", .{ CSI, n });
            }
            
            /// Move cursor right by n columns
            ///
            /// __Parameters__
            /// - `n`: Number of columns to move right
            pub inline fn moveRight(self: *Ansi, n: u16) !void {
                if (n == 0) return;
                try fmt.format(self.buffer.writer(), "{s}{}C", .{ CSI, n });
            }
            
            /// Move cursor left by n columns
            ///
            /// __Parameters__
            /// - `n`: Number of columns to move left
            pub inline fn moveLeft(self: *Ansi, n: u16) !void {
                if (n == 0) return;
                try fmt.format(self.buffer.writer(), "{s}{}D", .{ CSI, n });
            }
            
            /// Set foreground color
            ///
            /// __Parameters__
            /// - `color`: Color to set (supports all color modes)
            pub inline fn setFg(self: *Ansi, color: Color) !void {
                const writer = self.buffer.writer();
                switch (color) {
                    .basic => |c| try fmt.format(writer, "{s}3{}m", .{ CSI, c }),
                    .extended => |c| {
                        if (c < 8) {
                            try fmt.format(writer, "{s}3{}m", .{ CSI, c });
                        } else {
                            try fmt.format(writer, "{s}9{}m", .{ CSI, c - 8 });
                        }
                    },
                    .indexed => |c| try fmt.format(writer, "{s}38;5;{}m", .{ CSI, c }),
                    .rgb => |rgb| try fmt.format(writer, "{s}38;2;{};{};{}m", 
                        .{ CSI, rgb.r, rgb.g, rgb.b }),
                }
            }
            
            /// Set background color
            ///
            /// __Parameters__
            /// - `color`: Color to set (supports all color modes)
            pub inline fn setBg(self: *Ansi, color: Color) !void {
                const writer = self.buffer.writer();
                switch (color) {
                    .basic => |c| try fmt.format(writer, "{s}4{}m", .{ CSI, c }),
                    .extended => |c| {
                        if (c < 8) {
                            try fmt.format(writer, "{s}4{}m", .{ CSI, c });
                        } else {
                            try fmt.format(writer, "{s}10{}m", .{ CSI, c - 8 });
                        }
                    },
                    .indexed => |c| try fmt.format(writer, "{s}48;5;{}m", .{ CSI, c }),
                    .rgb => |rgb| try fmt.format(writer, "{s}48;2;{};{};{}m", 
                        .{ CSI, rgb.r, rgb.g, rgb.b }),
                }
            }
            
            /// Apply text styling
            ///
            /// __Parameters__
            /// - `style`: Style attributes to apply
            pub inline fn setStyle(self: *Ansi, style: Style) !void {
                if (style.bold) try self.buffer.appendSlice(CSI ++ "1m");
                if (style.dim) try self.buffer.appendSlice(CSI ++ "2m");
                if (style.italic) try self.buffer.appendSlice(CSI ++ "3m");
                if (style.underline) try self.buffer.appendSlice(CSI ++ "4m");
                if (style.blink) try self.buffer.appendSlice(CSI ++ "5m");
                if (style.reverse) try self.buffer.appendSlice(CSI ++ "7m");
                if (style.hidden) try self.buffer.appendSlice(CSI ++ "8m");
                if (style.strikethrough) try self.buffer.appendSlice(CSI ++ "9m");
            }
            
            /// Reset all attributes
            pub inline fn reset(self: *Ansi) !void {
                try self.buffer.appendSlice(RESET);
            }
            
            /// Save cursor position
            pub inline fn saveCursor(self: *Ansi) !void {
                try self.buffer.appendSlice(SAVE_CURSOR);
            }
            
            /// Restore cursor position
            pub inline fn restoreCursor(self: *Ansi) !void {
                try self.buffer.appendSlice(RESTORE_CURSOR);
            }
            
            /// Clear screen
            pub inline fn clearScreen(self: *Ansi) !void {
                try self.buffer.appendSlice(CLEAR_SCREEN);
                try self.moveTo(1, 1); // Move to home position
            }
            
            /// Clear current line
            pub inline fn clearLine(self: *Ansi) !void {
                try self.buffer.appendSlice(CLEAR_LINE);
            }
            
            /// Clear from cursor to end of line
            pub inline fn clearToEol(self: *Ansi) !void {
                try self.buffer.appendSlice(CLEAR_TO_EOL);
            }
            
            /// Show cursor
            pub inline fn showCursor(self: *Ansi) !void {
                try self.buffer.appendSlice(SHOW_CURSOR);
            }
            
            /// Hide cursor
            pub inline fn hideCursor(self: *Ansi) !void {
                try self.buffer.appendSlice(HIDE_CURSOR);
            }
            
            /// Enter alternate screen buffer
            pub inline fn enterAltScreen(self: *Ansi) !void {
                try self.buffer.appendSlice(ALT_SCREEN);
            }
            
            /// Exit alternate screen buffer
            pub inline fn exitAltScreen(self: *Ansi) !void {
                try self.buffer.appendSlice(MAIN_SCREEN);
            }
            
            /// Scroll up by n lines
            ///
            /// __Parameters__
            /// - `n`: Number of lines to scroll
            pub inline fn scrollUp(self: *Ansi, n: u16) !void {
                if (n == 0) return;
                try fmt.format(self.buffer.writer(), "{s}{}S", .{ CSI, n });
            }
            
            /// Scroll down by n lines
            ///
            /// __Parameters__
            /// - `n`: Number of lines to scroll
            pub inline fn scrollDown(self: *Ansi, n: u16) !void {
                if (n == 0) return;
                try fmt.format(self.buffer.writer(), "{s}{}T", .{ CSI, n });
            }
            
            /// Set scrolling region
            ///
            /// __Parameters__
            /// - `top`: Top line of scrolling region (1-based)
            /// - `bottom`: Bottom line of scrolling region (1-based)
            pub inline fn setScrollRegion(self: *Ansi, top: u16, bottom: u16) !void {
                try fmt.format(self.buffer.writer(), "{s}{};{}r", .{ CSI, top, bottom });
            }
            
            /// Get the built sequence
            ///
            /// __Return__
            /// - Slice containing the built ANSI sequence
            pub inline fn getSequence(self: *const Ansi) []const u8 {
                return self.buffer.items;
            }
            
            /// Clear the buffer for reuse
            pub inline fn clear(self: *Ansi) void {
                self.buffer.clearRetainingCapacity();
            }
            
            /// Write sequence to a writer
            ///
            /// __Parameters__
            /// - `writer`: Writer to output the sequence to
            pub inline fn writeTo(self: *const Ansi, writer: anytype) !void {
                try writer.writeAll(self.buffer.items);
            }
        };

    // └──────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Static Helpers ────────────────────────────┐

        /// Generate cursor position sequence
        ///
        /// __Parameters__
        /// - `row`: Target row (1-based)
        /// - `col`: Target column (1-based)
        /// - `buf`: Buffer to write sequence into
        ///
        /// __Return__
        /// - Slice containing the cursor position sequence
        pub inline fn cursorPosition(row: u16, col: u16, buf: []u8) ![]u8 {
            return try fmt.bufPrint(buf, "{s}{};{}H", .{ CSI, row, col });
        }
        
        /// Generate color sequence
        ///
        /// __Parameters__
        /// - `fg`: Optional foreground color
        /// - `bg`: Optional background color
        /// - `buf`: Buffer to write sequence into
        ///
        /// __Return__
        /// - Slice containing the color sequence
        pub inline fn colorSequence(fg: ?Color, bg: ?Color, buf: []u8) ![]u8 {
            var stream = std.io.fixedBufferStream(buf);
            const writer = stream.writer();
            
            if (fg) |color| {
                switch (color) {
                    .basic => |c| try fmt.format(writer, "{s}3{}m", .{ CSI, c }),
                    .extended => |c| {
                        if (c < 8) {
                            try fmt.format(writer, "{s}3{}m", .{ CSI, c });
                        } else {
                            try fmt.format(writer, "{s}9{}m", .{ CSI, c - 8 });
                        }
                    },
                    .indexed => |c| try fmt.format(writer, "{s}38;5;{}m", .{ CSI, c }),
                    .rgb => |rgb| try fmt.format(writer, "{s}38;2;{};{};{}m", 
                        .{ CSI, rgb.r, rgb.g, rgb.b }),
                }
            }
            
            if (bg) |color| {
                switch (color) {
                    .basic => |c| try fmt.format(writer, "{s}4{}m", .{ CSI, c }),
                    .extended => |c| {
                        if (c < 8) {
                            try fmt.format(writer, "{s}4{}m", .{ CSI, c });
                        } else {
                            try fmt.format(writer, "{s}10{}m", .{ CSI, c - 8 });
                        }
                    },
                    .indexed => |c| try fmt.format(writer, "{s}48;5;{}m", .{ CSI, c }),
                    .rgb => |rgb| try fmt.format(writer, "{s}48;2;{};{};{}m", 
                        .{ CSI, rgb.r, rgb.g, rgb.b }),
                }
            }
            
            return buf[0..stream.pos];
        }
        
        /// Generate style sequence
        ///
        /// __Parameters__
        /// - `style`: Style attributes to apply
        /// - `buf`: Buffer to write sequence into
        ///
        /// __Return__
        /// - Slice containing the style sequence
        pub inline fn styleSequence(style: Style, buf: []u8) ![]u8 {
            return try style.toSequence(buf);
        }
        
        /// Generate movement sequence
        ///
        /// __Parameters__
        /// - `direction`: Direction character ('A'=up, 'B'=down, 'C'=right, 'D'=left)
        /// - `n`: Number of positions to move
        /// - `buf`: Buffer to write sequence into
        ///
        /// __Return__
        /// - Slice containing the movement sequence
        pub inline fn movementSequence(direction: u8, n: u16, buf: []u8) ![]u8 {
            if (n == 0) return buf[0..0];
            return try fmt.bufPrint(buf, "{s}{}{c}", .{ CSI, n, direction });
        }
        
        /// Generate clear sequence
        ///
        /// __Parameters__
        /// - `mode`: Clear mode (0=to end, 1=to beginning, 2=entire)
        /// - `target`: Target ('J'=screen, 'K'=line)
        /// - `buf`: Buffer to write sequence into
        ///
        /// __Return__
        /// - Slice containing the clear sequence
        pub inline fn clearSequence(mode: u8, target: u8, buf: []u8) ![]u8 {
            if (mode == 0) {
                return try fmt.bufPrint(buf, "{s}{c}", .{ CSI, target });
            } else {
                return try fmt.bufPrint(buf, "{s}{}{c}", .{ CSI, mode, target });
            }
        }

    // └──────────────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝