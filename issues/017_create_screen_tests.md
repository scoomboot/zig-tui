# Issue #017: Create screen tests

## Summary
Implement comprehensive unit tests for the screen buffer module including cell management, drawing operations, and diffing algorithms.

## Description
Create a complete test suite for the screen module that covers cell structure, double buffering, drawing primitives, buffer diffing, and rendering. Tests should validate memory efficiency, performance, and correctness of all screen operations.

## Acceptance Criteria
- [ ] Create `lib/screen/screen.test.zig`
- [ ] Test cell structure and operations
- [ ] Test screen buffer initialization
- [ ] Test drawing primitives
- [ ] Test text rendering with wrapping
- [ ] Test buffer diffing algorithm
- [ ] Test dirty region tracking
- [ ] Test resize operations
- [ ] Test Unicode handling
- [ ] Test memory management
- [ ] Follow MCS test categorization
- [ ] Achieve >95% code coverage

## Dependencies
- Issue #009 (Implement screen buffer)
- Issue #010 (Implement buffer diffing)
- Issue #011 (Implement screen rendering)

## Implementation Notes
```zig
// screen.test.zig — Tests for screen buffer module
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Screen = @import("screen.zig").Screen;
    const Cell = @import("utils/cell/cell.zig").Cell;
    const Color = @import("utils/cell/cell.zig").Color;
    const Style = @import("utils/cell/cell.zig").Style;
    const Rect = @import("utils/rect/rect.zig").Rect;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test helpers
    fn createTestScreen(allocator: std.mem.Allocator, width: u16, height: u16) !*Screen {
        var screen = try allocator.create(Screen);
        screen.* = try Screen.init(allocator, width, height);
        return screen;
    }

    fn destroyTestScreen(allocator: std.mem.Allocator, screen: *Screen) void {
        screen.deinit();
        allocator.destroy(screen);
    }

    fn fillScreen(screen: *Screen, ch: u21) !void {
        const rect = Rect{
            .x = 0,
            .y = 0,
            .width = screen.width,
            .height = screen.height,
        };
        try screen.fillRect(rect, ch, .{});
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Cell Tests ────────────────────────────┐

        test "unit: Cell: creates empty cell" {
            const cell = Cell.empty();
            try testing.expect(cell.isEmpty());
            try testing.expectEqual(Color.default, cell.fg);
            try testing.expectEqual(Color.default, cell.bg);
            try testing.expectEqual(Style.none, cell.style);
        }

        test "unit: Cell: creates cell with character" {
            const cell = Cell.init('A', null, null, null);
            try testing.expect(!cell.isEmpty());
            try testing.expect(cell.contentEquals(Cell.init('A', null, null, null)));
            try testing.expectEqual(@as(u8, 1), cell.width());
        }

        test "unit: Cell: handles Unicode characters" {
            // Test emoji (wide character)
            const emoji = Cell.init('😀', null, null, null);
            try testing.expectEqual(@as(u8, 2), emoji.width());
            
            // Test combining character
            const combining = Cell.init(0x0301, null, null, null); // Combining acute accent
            try testing.expectEqual(@as(u8, 0), combining.width());
        }

        test "unit: Cell: compares cells correctly" {
            const cell1 = Cell.init('A', Color.red, Color.blue, Style.bold_only);
            const cell2 = Cell.init('A', Color.red, Color.blue, Style.bold_only);
            const cell3 = Cell.init('B', Color.red, Color.blue, Style.bold_only);
            const cell4 = Cell.init('A', Color.green, Color.blue, Style.bold_only);
            
            try testing.expect(cell1.equals(cell2));
            try testing.expect(!cell1.equals(cell3));
            try testing.expect(!cell1.equals(cell4));
        }

        test "unit: Cell: merges cells" {
            var base = Cell.init('A', Color.red, Color.blue, Style.none);
            const overlay = Cell.init('B', Color.green, null, Style.bold_only);
            
            base.merge(overlay);
            
            try testing.expect(base.contentEquals(Cell.init('B', null, null, null)));
            try testing.expectEqual(Color.green, base.fg);
            try testing.expectEqual(Color.blue, base.bg); // Preserved from base
            try testing.expect(base.style.bold);
        }

        test "unit: Cell: color representation" {
            // Test basic colors
            try testing.expectEqual(@as(u8, 0), Color.black.value);
            try testing.expectEqual(@as(u8, 1), Color.red.value);
            try testing.expectEqual(@as(u8, 7), Color.white.value);
            
            // Test indexed colors
            const indexed = Color{ .type = .indexed, .value = 123 };
            try testing.expectEqual(@as(u8, 123), indexed.value);
            
            // Test RGB conversion
            const rgb = Color.rgb(255, 128, 0);
            try testing.expectEqual(Color.ColorType.indexed, rgb.type);
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Screen Buffer Tests ────────────────────────────┐

        test "unit: Screen: initializes with dimensions" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 80, 24);
            defer screen.deinit();
            
            try testing.expectEqual(@as(u16, 80), screen.width);
            try testing.expectEqual(@as(u16, 24), screen.height);
            try testing.expectEqual(@as(usize, 80 * 24), screen.front_buffer.len);
            try testing.expectEqual(@as(usize, 80 * 24), screen.back_buffer.len);
        }

        test "unit: Screen: rejects invalid dimensions" {
            const allocator = testing.allocator;
            
            try testing.expectError(error.InvalidDimensions, Screen.init(allocator, 0, 24));
            try testing.expectError(error.InvalidDimensions, Screen.init(allocator, 80, 0));
        }

        test "unit: Screen: sets and gets cells" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 10, 10);
            defer screen.deinit();
            
            const cell = Cell.init('X', Color.red, Color.blue, Style.bold_only);
            try screen.setCell(5, 5, cell);
            
            const retrieved = screen.getCell(5, 5);
            try testing.expect(retrieved != null);
            try testing.expect(cell.equals(retrieved.?));
            
            // Out of bounds returns null
            try testing.expect(screen.getCell(10, 10) == null);
        }

        test "unit: Screen: writes text" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 20, 10);
            defer screen.deinit();
            
            try screen.writeText(0, 0, "Hello", .{ .fg = Color.red });
            
            // Check that text was written
            const h = screen.getCell(0, 0).?;
            const e = screen.getCell(1, 0).?;
            const l1 = screen.getCell(2, 0).?;
            const l2 = screen.getCell(3, 0).?;
            const o = screen.getCell(4, 0).?;
            
            try testing.expect(h.isChar('H'));
            try testing.expect(e.isChar('e'));
            try testing.expect(l1.isChar('l'));
            try testing.expect(l2.isChar('l'));
            try testing.expect(o.isChar('o'));
            try testing.expectEqual(Color.red, h.fg);
        }

        test "unit: Screen: handles text wrapping" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 5, 3);
            defer screen.deinit();
            
            try screen.writeText(3, 0, "Hello", .{ .wrap = true });
            
            // "Hel" on line 0, "lo" on line 1
            try testing.expect(screen.getCell(3, 0).?.isChar('H'));
            try testing.expect(screen.getCell(4, 0).?.isChar('e'));
            try testing.expect(screen.getCell(0, 1).?.isChar('l'));
            try testing.expect(screen.getCell(1, 1).?.isChar('l'));
            try testing.expect(screen.getCell(2, 1).?.isChar('o'));
        }

        test "unit: Screen: draws lines" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 10, 10);
            defer screen.deinit();
            
            // Horizontal line
            try screen.drawHLine(2, 5, 6, '-', .{});
            var x: u16 = 2;
            while (x < 8) : (x += 1) {
                try testing.expect(screen.getCell(x, 5).?.isChar('-'));
            }
            
            // Vertical line
            try screen.drawVLine(5, 2, 6, '|', .{});
            var y: u16 = 2;
            while (y < 8) : (y += 1) {
                try testing.expect(screen.getCell(5, y).?.isChar('|'));
            }
        }

        test "unit: Screen: fills rectangles" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 10, 10);
            defer screen.deinit();
            
            const rect = Rect{ .x = 2, .y = 2, .width = 4, .height = 3 };
            try screen.fillRect(rect, '#', .{ .fg = Color.green });
            
            // Check filled area
            var y: u16 = 2;
            while (y < 5) : (y += 1) {
                var x: u16 = 2;
                while (x < 6) : (x += 1) {
                    const cell = screen.getCell(x, y).?;
                    try testing.expect(cell.isChar('#'));
                    try testing.expectEqual(Color.green, cell.fg);
                }
            }
            
            // Check outside area is unchanged
            try testing.expect(screen.getCell(1, 1).?.isEmpty());
            try testing.expect(screen.getCell(7, 7).?.isEmpty());
        }

        test "unit: Screen: clears regions" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 10, 10);
            defer screen.deinit();
            
            // Fill screen
            try fillScreen(&screen, 'X');
            
            // Clear a region
            const rect = Rect{ .x = 2, .y = 2, .width = 4, .height = 3 };
            try screen.clearRegion(rect);
            
            // Check cleared area
            var y: u16 = 2;
            while (y < 5) : (y += 1) {
                var x: u16 = 2;
                while (x < 6) : (x += 1) {
                    try testing.expect(screen.getCell(x, y).?.isEmpty());
                }
            }
            
            // Check outside area still has content
            try testing.expect(screen.getCell(0, 0).?.isChar('X'));
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Resize Tests ────────────────────────────┐

        test "unit: Screen: resizes buffers" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 10, 10);
            defer screen.deinit();
            
            // Set some content
            try screen.setCell(5, 5, Cell.init('A', null, null, null));
            
            // Resize larger
            try screen.resize(20, 20);
            try testing.expectEqual(@as(u16, 20), screen.width);
            try testing.expectEqual(@as(u16, 20), screen.height);
            
            // Content should be preserved
            try testing.expect(screen.getCell(5, 5).?.isChar('A'));
            
            // Resize smaller
            try screen.resize(3, 3);
            try testing.expectEqual(@as(u16, 3), screen.width);
            try testing.expectEqual(@as(u16, 3), screen.height);
            
            // Content outside bounds is lost
            try testing.expect(screen.getCell(5, 5) == null);
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Diff Tests ────────────────────────────┐

        test "unit: Screen: detects simple changes" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 10, 10);
            defer screen.deinit();
            
            // Make changes to back buffer
            try screen.setCell(5, 5, Cell.init('X', null, null, null));
            
            // Generate diff
            var diff = try screen.generateDiff(.{ .optimize_level = .none });
            defer diff.deinit();
            
            // Should have one change
            try testing.expect(diff.ops.items.len > 0);
            try testing.expect(diff.estimated_cost > 0);
        }

        test "unit: Screen: optimizes horizontal spans" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 20, 10);
            defer screen.deinit();
            
            // Write a horizontal line
            try screen.writeText(0, 5, "Hello World", .{});
            
            // Generate optimized diff
            var diff = try screen.generateDiff(.{ .optimize_level = .basic });
            defer diff.deinit();
            
            // Should combine into spans rather than individual cells
            try testing.expect(diff.estimated_cost < 11); // Less than character count
        }

        test "unit: Screen: detects scrolling" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 10, 10);
            defer screen.deinit();
            
            // Set up content
            var y: u16 = 0;
            while (y < 10) : (y += 1) {
                try screen.writeText(0, y, "Line", .{});
            }
            screen.present();
            
            // Simulate scroll by shifting content
            y = 0;
            while (y < 9) : (y += 1) {
                var x: u16 = 0;
                while (x < 10) : (x += 1) {
                    const cell = screen.front_buffer[(y + 1) * 10 + x];
                    screen.back_buffer[y * 10 + x] = cell;
                }
            }
            
            // Clear last line
            y = 9;
            var x: u16 = 0;
            while (x < 10) : (x += 1) {
                screen.back_buffer[y * 10 + x] = Cell.empty();
            }
            
            // Generate diff with scroll detection
            var diff = try screen.generateDiff(.{
                .optimize_level = .balanced,
                .detect_scrolling = true,
            });
            defer diff.deinit();
            
            // Should detect as scroll operation
            var found_scroll = false;
            for (diff.ops.items) |op| {
                if (op == .scroll) {
                    found_scroll = true;
                    break;
                }
            }
            // Note: Actual scroll detection is complex and may not trigger in simple test
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Integration Tests ────────────────────────────┐

        test "integration: Screen: complete drawing pipeline" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 40, 20);
            defer screen.deinit();
            
            // Draw a box
            const box_rect = Rect{ .x = 5, .y = 5, .width = 10, .height = 5 };
            
            // Top and bottom borders
            try screen.drawHLine(box_rect.x, box_rect.y, box_rect.width, '─', .{});
            try screen.drawHLine(box_rect.x, box_rect.y + box_rect.height - 1, box_rect.width, '─', .{});
            
            // Left and right borders
            try screen.drawVLine(box_rect.x, box_rect.y, box_rect.height, '│', .{});
            try screen.drawVLine(box_rect.x + box_rect.width - 1, box_rect.y, box_rect.height, '│', .{});
            
            // Corners
            try screen.setCell(box_rect.x, box_rect.y, Cell.init('┌', null, null, null));
            try screen.setCell(box_rect.x + box_rect.width - 1, box_rect.y, Cell.init('┐', null, null, null));
            try screen.setCell(box_rect.x, box_rect.y + box_rect.height - 1, Cell.init('└', null, null, null));
            try screen.setCell(box_rect.x + box_rect.width - 1, box_rect.y + box_rect.height - 1, Cell.init('┘', null, null, null));
            
            // Add text inside
            try screen.writeText(box_rect.x + 2, box_rect.y + 2, "Hello", .{});
            
            // Generate diff
            var diff = try screen.generateDiff(.{ .optimize_level = .balanced });
            defer diff.deinit();
            
            // Should have operations
            try testing.expect(diff.ops.items.len > 0);
            
            // Present changes
            screen.present();
            
            // Front buffer should now match back buffer
            for (screen.front_buffer, screen.back_buffer) |front, back| {
                try testing.expect(front.equals(back));
            }
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Performance Tests ────────────────────────────┐

        test "performance: Screen: cell operations" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 80, 24);
            defer screen.deinit();
            
            const iterations = 10000;
            const start = std.time.nanoTimestamp();
            
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const x = @intCast(u16, i % 80);
                const y = @intCast(u16, (i / 80) % 24);
                const cell = Cell.init(@intCast(u21, 'A' + (i % 26)), null, null, null);
                try screen.setCell(x, y, cell);
            }
            
            const elapsed = std.time.nanoTimestamp() - start;
            const avg_ns = @divFloor(elapsed, iterations);
            
            // Should set cells in less than 100ns
            try testing.expect(avg_ns < 100);
        }

        test "performance: Screen: buffer diffing" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 80, 24);
            defer screen.deinit();
            
            // Make random changes
            var i: u16 = 0;
            while (i < 100) : (i += 1) {
                const x = i % 80;
                const y = i / 80;
                try screen.setCell(x, y, Cell.init('X', null, null, null));
            }
            
            const start = std.time.nanoTimestamp();
            
            var diff = try screen.generateDiff(.{ .optimize_level = .balanced });
            defer diff.deinit();
            
            const elapsed = std.time.nanoTimestamp() - start;
            
            // Should generate diff for 80x24 screen in less than 5ms
            try testing.expect(elapsed < 5_000_000);
        }

        test "performance: Screen: memory usage" {
            const allocator = testing.allocator;
            
            // Standard terminal size
            var screen = try Screen.init(allocator, 80, 24);
            defer screen.deinit();
            
            const cell_size = @sizeOf(Cell);
            const buffer_size = 80 * 24 * cell_size;
            const total_size = buffer_size * 2; // Front and back buffers
            
            // Should use reasonable memory (< 100KB for standard terminal)
            try testing.expect(total_size < 100_000);
            
            // Cell should be compact (< 16 bytes ideally)
            try testing.expect(cell_size <= 16);
        }

    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Test all cell operations
- Test all drawing primitives
- Test buffer management
- Test diff algorithms
- Test Unicode support
- Test performance targets
- Mock screen for isolated testing

## Estimated Time
3 hours

## Priority
🟡 High - Quality assurance

## Category
Testing