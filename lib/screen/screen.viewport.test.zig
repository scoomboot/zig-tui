// screen.viewport.test.zig — Test suite for Screen viewport system extensions
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const expectEqual = testing.expectEqual;
    const expectError = testing.expectError;
    const expect = testing.expect;
    
    const Screen = @import("screen.zig").Screen;
    const Size = @import("screen.zig").Size;
    const ViewportContext = @import("screen.zig").ViewportContext;
    const Rect = @import("utils/rect/rect.zig").Rect;
    const Cell = @import("utils/cell/cell.zig").Cell;
    const ScreenManager = @import("utils/screen_manager/screen_manager.zig").ScreenManager;

// ╚════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════════╗

    /// Test helper for creating a test screen
    fn createTestScreen(allocator: std.mem.Allocator) !*Screen {
        var screen = try allocator.create(Screen);
        screen.* = try Screen.init(allocator);
        return screen;
    }
    
    /// Test helper for cleaning up a test screen
    fn cleanupTestScreen(allocator: std.mem.Allocator, screen: *Screen) void {
        screen.deinit();
        allocator.destroy(screen);
    }

// ╚════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐
    
        test "unit: Screen: initializes viewport fields correctly" {
            const allocator = testing.allocator;
            
            const screen = try createTestScreen(allocator);
            defer cleanupTestScreen(allocator, screen);
            
            try expect(!screen.isManaged());
            try expect(screen.getViewportBounds() == null);
            try expect(screen.parent_manager == null);
        }
        
        test "unit: Screen: sets and clears parent manager correctly" {
            const allocator = testing.allocator;
            
            const screen = try createTestScreen(allocator);
            defer cleanupTestScreen(allocator, screen);
            
            var manager = try ScreenManager.init(allocator, .single);
            defer manager.deinit();
            
            // Set parent manager
            screen.setParentManager(@as(*anyopaque, @ptrCast(&manager)));
            try expect(screen.isManaged());
            try expect(screen.parent_manager == @as(*anyopaque, @ptrCast(&manager)));
            
            // Clear parent manager
            screen.clearParentManager();
            try expect(!screen.isManaged());
            try expect(screen.parent_manager == null);
            try expect(screen.getViewportBounds() == null);
        }
        
        test "unit: Screen: manages viewport bounds correctly" {
            const allocator = testing.allocator;
            
            const screen = try createTestScreen(allocator);
            defer cleanupTestScreen(allocator, screen);
            
            const viewport = Rect.init(10, 5, 60, 20);
            
            // Set viewport bounds
            screen.setViewportBounds(viewport);
            const bounds = screen.getViewportBounds();
            
            try expect(bounds != null);
            try expectEqual(@as(u16, 10), bounds.?.x);
            try expectEqual(@as(u16, 5), bounds.?.y);
            try expectEqual(@as(u16, 60), bounds.?.width);
            try expectEqual(@as(u16, 20), bounds.?.height);
        }
        
        test "unit: Screen: calculates effective size correctly" {
            const allocator = testing.allocator;
            
            const screen = try createTestScreen(allocator);
            defer cleanupTestScreen(allocator, screen);
            
            // Test without viewport bounds (independent screen)
            var size = screen.getEffectiveSize();
            try expectEqual(@as(u16, 80), size.cols); // Default screen width
            try expectEqual(@as(u16, 24), size.rows); // Default screen height
            
            // Test with viewport bounds (managed screen)
            const viewport = Rect.init(0, 0, 40, 15);
            screen.setViewportBounds(viewport);
            
            size = screen.getEffectiveSize();
            try expectEqual(@as(u16, 40), size.cols);
            try expectEqual(@as(u16, 15), size.rows);
        }
        
        test "unit: ViewportContext: creates and operates correctly" {
            const allocator = testing.allocator;
            
            const screen = try createTestScreen(allocator);
            defer cleanupTestScreen(allocator, screen);
            
            const viewport_context = screen.getViewportContext();
            
            // Test effective size calculation
            const size = viewport_context.getEffectiveSize();
            try expectEqual(@as(u16, 80), size.cols);
            try expectEqual(@as(u16, 24), size.rows);
            
            // Test bounds checking
            try expect(viewport_context.isWithinBounds(0, 0));
            try expect(viewport_context.isWithinBounds(79, 23));
            try expect(!viewport_context.isWithinBounds(80, 24));
        }
        
        test "unit: ViewportContext: handles drawing operations correctly" {
            const allocator = testing.allocator;
            
            const screen = try createTestScreen(allocator);
            defer cleanupTestScreen(allocator, screen);
            
            var viewport_context = screen.getViewportContext();
            
            // Test cell setting and getting
            const test_cell = Cell.init('A', .{}, .{});
            viewport_context.setCell(5, 3, test_cell);
            
            const retrieved_cell = viewport_context.getCell(5, 3);
            try expect(retrieved_cell != null);
            try expectEqual(@as(u21, 'A'), retrieved_cell.?.char);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: Screen with ScreenManager: coordinates resize correctly" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .split_horizontal);
            defer manager.deinit();
            
            const screen1 = try createTestScreen(allocator);
            const screen2 = try createTestScreen(allocator);
            defer {
                cleanupTestScreen(allocator, screen1);
                cleanupTestScreen(allocator, screen2);
            }
            
            try manager.addScreen(screen1, "left");
            try manager.addScreen(screen2, "right");
            
            // Verify screens are managed
            try expect(screen1.isManaged());
            try expect(screen2.isManaged());
            
            // Test coordinated resize
            try manager.handleResize(100, 40, .preserve_content);
            
            // Verify viewport bounds were set
            try expect(screen1.getViewportBounds() != null);
            try expect(screen2.getViewportBounds() != null);
        }
        
        test "integration: Screen viewport with drawing: restricts coordinates correctly" {
            const allocator = testing.allocator;
            
            const screen = try createTestScreen(allocator);
            defer cleanupTestScreen(allocator, screen);
            
            // Set up viewport bounds (smaller than screen)
            const viewport = Rect.init(0, 0, 20, 10);
            screen.setViewportBounds(viewport);
            
            var manager = try ScreenManager.init(allocator, .single);
            defer manager.deinit();
            screen.setParentManager(@as(*anyopaque, @ptrCast(&manager)));
            
            var viewport_context = screen.getViewportContext();
            
            // Test drawing within bounds
            const test_cell = Cell.init('X', .{}, .{});
            viewport_context.setCell(10, 5, test_cell);
            
            const retrieved_cell = viewport_context.getCell(10, 5);
            try expect(retrieved_cell != null);
            try expectEqual(@as(u21, 'X'), retrieved_cell.?.char);
            
            // Test effective size matches viewport
            const size = viewport_context.getEffectiveSize();
            try expectEqual(@as(u16, 20), size.cols);
            try expectEqual(@as(u16, 10), size.rows);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Scenario Tests ────────────────────────────┐
    
        test "scenario: split-screen editing: viewport coordinates work correctly" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .split_vertical);
            defer manager.deinit();
            
            const editor_screen = try createTestScreen(allocator);
            const console_screen = try createTestScreen(allocator);
            defer {
                cleanupTestScreen(allocator, editor_screen);
                cleanupTestScreen(allocator, console_screen);
            }
            
            try manager.addScreen(editor_screen, "editor");
            try manager.addScreen(console_screen, "console");
            
            // Simulate terminal resize
            try manager.handleResize(80, 40, .preserve_content);
            
            // Both screens should have viewport bounds
            try expect(editor_screen.getViewportBounds() != null);
            try expect(console_screen.getViewportBounds() != null);
            
            // Test drawing to each screen's viewport
            var editor_context = editor_screen.getViewportContext();
            var console_context = console_screen.getViewportContext();
            
            const editor_cell = Cell.init('E', .{}, .{});
            const console_cell = Cell.init('C', .{}, .{});
            
            editor_context.setCell(0, 0, editor_cell);
            console_context.setCell(0, 0, console_cell);
            
            // Verify each screen maintains its own coordinate space
            const editor_retrieved = editor_context.getCell(0, 0);
            const console_retrieved = console_context.getCell(0, 0);
            
            try expect(editor_retrieved != null);
            try expect(console_retrieved != null);
            try expectEqual(@as(u21, 'E'), editor_retrieved.?.char);
            try expectEqual(@as(u21, 'C'), console_retrieved.?.char);
        }
        
        test "scenario: modal dialog overlay: viewport bounds work correctly" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .floating);
            defer manager.deinit();
            
            const background_screen = try createTestScreen(allocator);
            const dialog_screen = try createTestScreen(allocator);
            defer {
                cleanupTestScreen(allocator, background_screen);
                cleanupTestScreen(allocator, dialog_screen);
            }
            
            try manager.addScreen(background_screen, "background");
            try manager.addScreen(dialog_screen, "dialog");
            
            // Set custom viewport for dialog (centered)
            const dialog_viewport = Rect.init(20, 8, 40, 16);
            try manager.setScreenViewport(dialog_screen, dialog_viewport);
            
            // Verify dialog has correct viewport
            const bounds = dialog_screen.getViewportBounds();
            try expect(bounds != null);
            try expectEqual(@as(u16, 20), bounds.?.x);
            try expectEqual(@as(u16, 8), bounds.?.y);
            try expectEqual(@as(u16, 40), bounds.?.width);
            try expectEqual(@as(u16, 16), bounds.?.height);
            
            // Test drawing to dialog viewport
            var dialog_context = dialog_screen.getViewportContext();
            const size = dialog_context.getEffectiveSize();
            
            try expectEqual(@as(u16, 40), size.cols);
            try expectEqual(@as(u16, 16), size.rows);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: ViewportContext drawing: performs efficiently" {
            const allocator = testing.allocator;
            
            const screen = try createTestScreen(allocator);
            defer cleanupTestScreen(allocator, screen);
            
            var viewport_context = screen.getViewportContext();
            const test_cell = Cell.init('*', .{}, .{});
            
            const start_time = std.time.nanoTimestamp();
            
            // Fill entire screen rapidly
            const size = viewport_context.getEffectiveSize();
            for (0..10) |_| {
                var y: u16 = 0;
                while (y < size.rows) : (y += 1) {
                    var x: u16 = 0;
                    while (x < size.cols) : (x += 1) {
                        viewport_context.setCell(x, y, test_cell);
                    }
                }
            }
            
            const elapsed = std.time.nanoTimestamp() - start_time;
            const elapsed_ms = elapsed / 1_000_000;
            
            // Should complete in under 50ms
            try expect(elapsed_ms < 50);
        }
        
        test "performance: viewport bounds checking: processes quickly" {
            const allocator = testing.allocator;
            
            const screen = try createTestScreen(allocator);
            defer cleanupTestScreen(allocator, screen);
            
            screen.setViewportBounds(Rect.init(10, 5, 60, 15));
            var viewport_context = screen.getViewportContext();
            
            const start_time = std.time.nanoTimestamp();
            
            // Perform many bounds checks
            for (0..100000) |i| {
                const x = @as(u16, @intCast(i % 100));
                const y = @as(u16, @intCast(i % 50));
                _ = viewport_context.isWithinBounds(x, y);
            }
            
            const elapsed = std.time.nanoTimestamp() - start_time;
            const elapsed_ms = elapsed / 1_000_000;
            
            // Should complete in under 10ms
            try expect(elapsed_ms < 10);
        }
    
    // └──────────────────────────────────────────────────────────────────┘

// ╚════════════════════════════════════════════════════════════════════════════════════════╝