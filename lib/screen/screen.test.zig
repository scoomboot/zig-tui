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
    const Cell = @import("utils/cell/cell.zig").Cell;
    const Rect = @import("utils/rect/rect.zig").Rect;

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
            var screen = try Screen.init(allocator, 100, 50);
            defer screen.deinit();
            
            try testing.expectEqual(@as(u16, 100), screen.getWidth());
            try testing.expectEqual(@as(u16, 50), screen.getHeight());
        }
        
        test "unit: Screen: clears buffer correctly" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 10, 10);
            defer screen.deinit();
            
            // Set a cell
            const cell = Cell{ .char = 'A', .fg = .white, .bg = .black, .style = .none };
            try screen.setCell(5, 5, cell);
            
            // Clear screen
            screen.clear();
            
            // Check cell is cleared
            const cleared = screen.getCell(5, 5);
            try testing.expectEqual(@as(u32, ' '), cleared.char);
        }
        
        test "unit: Screen: sets and gets cells correctly" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 20, 20);
            defer screen.deinit();
            
            const cell = Cell{ .char = 'X', .fg = .red, .bg = .blue, .style = .bold };
            try screen.setCell(10, 10, cell);
            
            const retrieved = screen.getCell(10, 10);
            try testing.expectEqual(cell.char, retrieved.char);
            try testing.expectEqual(cell.fg, retrieved.fg);
            try testing.expectEqual(cell.bg, retrieved.bg);
            try testing.expectEqual(cell.style, retrieved.style);
        }
        
        test "unit: Screen: handles out of bounds access" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 10, 10);
            defer screen.deinit();
            
            const cell = Cell{ .char = 'A', .fg = .white, .bg = .black, .style = .none };
            
            // Try to set cell out of bounds
            const result = screen.setCell(100, 100, cell);
            try testing.expectError(Screen.Error.OutOfBounds, result);
        }
        
        test "unit: Screen: resizes correctly" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 10, 10);
            defer screen.deinit();
            
            // Set some cells
            const cell = Cell{ .char = 'A', .fg = .white, .bg = .black, .style = .none };
            try screen.setCell(5, 5, cell);
            
            // Resize
            try screen.resize(20, 20);
            
            try testing.expectEqual(@as(u16, 20), screen.getWidth());
            try testing.expectEqual(@as(u16, 20), screen.getHeight());
            
            // Old content should be preserved
            const preserved = screen.getCell(5, 5);
            try testing.expectEqual(cell.char, preserved.char);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: Screen with Cell: manages cell buffer" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 50, 25);
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
                    try screen.setCell(@intCast(x), @intCast(y), cell);
                }
            }
            
            // Verify pattern
            for (0..25) |y| {
                for (0..50) |x| {
                    const cell = screen.getCell(@intCast(x), @intCast(y));
                    try testing.expectEqual(@as(u32, @intCast((x * y) % 128)), cell.char);
                }
            }
        }
        
        test "integration: Screen with Rect: fills rectangles correctly" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 100, 50);
            defer screen.deinit();
            
            const rect = Rect{ .x = 10, .y = 10, .width = 30, .height = 20 };
            const fill_cell = Cell{ .char = '#', .fg = .green, .bg = .black, .style = .none };
            
            try screen.fillRect(rect, fill_cell);
            
            // Check filled area
            for (rect.y..rect.y + rect.height) |y| {
                for (rect.x..rect.x + rect.width) |x| {
                    const cell = screen.getCell(@intCast(x), @intCast(y));
                    try testing.expectEqual(fill_cell.char, cell.char);
                    try testing.expectEqual(fill_cell.fg, cell.fg);
                }
            }
        }
        
        test "integration: Screen buffering: double buffering works" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 80, 24);
            defer screen.deinit();
            
            // Write to back buffer
            const cell = Cell{ .char = 'B', .fg = .white, .bg = .black, .style = .none };
            try screen.setCell(10, 10, cell);
            
            // Swap buffers
            try screen.present();
            
            // Front buffer should have the change
            const front_cell = screen.getFrontCell(10, 10);
            try testing.expectEqual(cell.char, front_cell.char);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── E2E Tests ────────────────────────────┐
    
        test "e2e: complete rendering pipeline: buffer to output" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 80, 24);
            defer screen.deinit();
            
            // Clear screen
            screen.clear();
            
            // Draw UI elements
            const header = "TUI Application";
            for (header, 0..) |char, i| {
                const cell = Cell{ .char = char, .fg = .white, .bg = .blue, .style = .bold };
                try screen.setCell(@intCast(i), 0, cell);
            }
            
            // Draw border
            for (0..80) |x| {
                const border_cell = Cell{ .char = '-', .fg = .white, .bg = .black, .style = .none };
                try screen.setCell(@intCast(x), 1, border_cell);
                try screen.setCell(@intCast(x), 22, border_cell);
            }
            
            // Present to front buffer
            try screen.present();
            
            // Generate diff
            const diff = try screen.getDiff(allocator);
            defer allocator.free(diff);
            
            // Should have changes
            try testing.expect(diff.len > 0);
        }
        
        test "e2e: screen update cycle: tracks dirty regions" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 100, 40);
            defer screen.deinit();
            
            // Initial render
            screen.clear();
            try screen.present();
            
            // Make small change
            const cell = Cell{ .char = 'X', .fg = .red, .bg = .black, .style = .none };
            try screen.setCell(50, 20, cell);
            
            // Get dirty region
            const dirty = try screen.getDirtyRegion();
            try testing.expect(dirty != null);
            
            if (dirty) |region| {
                try testing.expect(region.contains(50, 20));
            }
            
            // Present changes
            try screen.present();
            
            // Should have no dirty regions after present
            const after_dirty = try screen.getDirtyRegion();
            try testing.expect(after_dirty == null);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: Screen.setCell: handles many updates efficiently" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 200, 100);
            defer screen.deinit();
            
            const cell = Cell{ .char = 'P', .fg = .white, .bg = .black, .style = .none };
            const updates = 100000;
            
            var prng = std.rand.DefaultPrng.init(12345);
            const random = prng.random();
            
            const start = std.time.milliTimestamp();
            
            for (0..updates) |_| {
                const x = random.intRangeLessThan(u16, 0, 200);
                const y = random.intRangeLessThan(u16, 0, 100);
                try screen.setCell(x, y, cell);
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should handle 100k updates quickly
            try testing.expect(elapsed < 1000); // Under 1 second
        }
        
        test "performance: Screen.getDiff: generates diff efficiently" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 160, 50);
            defer screen.deinit();
            
            // Make many changes
            for (0..50) |y| {
                for (0..160) |x| {
                    if ((x + y) % 3 == 0) {
                        const cell = Cell{ .char = '*', .fg = .yellow, .bg = .black, .style = .none };
                        try screen.setCell(@intCast(x), @intCast(y), cell);
                    }
                }
            }
            
            const start = std.time.milliTimestamp();
            const diff = try screen.getDiff(allocator);
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
            var screen = try Screen.init(allocator, 500, 200);
            defer screen.deinit();
            
            // Fill entire screen
            const cell = Cell{ .char = 'S', .fg = .white, .bg = .black, .style = .none };
            for (0..200) |y| {
                for (0..500) |x| {
                    try screen.setCell(@intCast(x), @intCast(y), cell);
                }
            }
            
            // Should handle large buffer
            try testing.expectEqual(@as(u16, 500), screen.getWidth());
            try testing.expectEqual(@as(u16, 200), screen.getHeight());
        }
        
        test "stress: Screen: survives rapid resize operations" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 80, 24);
            defer screen.deinit();
            
            var prng = std.rand.DefaultPrng.init(54321);
            const random = prng.random();
            
            // Perform many random resizes
            for (0..100) |_| {
                const w = random.intRangeLessThan(u16, 10, 200);
                const h = random.intRangeLessThan(u16, 10, 100);
                try screen.resize(w, h);
                
                // Verify size
                try testing.expectEqual(w, screen.getWidth());
                try testing.expectEqual(h, screen.getHeight());
            }
        }
    
    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝