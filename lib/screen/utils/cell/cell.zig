// cell.zig — Screen cell representation for character and style
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

    /// Color representation
    pub const Color = union(enum) {
        default: void,
        indexed: u8,
        rgb: RGB,
        
        pub const RGB = struct {
            r: u8,
            g: u8,
            b: u8,
        };
        
        /// Common color constants
        pub const black = Color{ .indexed = 0 };
        pub const red = Color{ .indexed = 1 };
        pub const green = Color{ .indexed = 2 };
        pub const yellow = Color{ .indexed = 3 };
        pub const blue = Color{ .indexed = 4 };
        pub const magenta = Color{ .indexed = 5 };
        pub const cyan = Color{ .indexed = 6 };
        pub const white = Color{ .indexed = 7 };
        pub const bright_black = Color{ .indexed = 8 };
        pub const bright_red = Color{ .indexed = 9 };
        pub const bright_green = Color{ .indexed = 10 };
        pub const bright_yellow = Color{ .indexed = 11 };
        pub const bright_blue = Color{ .indexed = 12 };
        pub const bright_magenta = Color{ .indexed = 13 };
        pub const bright_cyan = Color{ .indexed = 14 };
        pub const bright_white = Color{ .indexed = 15 };
    };
    
    /// Style attributes
    pub const Style = struct {
        fg: Color,
        bg: Color,
        attrs: Attributes,
        
        /// Default style
        pub fn default() Style {
            return Style{
                .fg = Color{ .default = {} },
                .bg = Color{ .default = {} },
                .attrs = Attributes{},
            };
        }
        
        /// Create style with foreground color
        pub fn with_fg(fg: Color) Style {
            var style = default();
            style.fg = fg;
            return style;
        }
        
        /// Create style with background color
        pub fn with_bg(bg: Color) Style {
            var style = default();
            style.bg = bg;
            return style;
        }
        
        /// Create style with foreground and background colors
        pub fn with_colors(fg: Color, bg: Color) Style {
            return Style{
                .fg = fg,
                .bg = bg,
                .attrs = Attributes{},
            };
        }
    };
    
    /// Text attributes
    pub const Attributes = packed struct {
        bold: bool = false,
        dim: bool = false,
        italic: bool = false,
        underline: bool = false,
        blink: bool = false,
        reverse: bool = false,
        hidden: bool = false,
        strikethrough: bool = false,
        
        /// Check if any attributes are set
        pub fn is_empty(self: Attributes) bool {
            return !self.bold and !self.dim and !self.italic and 
                   !self.underline and !self.blink and !self.reverse and 
                   !self.hidden and !self.strikethrough;
        }
    };
    
    /// Screen cell
    pub const Cell = struct {
        char: u21,  // Unicode codepoint
        style: Style,
        
        /// Create empty cell
        pub fn empty() Cell {
            return Cell{
                .char = ' ',
                .style = Style.default(),
            };
        }
        
        /// Create cell with character
        pub fn with_char(char: u21) Cell {
            return Cell{
                .char = char,
                .style = Style.default(),
            };
        }
        
        /// Create styled cell
        pub fn styled(char: u21, style: Style) Cell {
            return Cell{
                .char = char,
                .style = style,
            };
        }
        
        /// Check if two cells are equal
        pub fn equals(a: Cell, b: Cell) bool {
            return a.char == b.char and 
                   styles_equal(a.style, b.style);
        }
        
        fn styles_equal(a: Style, b: Style) bool {
            return colors_equal(a.fg, b.fg) and 
                   colors_equal(a.bg, b.bg) and
                   @as(u8, @bitCast(a.attrs)) == @as(u8, @bitCast(b.attrs));
        }
        
        fn colors_equal(a: Color, b: Color) bool {
            return switch (a) {
                .default => b == .default,
                .indexed => |val_a| switch (b) {
                    .indexed => |val_b| val_a == val_b,
                    else => false,
                },
                .rgb => |rgb_a| switch (b) {
                    .rgb => |rgb_b| rgb_a.r == rgb_b.r and 
                                     rgb_a.g == rgb_b.g and 
                                     rgb_a.b == rgb_b.b,
                    else => false,
                },
            };
        }
    };
    
    /// Cell buffer for efficient bulk operations
    pub const CellBuffer = struct {
        cells: []Cell,
        width: u16,
        height: u16,
        allocator: std.mem.Allocator,
        
        /// Initialize cell buffer
        pub fn init(allocator: std.mem.Allocator, width: u16, height: u16) !CellBuffer {
            const size = @as(usize, width) * @as(usize, height);
            const cells = try allocator.alloc(Cell, size);
            
            // Initialize with empty cells
            for (cells) |*cell| {
                cell.* = Cell.empty();
            }
            
            return CellBuffer{
                .cells = cells,
                .width = width,
                .height = height,
                .allocator = allocator,
            };
        }
        
        /// Deinitialize cell buffer
        pub fn deinit(self: *CellBuffer) void {
            self.allocator.free(self.cells);
        }
        
        /// Get cell at position
        pub fn get(self: *CellBuffer, x: u16, y: u16) ?*Cell {
            if (x >= self.width or y >= self.height) return null;
            
            const index = @as(usize, y) * @as(usize, self.width) + @as(usize, x);
            return &self.cells[index];
        }
        
        /// Set cell at position
        pub fn set(self: *CellBuffer, x: u16, y: u16, cell: Cell) void {
            if (x >= self.width or y >= self.height) return;
            
            const index = @as(usize, y) * @as(usize, self.width) + @as(usize, x);
            self.cells[index] = cell;
        }
        
        /// Clear buffer
        pub fn clear(self: *CellBuffer) void {
            for (self.cells) |*cell| {
                cell.* = Cell.empty();
            }
        }
    };

// ╚══════════╝