// screen.test.zig — Comprehensive tests for screen buffer operations
//
// repo   : https://github.com/fisty/zig-tui
// author : https://github.com/fisty
//
// Tests for screen buffer management, rendering, and diffing.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Screen = @import("screen.zig").Screen;
    const ResizeMode = @import("screen.zig").ResizeMode;
    const Size = @import("screen.zig").Size;
    const ScreenResizeError = @import("screen.zig").ScreenResizeError;
    const Cell = @import("utils/cell/cell.zig").Cell;
    const Rect = @import("utils/rect/rect.zig").Rect;
    const Terminal = @import("../terminal/terminal.zig").Terminal;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test constants
    const DEFAULT_WIDTH = 80;
    const DEFAULT_HEIGHT = 24;
    const MAX_SCREEN_SIZE = 10000;
    
    // Test helpers
    const TestScreen = struct {
        screen: Screen,
        allocator: std.mem.Allocator,
        
        pub fn init(allocator: std.mem.Allocator, width: u16, height: u16) !TestScreen {
            return TestScreen{
                .screen = try Screen.init(allocator, width, height),
                .allocator = allocator,
            };
        }
        
        pub fn deinit(self: *TestScreen) void {
            self.screen.deinit();
        }
    };
    
    // Creates a screen with test pattern
    fn createTestPatternScreen(allocator: std.mem.Allocator) !*Screen {
        var screen = try allocator.create(Screen);
        screen.* = try Screen.init(allocator, DEFAULT_WIDTH, DEFAULT_HEIGHT);
        
        // Fill with test pattern
        for (0..DEFAULT_HEIGHT) |y| {
            for (0..DEFAULT_WIDTH) |x| {
                const cell = Cell{
                    .char = @intCast((x + y) % 26 + 'A'),
                    .fg = .white,
                    .bg = .black,
                    .style = .none,
                };
                try screen.setCell(@intCast(x), @intCast(y), cell);
            }
        }
        
        return screen;
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐
    
        test "unit: Screen: initializes with correct dimensions" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 100, 50);
            defer screen.deinit();
            
            try testing.expectEqual(@as(u16, 100), screen.width);
            try testing.expectEqual(@as(u16, 50), screen.height);
        }
        
        test "unit: Screen: clears buffer correctly" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 10, 10);
            defer screen.deinit();
            
            // Set a cell
            const cell = Cell{ .char = 'A', .fg = .white, .bg = .black, .style = .none };
            screen.set_cell(5, 5, cell);
            
            // Clear screen
            screen.clear();
            
            // Check cell is cleared
            if (screen.get_cell(5, 5)) |cleared| {
                try testing.expectEqual(@as(u32, ' '), cleared.char);
            } else {
                try testing.expect(false);
            }
        }
        
        test "unit: Screen: sets and gets cells correctly" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 20, 20);
            defer screen.deinit();
            
            const cell = Cell{ .char = 'X', .fg = .red, .bg = .blue, .style = .bold };
            screen.set_cell(10, 10, cell);
            
            if (screen.get_cell(10, 10)) |retrieved| {
                try testing.expectEqual(cell.char, retrieved.char);
                try testing.expectEqual(cell.fg, retrieved.fg);
                try testing.expectEqual(cell.bg, retrieved.bg);
                try testing.expectEqual(cell.style, retrieved.style);
            } else {
                try testing.expect(false);
            }
        }
        
        test "unit: Screen: handles out of bounds access" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 10, 10);
            defer screen.deinit();
            
            const cell = Cell{ .char = 'A', .fg = .white, .bg = .black, .style = .none };
            
            // Try to set cell out of bounds (should silently return)
            screen.set_cell(100, 100, cell);
            
            // Try to get cell out of bounds (should return null)
            const result = screen.get_cell(100, 100);
            try testing.expectEqual(@as(?*Cell, null), result);
        }
        
        test "unit: Screen: resizes correctly" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 10, 10);
            defer screen.deinit();
            
            // Set some cells
            const cell = Cell{ .char = 'A', .fg = .white, .bg = .black, .style = .none };
            screen.set_cell(5, 5, cell);
            
            // Resize
            try screen.resize(20, 20);
            
            try testing.expectEqual(@as(u16, 20), screen.width);
            try testing.expectEqual(@as(u16, 20), screen.height);
        }
        
        test "unit: Screen: initializes with terminal size detection" {
            const allocator = testing.allocator;
            
            // Create a mock terminal
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            var screen = try Screen.initWithTerminal(allocator, &terminal);
            defer screen.deinit();
            
            // Should have terminal reference set
            try testing.expect(screen.terminal_ref != null);
            
            // Should have dimensions from terminal
            const size = screen.getSize();
            try testing.expect(size.cols > 0);
            try testing.expect(size.rows > 0);
        }
        
        test "unit: Screen: handles resize with preserve_content mode" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 10, 10);
            defer screen.deinit();
            
            // Fill screen with pattern
            var y: u16 = 0;
            while (y < 10) : (y += 1) {
                var x: u16 = 0;
                while (x < 10) : (x += 1) {
                    const cell = Cell{ 
                        .char = @intCast('A' + ((x + y) % 26)),
                        .fg = .white, 
                        .bg = .black, 
                        .style = .none 
                    };
                    screen.set_cell(x, y, cell);
                }
            }
            
            // Swap buffers to commit changes
            screen.swap_buffers();
            
            // Resize with preserve_content
            const new_size = Size.init(15, 15);
            try screen.handleResize(new_size, .preserve_content);
            
            // Check size changed
            try testing.expectEqual(@as(u16, 15), screen.width);
            try testing.expectEqual(@as(u16, 15), screen.height);
            
            // Check content preserved in overlapping region
            y = 0;
            while (y < 10) : (y += 1) {
                var x: u16 = 0;
                while (x < 10) : (x += 1) {
                    const expected_char = @as(u32, 'A' + ((x + y) % 26));
                    const idx = @as(usize, y) * @as(usize, 15) + @as(usize, x);
                    try testing.expectEqual(expected_char, screen.front_buffer[idx].char);
                }
            }
            
            // Check new areas are empty
            y = 0;
            while (y < 15) : (y += 1) {
                var x: u16 = 10;
                while (x < 15) : (x += 1) {
                    const idx = @as(usize, y) * @as(usize, 15) + @as(usize, x);
                    try testing.expectEqual(@as(u32, ' '), screen.front_buffer[idx].char);
                }
            }
        }
        
        test "unit: Screen: handles resize with clear_content mode" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 10, 10);
            defer screen.deinit();
            
            // Fill screen with content
            const cell = Cell{ .char = 'X', .fg = .white, .bg = .black, .style = .none };
            var i: u16 = 0;
            while (i < 10) : (i += 1) {
                screen.set_cell(i, i, cell);
            }
            
            // Resize with clear_content
            const new_size = Size.init(20, 20);
            try screen.handleResize(new_size, .clear_content);
            
            // Check size changed
            try testing.expectEqual(@as(u16, 20), screen.width);
            try testing.expectEqual(@as(u16, 20), screen.height);
            
            // Check all content is cleared
            for (screen.front_buffer) |front_cell| {
                try testing.expectEqual(@as(u32, ' '), front_cell.char);
            }
        }
        
        test "unit: Screen: validates resize dimensions" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 10, 10);
            defer screen.deinit();
            
            // Try invalid dimensions (0 width)
            const invalid_size1 = Size.init(0, 10);
            const result1 = screen.handleResize(invalid_size1, .preserve_content);
            try testing.expectError(ScreenResizeError.InvalidDimensions, result1);
            
            // Try invalid dimensions (0 height)
            const invalid_size2 = Size.init(10, 0);
            const result2 = screen.handleResize(invalid_size2, .preserve_content);
            try testing.expectError(ScreenResizeError.InvalidDimensions, result2);
            
            // Original dimensions should be unchanged
            try testing.expectEqual(@as(u16, 10), screen.width);
            try testing.expectEqual(@as(u16, 10), screen.height);
        }
        
        test "unit: Screen: skips resize when dimensions unchanged" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 10, 10);
            defer screen.deinit();
            
            // Mark some state
            screen.needs_full_redraw = false;
            
            // Try resize with same dimensions
            const same_size = Size.init(10, 10);
            try screen.handleResize(same_size, .preserve_content);
            
            // Should not have marked for redraw
            try testing.expectEqual(false, screen.needs_full_redraw);
        }
        
        test "unit: Screen: utility methods work correctly" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 80, 24);
            defer screen.deinit();
            
            // Test getSize
            const size = screen.getSize();
            try testing.expectEqual(@as(u16, 80), size.cols);
            try testing.expectEqual(@as(u16, 24), size.rows);
            
            // Test isResizing
            try testing.expectEqual(false, screen.isResizing());
            
            // Test markForFullRedraw
            screen.needs_full_redraw = false;
            screen.markForFullRedraw();
            try testing.expectEqual(true, screen.needs_full_redraw);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: Screen with Cell: manages cell buffer" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 50, 25);
            defer screen.deinit();
            
            // Fill screen with pattern
            for (0..25) |y| {
                for (0..50) |x| {
                    const cell = Cell{
                        .char = @intCast((x * y) % 128),
                        .fg = if (x % 2 == 0) .white else .black,
                        .bg = if (y % 2 == 0) .black else .white,
                        .style = .none,
                    };
                    screen.set_cell(@intCast(x), @intCast(y), cell);
                }
            }
            
            // Verify pattern
            for (0..25) |y| {
                for (0..50) |x| {
                    if (screen.get_cell(@intCast(x), @intCast(y))) |cell| {
                        try testing.expectEqual(@as(u32, @intCast((x * y) % 128)), cell.char);
                    } else {
                        try testing.expect(false);
                    }
                }
            }
        }
        
        test "integration: Screen with Terminal: resize callback integration" {
            const allocator = testing.allocator;
            
            // Create terminal and screen
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            var screen = try Screen.initWithTerminal(allocator, &terminal);
            defer screen.deinit();
            
            // Initial size
            const initial_size = screen.getSize();
            
            // Fill with test pattern
            const cell = Cell{ .char = 'T', .fg = .green, .bg = .black, .style = .none };
            var y: u16 = 0;
            while (y < @min(5, initial_size.rows)) : (y += 1) {
                var x: u16 = 0;
                while (x < @min(5, initial_size.cols)) : (x += 1) {
                    screen.set_cell(x, y, cell);
                }
            }
            screen.swap_buffers();
            
            // Simulate resize through handleResize
            const new_size = Size.init(
                if (initial_size.cols > 40) initial_size.cols - 10 else initial_size.cols + 10,
                if (initial_size.rows > 20) initial_size.rows - 5 else initial_size.rows + 5
            );
            try screen.handleResize(new_size, .preserve_content);
            
            // Verify resize occurred
            const resized = screen.getSize();
            try testing.expectEqual(new_size.cols, resized.cols);
            try testing.expectEqual(new_size.rows, resized.rows);
            
            // Check content preservation in valid region
            const check_width = @min(5, @min(initial_size.cols, new_size.cols));
            const check_height = @min(5, @min(initial_size.rows, new_size.rows));
            
            y = 0;
            while (y < check_height) : (y += 1) {
                var x: u16 = 0;
                while (x < check_width) : (x += 1) {
                    const idx = @as(usize, y) * @as(usize, new_size.cols) + @as(usize, x);
                    try testing.expectEqual(cell.char, screen.front_buffer[idx].char);
                }
            }
        }
        
        test "integration: Screen buffering: double buffering works" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 80, 24);
            defer screen.deinit();
            
            // Write to back buffer
            const cell = Cell{ .char = 'B', .fg = .white, .bg = .black, .style = .none };
            screen.set_cell(10, 10, cell);
            
            // Swap buffers
            screen.swap_buffers();
            
            // Front buffer should have the change
            const idx = @as(usize, 10) * @as(usize, 80) + @as(usize, 10);
            try testing.expectEqual(cell.char, screen.front_buffer[idx].char);
        }
        
        test "integration: Screen resize: preserves content across multiple resizes" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 20, 20);
            defer screen.deinit();
            
            // Create distinctive pattern
            const patterns = [_]u32{ '@', '#', '$', '%', '&' };
            for (patterns, 0..) |pattern, i| {
                const cell = Cell{ 
                    .char = pattern, 
                    .fg = .white, 
                    .bg = .black, 
                    .style = .none 
                };
                screen.set_cell(@intCast(i), @intCast(i), cell);
            }
            screen.swap_buffers();
            
            // First resize - larger
            try screen.handleResize(Size.init(30, 30), .preserve_content);
            
            // Check pattern preserved
            for (patterns, 0..) |pattern, i| {
                const idx = @as(usize, i) * @as(usize, 30) + @as(usize, i);
                try testing.expectEqual(pattern, screen.front_buffer[idx].char);
            }
            
            // Second resize - smaller
            try screen.handleResize(Size.init(15, 15), .preserve_content);
            
            // Check pattern still preserved (within bounds)
            for (patterns, 0..) |pattern, i| {
                if (i < 15) {
                    const idx = @as(usize, i) * @as(usize, 15) + @as(usize, i);
                    try testing.expectEqual(pattern, screen.front_buffer[idx].char);
                }
            }
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── E2E Tests ────────────────────────────┐
    
        test "e2e: complete rendering pipeline: buffer to output" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 80, 24);
            defer screen.deinit();
            
            // Clear screen
            screen.clear();
            
            // Draw UI elements
            const header = "TUI Application";
            for (header, 0..) |char, i| {
                const cell = Cell{ .char = char, .fg = .white, .bg = .blue, .style = .bold };
                screen.set_cell(@intCast(i), 0, cell);
            }
            
            // Draw border
            for (0..80) |x| {
                const border_cell = Cell{ .char = '-', .fg = .white, .bg = .black, .style = .none };
                screen.set_cell(@intCast(x), 1, border_cell);
                screen.set_cell(@intCast(x), 22, border_cell);
            }
            
            // Swap buffers
            screen.swap_buffers();
            
            // Verify content in front buffer
            for (header, 0..) |char, i| {
                const idx = @as(usize, 0) * @as(usize, 80) + @as(usize, i);
                try testing.expectEqual(@as(u32, char), screen.front_buffer[idx].char);
            }
        }
        
        test "e2e: full resize workflow: init with terminal to resize to redraw" {
            const allocator = testing.allocator;
            
            // Initialize with terminal
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            var screen = try Screen.initWithTerminal(allocator, &terminal);
            defer screen.deinit();
            
            const initial_size = screen.getSize();
            
            // Draw initial content
            const header = "Resizable TUI";
            for (header, 0..) |char, i| {
                if (i < initial_size.cols) {
                    const cell = Cell{ 
                        .char = char, 
                        .fg = .cyan, 
                        .bg = .black, 
                        .style = .bold 
                    };
                    screen.set_cell(@intCast(i), 0, cell);
                }
            }
            screen.swap_buffers();
            
            // Simulate window resize - smaller
            const smaller_size = Size.init(
                @max(40, initial_size.cols / 2),
                @max(12, initial_size.rows / 2)
            );
            try screen.handleResize(smaller_size, .preserve_content);
            
            // Verify resize and content preservation
            try testing.expectEqual(smaller_size.cols, screen.width);
            try testing.expectEqual(smaller_size.rows, screen.height);
            try testing.expectEqual(true, screen.needs_full_redraw);
            
            // Check header preserved (up to new width)
            const check_len = @min(header.len, smaller_size.cols);
            for (header[0..check_len], 0..) |char, i| {
                const idx = @as(usize, 0) * @as(usize, smaller_size.cols) + @as(usize, i);
                try testing.expectEqual(@as(u32, char), screen.front_buffer[idx].char);
            }
            
            // Simulate resize back to larger
            const larger_size = Size.init(
                initial_size.cols + 20,
                initial_size.rows + 10
            );
            try screen.handleResize(larger_size, .preserve_content);
            
            // Content should still be preserved
            for (header[0..check_len], 0..) |char, i| {
                const idx = @as(usize, 0) * @as(usize, larger_size.cols) + @as(usize, i);
                try testing.expectEqual(@as(u32, char), screen.front_buffer[idx].char);
            }
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: Screen.setCell: handles many updates efficiently" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 200, 100);
            defer screen.deinit();
            
            const cell = Cell{ .char = 'P', .fg = .white, .bg = .black, .style = .none };
            const updates = 100000;
            
            var prng = std.rand.DefaultPrng.init(12345);
            const random = prng.random();
            
            const start = std.time.milliTimestamp();
            
            for (0..updates) |_| {
                const x = random.intRangeLessThan(u16, 0, 200);
                const y = random.intRangeLessThan(u16, 0, 100);
                screen.set_cell(x, y, cell);
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should handle 100k updates quickly
            try testing.expect(elapsed < 1000); // Under 1 second
        }
        
        test "performance: Screen resize: completes within 50ms" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 320, 200);
            defer screen.deinit();
            
            // Fill with content to make resize work harder
            var y: u16 = 0;
            while (y < 200) : (y += 1) {
                var x: u16 = 0;
                while (x < 320) : (x += 1) {
                    const cell = Cell{ 
                        .char = @intCast(((x * y) % 94) + 33),
                        .fg = .white, 
                        .bg = .black, 
                        .style = .none 
                    };
                    screen.set_cell(x, y, cell);
                }
            }
            screen.swap_buffers();
            
            // Measure resize time
            const start = std.time.milliTimestamp();
            try screen.handleResize(Size.init(400, 300), .preserve_content);
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should complete within 50ms as per requirement
            try testing.expect(elapsed < 50);
            
            // Test shrinking too
            const start2 = std.time.milliTimestamp();
            try screen.handleResize(Size.init(160, 100), .preserve_content);
            const elapsed2 = std.time.milliTimestamp() - start2;
            
            try testing.expect(elapsed2 < 50);
        }
        
        test "performance: Screen.getDiff: generates diff efficiently" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 160, 50);
            defer screen.deinit();
            
            // Make many changes
            for (0..50) |y| {
                for (0..160) |x| {
                    if ((x + y) % 3 == 0) {
                        const cell = Cell{ .char = '*', .fg = .yellow, .bg = .black, .style = .none };
                        screen.set_cell(@intCast(x), @intCast(y), cell);
                    }
                }
            }
            
            const start = std.time.milliTimestamp();
            const diff = try screen.get_diff(allocator);
            defer allocator.free(diff);
            const elapsed = std.time.milliTimestamp() - start;
            
            // Diff generation should be fast
            try testing.expect(elapsed < 100);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Stress Tests ────────────────────────────┐
    
        test "stress: Screen: handles maximum size buffers" {
            const allocator = testing.allocator;
            
            // Try to create very large screen
            var screen = try Screen.init_with_size(allocator, 500, 200);
            defer screen.deinit();
            
            // Fill entire screen
            const cell = Cell{ .char = 'S', .fg = .white, .bg = .black, .style = .none };
            for (0..200) |y| {
                for (0..500) |x| {
                    screen.set_cell(@intCast(x), @intCast(y), cell);
                }
            }
            
            // Should handle large buffer
            try testing.expectEqual(@as(u16, 500), screen.width);
            try testing.expectEqual(@as(u16, 200), screen.height);
        }
        
        test "stress: Screen: survives rapid resize operations" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 80, 24);
            defer screen.deinit();
            
            var prng = std.rand.DefaultPrng.init(54321);
            const random = prng.random();
            
            // Perform many random resizes using old resize method
            for (0..100) |_| {
                const w = random.intRangeLessThan(u16, 10, 200);
                const h = random.intRangeLessThan(u16, 10, 100);
                try screen.resize(w, h);
                
                // Verify size
                try testing.expectEqual(w, screen.width);
                try testing.expectEqual(h, screen.height);
            }
        }
        
        test "stress: Screen resize: handles edge cases" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 100, 50);
            defer screen.deinit();
            
            // Test very small size
            try screen.handleResize(Size.init(1, 1), .preserve_content);
            try testing.expectEqual(@as(u16, 1), screen.width);
            try testing.expectEqual(@as(u16, 1), screen.height);
            
            // Test very large size (but reasonable for testing)
            try screen.handleResize(Size.init(1000, 1000), .clear_content);
            try testing.expectEqual(@as(u16, 1000), screen.width);
            try testing.expectEqual(@as(u16, 1000), screen.height);
            
            // Test aspect ratio extremes
            try screen.handleResize(Size.init(1, 500), .preserve_content);
            try testing.expectEqual(@as(u16, 1), screen.width);
            try testing.expectEqual(@as(u16, 500), screen.height);
            
            try screen.handleResize(Size.init(500, 1), .preserve_content);
            try testing.expectEqual(@as(u16, 500), screen.width);
            try testing.expectEqual(@as(u16, 1), screen.height);
        }
        
        test "stress: Screen resize: thread safety simulation" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 80, 24);
            defer screen.deinit();
            
            // Fill with identifiable content
            const marker = Cell{ .char = 'M', .fg = .magenta, .bg = .black, .style = .none };
            screen.set_cell(0, 0, marker);
            screen.set_cell(79, 23, marker);
            screen.swap_buffers();
            
            // Simulate concurrent resize attempts
            // In real scenario, these would be from different threads
            // Here we test the mutex protection logic
            
            // First resize should succeed
            try screen.handleResize(Size.init(100, 30), .preserve_content);
            
            // Manually set is_resizing to simulate concurrent access
            screen.is_resizing = true;
            
            // Second resize should fail with ResizeInProgress
            const result = screen.handleResize(Size.init(120, 40), .preserve_content);
            try testing.expectError(ScreenResizeError.ResizeInProgress, result);
            
            // Reset flag
            screen.is_resizing = false;
            
            // Now resize should work again
            try screen.handleResize(Size.init(120, 40), .preserve_content);
            try testing.expectEqual(@as(u16, 120), screen.width);
            try testing.expectEqual(@as(u16, 40), screen.height);
            
            // Check marker preservation
            const idx1 = @as(usize, 0) * @as(usize, 120) + @as(usize, 0);
            try testing.expectEqual(marker.char, screen.front_buffer[idx1].char);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Additional Resize Tests ────────────────────────────┐
    
        test "unit: Screen: resize with scale_content mode defaults to clear" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 10, 10);
            defer screen.deinit();
            
            // Fill with content
            const cell = Cell{ .char = 'S', .fg = .white, .bg = .black, .style = .none };
            var i: u16 = 0;
            while (i < 10) : (i += 1) {
                screen.set_cell(i, i, cell);
            }
            screen.swap_buffers();
            
            // Resize with scale_content (currently defaults to clear)
            const new_size = Size.init(20, 20);
            try screen.handleResize(new_size, .scale_content);
            
            // Should be cleared (scale_content not yet implemented)
            for (screen.front_buffer) |front_cell| {
                try testing.expectEqual(@as(u32, ' '), front_cell.char);
            }
        }
        
        test "integration: Screen resize: content preservation with shrinking" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 20, 20);
            defer screen.deinit();
            
            // Create a pattern that will be partially lost on shrink
            var y: u16 = 0;
            while (y < 20) : (y += 1) {
                var x: u16 = 0;
                while (x < 20) : (x += 1) {
                    const cell = Cell{
                        .char = if (x < 10 and y < 10) 'K' else 'L',
                        .fg = .white,
                        .bg = .black,
                        .style = .none,
                    };
                    screen.set_cell(x, y, cell);
                }
            }
            screen.swap_buffers();
            
            // Shrink to smaller size
            try screen.handleResize(Size.init(10, 10), .preserve_content);
            
            // Only 'K' cells should remain
            y = 0;
            while (y < 10) : (y += 1) {
                var x: u16 = 0;
                while (x < 10) : (x += 1) {
                    const idx = @as(usize, y) * @as(usize, 10) + @as(usize, x);
                    try testing.expectEqual(@as(u32, 'K'), screen.front_buffer[idx].char);
                }
            }
        }
        
        test "performance: Screen resize: batch resize operations" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 100, 50);
            defer screen.deinit();
            
            // Fill with complex content
            for (0..50) |y| {
                for (0..100) |x| {
                    const cell = Cell{
                        .char = @intCast(33 + ((x * y) % 94)),
                        .fg = if ((x + y) % 2 == 0) .white else .cyan,
                        .bg = .black,
                        .style = .none,
                    };
                    screen.set_cell(@intCast(x), @intCast(y), cell);
                }
            }
            screen.swap_buffers();
            
            const resize_ops = 10;
            const start = std.time.milliTimestamp();
            
            // Perform multiple resizes
            var i: u16 = 0;
            while (i < resize_ops) : (i += 1) {
                const new_width = 100 + (i * 10);
                const new_height = 50 + (i * 5);
                try screen.handleResize(Size.init(new_width, new_height), .preserve_content);
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // All resizes should complete quickly
            try testing.expect(elapsed < 100); // Under 100ms for 10 resizes
        }
        
        test "stress: Screen resize: memory stability check" {
            const allocator = testing.allocator;
            var screen = try Screen.init_with_size(allocator, 50, 25);
            defer screen.deinit();
            
            // Pattern to track memory corruption
            const sentinel = Cell{ .char = 0xDEADBEEF, .fg = .white, .bg = .black, .style = .none };
            
            var prng = std.rand.DefaultPrng.init(9876);
            const random = prng.random();
            
            // Perform many resize operations with random sizes
            var i: u32 = 0;
            while (i < 50) : (i += 1) {
                // Random size within reasonable bounds
                const w = random.intRangeLessThan(u16, 20, 300);
                const h = random.intRangeLessThan(u16, 10, 150);
                
                // Place sentinel values
                if (screen.width > 0 and screen.height > 0) {
                    screen.set_cell(0, 0, sentinel);
                    screen.set_cell(screen.width - 1, screen.height - 1, sentinel);
                }
                
                // Alternate between resize modes
                const mode: ResizeMode = if (i % 3 == 0) .preserve_content else if (i % 3 == 1) .clear_content else .scale_content;
                
                try screen.handleResize(Size.init(w, h), mode);
                
                // Verify size is correct
                try testing.expectEqual(w, screen.width);
                try testing.expectEqual(h, screen.height);
                
                // Verify buffers are properly sized
                const expected_size = @as(usize, w) * @as(usize, h);
                try testing.expectEqual(expected_size, screen.front_buffer.len);
                try testing.expectEqual(expected_size, screen.back_buffer.len);
            }
        }
    
    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝