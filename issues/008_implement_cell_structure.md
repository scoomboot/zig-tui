# Issue #008: Implement cell structure

## Summary
Create the Cell structure that represents a single character with styling attributes in the screen buffer.

## Description
Implement a memory-efficient Cell structure that can store a character along with its foreground color, background color, and style attributes. The cell should support Unicode characters and be optimized for fast comparison and copying.

## Acceptance Criteria
- [ ] Create `lib/screen/utils/cell/cell.zig`
- [ ] Implement Cell struct with:
  - [ ] Character storage (Unicode support)
  - [ ] Foreground color
  - [ ] Background color
  - [ ] Style attributes (bold, italic, etc.)
- [ ] Add cell comparison methods
- [ ] Add cell merging/overlay methods
- [ ] Implement default/empty cell concept
- [ ] Optimize memory layout for cache efficiency
- [ ] Add cell clustering for wide characters
- [ ] Create comprehensive tests
- [ ] Follow MCS style guidelines

## Dependencies
- Issue #003 (Create main entry point)

## Implementation Notes
```zig
// cell.zig — Screen buffer cell representation
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const unicode = std.unicode;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    /// Color representation with efficient packing
    pub const Color = packed struct {
        type: ColorType,
        value: u8,
        
        pub const ColorType = enum(u2) {
            default = 0,
            basic = 1,      // 8 colors
            indexed = 2,    // 256 colors
            rgb = 3,        // True color (stored separately)
        };
        
        pub const default = Color{ .type = .default, .value = 0 };
        pub const black = Color{ .type = .basic, .value = 0 };
        pub const red = Color{ .type = .basic, .value = 1 };
        pub const green = Color{ .type = .basic, .value = 2 };
        pub const yellow = Color{ .type = .basic, .value = 3 };
        pub const blue = Color{ .type = .basic, .value = 4 };
        pub const magenta = Color{ .type = .basic, .value = 5 };
        pub const cyan = Color{ .type = .basic, .value = 6 };
        pub const white = Color{ .type = .basic, .value = 7 };
        
        pub fn rgb(r: u8, g: u8, b: u8) Color {
            // Pack RGB into indexed color space for now
            // Full RGB support requires separate storage
            const index = rgbToIndex256(r, g, b);
            return Color{ .type = .indexed, .value = index };
        }
    };

    /// Style attributes packed into a single byte
    pub const Style = packed struct {
        bold: bool = false,
        dim: bool = false,
        italic: bool = false,
        underline: bool = false,
        blink: bool = false,
        reverse: bool = false,
        hidden: bool = false,
        strikethrough: bool = false,
        
        pub const none = Style{};
        pub const bold_only = Style{ .bold = true };
        pub const underline_only = Style{ .underline = true };
    };

    /// Character content with Unicode support
    pub const CharContent = union(enum) {
        empty: void,
        ascii: u8,
        utf8: [4]u8,  // UTF-8 encoded, null-terminated
        wide: u32,     // Wide character (emoji, CJK)
        
        pub fn fromChar(ch: u21) CharContent {
            if (ch == 0 or ch == ' ') {
                return .{ .empty = {} };
            } else if (ch < 128) {
                return .{ .ascii = @intCast(u8, ch) };
            } else {
                var buf: [4]u8 = [_]u8{0} ** 4;
                const len = unicode.utf8Encode(ch, &buf) catch return .{ .empty = {} };
                _ = len;
                return .{ .utf8 = buf };
            }
        }
        
        pub fn width(self: CharContent) u8 {
            return switch (self) {
                .empty => 0,
                .ascii => 1,
                .utf8 => |bytes| unicodeWidth(bytes),
                .wide => 2,
            };
        }
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Cell represents a single position in the terminal buffer
    pub const Cell = struct {
        content: CharContent,
        fg: Color,
        bg: Color,
        style: Style,
        
        // ┌──────────────────────────── Constructors ────────────────────────────┐

            /// Create an empty cell with default attributes
            pub fn empty() Cell {
                return Cell{
                    .content = .{ .empty = {} },
                    .fg = Color.default,
                    .bg = Color.default,
                    .style = Style.none,
                };
            }

            /// Create a cell with a character and optional styling
            pub fn init(ch: u21, fg: ?Color, bg: ?Color, style: ?Style) Cell {
                return Cell{
                    .content = CharContent.fromChar(ch),
                    .fg = fg orelse Color.default,
                    .bg = bg orelse Color.default,
                    .style = style orelse Style.none,
                };
            }

            /// Create a cell from a string slice (first character only)
            pub fn fromStr(str: []const u8, fg: ?Color, bg: ?Color, style: ?Style) Cell {
                if (str.len == 0) return empty();
                
                const ch = unicode.utf8Decode(str) catch return empty();
                return init(ch, fg, bg, style);
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Comparison ────────────────────────────┐

            /// Check if two cells are visually identical
            pub fn equals(self: Cell, other: Cell) bool {
                return self.visuallyEquals(other) and self.style == other.style;
            }

            /// Check if cells have the same visible content (ignoring hidden style)
            pub fn visuallyEquals(self: Cell, other: Cell) bool {
                if (!self.contentEquals(other)) return false;
                if (self.fg.type != other.fg.type or self.fg.value != other.fg.value) return false;
                if (self.bg.type != other.bg.type or self.bg.value != other.bg.value) return false;
                
                // Compare visible styles only
                const self_visible = self.style and ~Style{ .hidden = true };
                const other_visible = other.style and ~Style{ .hidden = true };
                
                return self_visible == other_visible;
            }

            /// Check if cells have the same character content
            pub fn contentEquals(self: Cell, other: Cell) bool {
                return switch (self.content) {
                    .empty => other.content == .empty,
                    .ascii => |ch| switch (other.content) {
                        .ascii => |other_ch| ch == other_ch,
                        else => false,
                    },
                    .utf8 => |bytes| switch (other.content) {
                        .utf8 => |other_bytes| std.mem.eql(u8, &bytes, &other_bytes),
                        else => false,
                    },
                    .wide => |ch| switch (other.content) {
                        .wide => |other_ch| ch == other_ch,
                        else => false,
                    },
                };
            }

            /// Check if cell is empty (no visible content)
            pub fn isEmpty(self: Cell) bool {
                return self.content == .empty or 
                       (self.style.hidden and self.bg == Color.default);
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Operations ────────────────────────────┐

            /// Merge another cell on top of this one (overlay)
            pub fn merge(self: *Cell, other: Cell) void {
                if (other.content != .empty) {
                    self.content = other.content;
                }
                if (other.fg.type != .default) {
                    self.fg = other.fg;
                }
                if (other.bg.type != .default) {
                    self.bg = other.bg;
                }
                // Merge styles (OR operation)
                self.style = @bitCast(Style, @bitCast(u8, self.style) | @bitCast(u8, other.style));
            }

            /// Reset cell to empty state
            pub fn reset(self: *Cell) void {
                self.* = empty();
            }

            /// Get the display width of the cell (0, 1, or 2)
            pub fn width(self: Cell) u8 {
                return self.content.width();
            }

        // └──────────────────────────────────────────────────────────────────┘

    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ UTIL ══════════════════════════════════════╗

    // ┌──────────────────────────── Helper Functions ────────────────────────────┐

        /// Convert RGB to 256-color palette index
        fn rgbToIndex256(r: u8, g: u8, b: u8) u8 {
            // Simplified conversion - proper implementation would use color distance
            if (r == g and g == b) {
                // Grayscale
                if (r < 8) return 16;
                if (r > 248) return 231;
                return @intCast(u8, 232 + ((r - 8) / 10));
            } else {
                // 6x6x6 color cube
                const ri = r * 5 / 255;
                const gi = g * 5 / 255;
                const bi = b * 5 / 255;
                return @intCast(u8, 16 + ri * 36 + gi * 6 + bi);
            }
        }

        /// Get display width of Unicode character
        fn unicodeWidth(utf8_bytes: [4]u8) u8 {
            // Simplified - would need proper Unicode width tables
            const ch = unicode.utf8Decode(utf8_bytes[0..]) catch return 1;
            
            // Check for zero-width characters
            if (ch >= 0x0300 and ch <= 0x036F) return 0; // Combining marks
            
            // Check for wide characters (CJK, emoji)
            if ((ch >= 0x1100 and ch <= 0x115F) or  // Hangul
                (ch >= 0x2E80 and ch <= 0x9FFF) or  // CJK
                (ch >= 0xF900 and ch <= 0xFAFF) or  // CJK Compatibility
                (ch >= 0xFE30 and ch <= 0xFE4F) or  // CJK Compatibility Forms
                (ch >= 0x1F300 and ch <= 0x1F9FF))  // Emoji
            {
                return 2;
            }
            
            return 1;
        }

    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Test ASCII character storage
- Test Unicode character handling
- Test wide character support
- Test color representations
- Test style attributes
- Test cell comparison methods
- Test merge operations
- Memory usage: < 8 bytes per cell for common cases
- Performance: < 1ns for cell comparison

## Estimated Time
2 hours

## Priority
🟡 High - Required for screen buffer

## Category
Screen Management