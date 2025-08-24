// cell.test.zig — Comprehensive tests for cell representation
//
// repo   : https://github.com/fisty/zig-tui
// author : https://github.com/fisty
//
// Tests for terminal cell structure and operations.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Cell = @import("cell.zig").Cell;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test constants
    const DEFAULT_CHAR: u32 = ' ';
    const MAX_UNICODE: u32 = 0x10FFFF;
    
    // Color definitions
    const Color = enum(u8) {
        black = 0,
        red = 1,
        green = 2,
        yellow = 3,
        blue = 4,
        magenta = 5,
        cyan = 6,
        white = 7,
        default = 9,
        
        bright_black = 8,
        bright_red = 9,
        bright_green = 10,
        bright_yellow = 11,
        bright_blue = 12,
        bright_magenta = 13,
        bright_cyan = 14,
        bright_white = 15,
    };
    
    // Style flags
    const Style = packed struct {
        bold: bool = false,
        dim: bool = false,
        italic: bool = false,
        underline: bool = false,
        blink: bool = false,
        reverse: bool = false,
        hidden: bool = false,
        strikethrough: bool = false,
    };
    
    // Test helpers
    fn createDefaultCell() Cell {
        return Cell{
            .char = DEFAULT_CHAR,
            .fg = .default,
            .bg = .default,
            .style = .{},
        };
    }
    
    fn createStyledCell(char: u32, fg: Color, bg: Color, style: Style) Cell {
        return Cell{
            .char = char,
            .fg = fg,
            .bg = bg,
            .style = style,
        };
    }
    
    fn createUnicodeCell(codepoint: u32) Cell {
        return Cell{
            .char = codepoint,
            .fg = .default,
            .bg = .default,
            .style = .{},
        };
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐
    
        test "unit: Cell: initializes with default values" {
            const cell = createDefaultCell();
            
            try testing.expectEqual(DEFAULT_CHAR, cell.char);
            try testing.expectEqual(Color.default, cell.fg);
            try testing.expectEqual(Color.default, cell.bg);
            try testing.expect(!cell.style.bold);
            try testing.expect(!cell.style.italic);
            try testing.expect(!cell.style.underline);
        }
        
        test "unit: Cell: stores ASCII characters correctly" {
            const cell = Cell{
                .char = 'A',
                .fg = .white,
                .bg = .black,
                .style = .{},
            };
            
            try testing.expectEqual(@as(u32, 'A'), cell.char);
            try testing.expect(cell.isAscii());
        }
        
        test "unit: Cell: stores Unicode characters correctly" {
            // Test various Unicode characters
            const test_chars = [_]u32{
                '😀', // Emoji
                '中', // Chinese
                '∑', // Math symbol
                '€', // Currency
                'Ω', // Greek
            };
            
            for (test_chars) |char| {
                const cell = createUnicodeCell(char);
                try testing.expectEqual(char, cell.char);
                try testing.expect(!cell.isAscii());
            }
        }
        
        test "unit: Cell: applies colors correctly" {
            const cell = Cell{
                .char = 'C',
                .fg = .red,
                .bg = .blue,
                .style = .{},
            };
            
            try testing.expectEqual(Color.red, cell.fg);
            try testing.expectEqual(Color.blue, cell.bg);
        }
        
        test "unit: Cell: applies styles correctly" {
            const cell = Cell{
                .char = 'S',
                .fg = .white,
                .bg = .black,
                .style = .{
                    .bold = true,
                    .italic = true,
                    .underline = true,
                },
            };
            
            try testing.expect(cell.style.bold);
            try testing.expect(cell.style.italic);
            try testing.expect(cell.style.underline);
            try testing.expect(!cell.style.blink);
        }
        
        test "unit: Cell: compares cells for equality" {
            const cell1 = createStyledCell('X', .red, .blue, .{ .bold = true });
            const cell2 = createStyledCell('X', .red, .blue, .{ .bold = true });
            const cell3 = createStyledCell('Y', .red, .blue, .{ .bold = true });
            
            try testing.expect(cell1.equals(cell2));
            try testing.expect(!cell1.equals(cell3));
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: Cell with RGB colors: stores 24-bit color" {
            const cell = Cell{
                .char = 'R',
                .fg = .{ .rgb = .{ .r = 255, .g = 128, .b = 0 } },
                .bg = .{ .rgb = .{ .r = 0, .g = 128, .b = 255 } },
                .style = .{},
            };
            
            try testing.expectEqual(@as(u8, 255), cell.fg.rgb.r);
            try testing.expectEqual(@as(u8, 128), cell.fg.rgb.g);
            try testing.expectEqual(@as(u8, 0), cell.fg.rgb.b);
            
            try testing.expectEqual(@as(u8, 0), cell.bg.rgb.r);
            try testing.expectEqual(@as(u8, 128), cell.bg.rgb.g);
            try testing.expectEqual(@as(u8, 255), cell.bg.rgb.b);
        }
        
        test "integration: Cell merging: combines cells correctly" {
            const base = Cell{
                .char = 'B',
                .fg = .white,
                .bg = .black,
                .style = .{ .bold = true },
            };
            
            const overlay = Cell{
                .char = 'O',
                .fg = .red,
                .bg = .default,
                .style = .{ .italic = true },
            };
            
            const merged = base.merge(overlay);
            
            // Overlay char takes precedence
            try testing.expectEqual(@as(u32, 'O'), merged.char);
            
            // Non-default colors from overlay
            try testing.expectEqual(Color.red, merged.fg);
            
            // Default bg in overlay, use base
            try testing.expectEqual(Color.black, merged.bg);
            
            // Styles are combined
            try testing.expect(merged.style.bold);
            try testing.expect(merged.style.italic);
        }
        
        test "integration: Cell diffing: detects changes" {
            const old_cell = createStyledCell('A', .white, .black, .{});
            const new_cell = createStyledCell('B', .red, .black, .{ .bold = true });
            
            const diff = old_cell.diff(new_cell);
            
            try testing.expect(diff.char_changed);
            try testing.expect(diff.fg_changed);
            try testing.expect(!diff.bg_changed);
            try testing.expect(diff.style_changed);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── E2E Tests ────────────────────────────┐
    
        test "e2e: cell rendering pipeline: creation to display" {
            const allocator = testing.allocator;
            
            // Create a line of cells
            var line = try allocator.alloc(Cell, 10);
            defer allocator.free(line);
            
            // Fill with gradient
            for (line, 0..) |*cell, i| {
                cell.* = Cell{
                    .char = @intCast('0' + (i % 10)),
                    .fg = @enumFromInt(@as(u8, @intCast(i % 16))),
                    .bg = .black,
                    .style = .{
                        .bold = i % 2 == 0,
                        .italic = i % 3 == 0,
                    },
                };
            }
            
            // Render to buffer
            var buffer = std.ArrayList(u8).init(allocator);
            defer buffer.deinit();
            
            for (line) |cell| {
                try cell.render(&buffer);
            }
            
            // Should have rendered content
            try testing.expect(buffer.items.len > 0);
        }
        
        test "e2e: cell animation: tracks cell state changes" {
            var cell = createDefaultCell();
            
            // Animation frames
            const frames = [_]struct { char: u32, fg: Color }{
                .{ .char = '|', .fg = .white },
                .{ .char = '/', .fg = .yellow },
                .{ .char = '-', .fg = .cyan },
                .{ .char = '\\', .fg = .blue },
            };
            
            // Track changes
            var total_changes: u32 = 0;
            
            for (frames) |frame| {
                const old_cell = cell;
                cell.char = frame.char;
                cell.fg = frame.fg;
                
                const diff = old_cell.diff(cell);
                if (diff.hasChanges()) {
                    total_changes += 1;
                }
            }
            
            // Should detect all frame changes
            try testing.expectEqual(@as(u32, frames.len), total_changes);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: Cell operations: handles many cells efficiently" {
            const allocator = testing.allocator;
            
            const cell_count = 100000;
            var cells = try allocator.alloc(Cell, cell_count);
            defer allocator.free(cells);
            
            const start = std.time.milliTimestamp();
            
            // Initialize all cells
            for (cells, 0..) |*cell, i| {
                cell.* = Cell{
                    .char = @intCast((i % 94) + 33), // Printable ASCII
                    .fg = @enumFromInt(@as(u8, @intCast(i % 16))),
                    .bg = @enumFromInt(@as(u8, @intCast((i / 16) % 16))),
                    .style = .{
                        .bold = i % 2 == 0,
                        .italic = i % 3 == 0,
                        .underline = i % 5 == 0,
                    },
                };
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should initialize 100k cells quickly
            try testing.expect(elapsed < 100);
        }
        
        test "performance: Cell.equals: compares cells quickly" {
            const cell1 = createStyledCell('P', .white, .black, .{ .bold = true });
            const cell2 = createStyledCell('P', .white, .black, .{ .bold = true });
            const cell3 = createStyledCell('Q', .red, .blue, .{ .italic = true });
            
            const iterations = 1000000;
            var equal_count: u32 = 0;
            
            const start = std.time.milliTimestamp();
            
            for (0..iterations) |i| {
                const is_equal = if (i % 2 == 0)
                    cell1.equals(cell2)
                else
                    cell1.equals(cell3);
                
                if (is_equal) {
                    equal_count += 1;
                }
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should compare 1M cells quickly
            try testing.expect(elapsed < 100);
            try testing.expectEqual(@as(u32, iterations / 2), equal_count);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Stress Tests ────────────────────────────┐
    
        test "stress: Cell: handles all Unicode ranges" {
            // Test various Unicode blocks
            const test_ranges = [_][2]u32{
                [_]u32{ 0x0000, 0x007F }, // Basic Latin
                [_]u32{ 0x0080, 0x00FF }, // Latin-1 Supplement
                [_]u32{ 0x0100, 0x017F }, // Latin Extended-A
                [_]u32{ 0x0400, 0x04FF }, // Cyrillic
                [_]u32{ 0x1F600, 0x1F64F }, // Emoticons
            };
            
            for (test_ranges) |range| {
                const start = range[0];
                const end = @min(range[1], start + 100); // Test subset
                
                for (start..end) |codepoint| {
                    const cell = createUnicodeCell(@intCast(codepoint));
                    try testing.expectEqual(@as(u32, @intCast(codepoint)), cell.char);
                    
                    // Verify it's valid Unicode
                    try testing.expect(cell.char <= MAX_UNICODE);
                }
            }
        }
        
        test "stress: Cell: handles all color and style combinations" {
            const allocator = testing.allocator;
            
            // Test all combinations
            var cells = std.ArrayList(Cell).init(allocator);
            defer cells.deinit();
            
            // All foreground colors
            for (0..16) |fg| {
                // All background colors
                for (0..16) |bg| {
                    // All style combinations (8 boolean flags = 256 combinations)
                    for (0..256) |style_bits| {
                        const cell = Cell{
                            .char = 'T',
                            .fg = @enumFromInt(@as(u8, @intCast(fg))),
                            .bg = @enumFromInt(@as(u8, @intCast(bg))),
                            .style = .{
                                .bold = (style_bits & 0x01) != 0,
                                .dim = (style_bits & 0x02) != 0,
                                .italic = (style_bits & 0x04) != 0,
                                .underline = (style_bits & 0x08) != 0,
                                .blink = (style_bits & 0x10) != 0,
                                .reverse = (style_bits & 0x20) != 0,
                                .hidden = (style_bits & 0x40) != 0,
                                .strikethrough = (style_bits & 0x80) != 0,
                            },
                        };
                        
                        try cells.append(cell);
                        
                        // Limit total cells for memory
                        if (cells.items.len >= 1000) {
                            break;
                        }
                    }
                    if (cells.items.len >= 1000) break;
                }
                if (cells.items.len >= 1000) break;
            }
            
            // Verify all cells are valid
            for (cells.items) |cell| {
                try testing.expect(cell.char <= MAX_UNICODE);
            }
        }
    
    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝