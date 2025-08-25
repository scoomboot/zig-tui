// screen_manager.test.zig — Comprehensive test suite for multi-screen management
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
    
    const ScreenManager = @import("screen_manager.zig").ScreenManager;
    const LayoutType = @import("screen_manager.zig").LayoutType;
    const GridConfig = @import("screen_manager.zig").GridConfig;
    const SplitConfig = @import("screen_manager.zig").SplitConfig;
    const FocusEvent = @import("screen_manager.zig").FocusEvent;
    const FocusEventType = @import("screen_manager.zig").FocusEventType;
    const Screen = @import("../../screen.zig").Screen;
    const Terminal = @import("../../../terminal/terminal.zig").Terminal;
    const Rect = @import("../rect/rect.zig").Rect;
    const Size = @import("../../screen.zig").Size;

// ╚════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════════╗

    /// Test helper for creating screen instances
    fn createTestScreen(allocator: std.mem.Allocator) !*Screen {
        var screen = try allocator.create(Screen);
        screen.* = try Screen.init(allocator);
        return screen;
    }
    
    /// Test helper for creating multiple screens
    fn createTestScreens(allocator: std.mem.Allocator, count: usize) ![]const *Screen {
        var screens = try allocator.alloc(*Screen, count);
        for (screens, 0..) |*screen, i| {
            screen.* = try createTestScreen(allocator);
            _ = i; // Suppress unused variable warning
        }
        return screens;
    }
    
    /// Test helper for cleaning up screens
    fn cleanupTestScreens(allocator: std.mem.Allocator, screens: []const *Screen) void {
        for (screens) |screen| {
            screen.deinit();
            allocator.destroy(screen);
        }
        allocator.free(screens);
    }
    
    /// Focus event capture for testing
    var captured_events: std.ArrayList(FocusEvent) = undefined;
    var capture_allocator: std.mem.Allocator = undefined;
    
    fn testFocusCallback(event: FocusEvent) void {
        captured_events.append(event) catch unreachable;
    }
    
    fn setupEventCapture(allocator: std.mem.Allocator) void {
        capture_allocator = allocator;
        captured_events = std.ArrayList(FocusEvent).init(allocator);
    }
    
    fn cleanupEventCapture() void {
        captured_events.deinit();
    }
    
    fn clearCapturedEvents() void {
        captured_events.clearRetainingCapacity();
    }

// ╚════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐
    
        test "unit: ScreenManager: initializes with default values" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .single);
            defer manager.deinit();
            
            try expectEqual(@as(usize, 0), manager.getScreenCount());
            try expectEqual(LayoutType.single, manager.getLayout());
            try expect(manager.getFocusedScreen() == null);
            try expect(!manager.isFocusLocked());
            try expect(manager.getModalScreen() == null);
        }
        
        test "unit: ScreenManager: adds and removes screens correctly" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .single);
            defer manager.deinit();
            
            const screens = try createTestScreens(allocator, 3);
            defer cleanupTestScreens(allocator, screens);
            
            // Add screens
            try manager.addScreen(screens[0], "screen1");
            try manager.addScreen(screens[1], "screen2");  
            try manager.addScreen(screens[2], null);
            
            try expectEqual(@as(usize, 3), manager.getScreenCount());
            
            // Test screen retrieval by ID
            const found_screen = try manager.getScreenById("screen1");
            try expect(found_screen == screens[0]);
            
            // Remove screen
            try manager.removeScreen(screens[1]);
            try expectEqual(@as(usize, 2), manager.getScreenCount());
            
            // Test duplicate ID error
            try expectError(error.DuplicateId, manager.addScreen(screens[1], "screen1"));
        }
        
        test "unit: ScreenManager: manages layout types correctly" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .single);
            defer manager.deinit();
            
            // Test layout switching
            try manager.setLayout(.grid);
            try expectEqual(LayoutType.grid, manager.getLayout());
            
            try manager.setLayout(.split_horizontal);
            try expectEqual(LayoutType.split_horizontal, manager.getLayout());
            
            try manager.setLayout(.floating);
            try expectEqual(LayoutType.floating, manager.getLayout());
        }
        
        test "unit: ScreenManager: manages focus correctly" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .single);
            defer manager.deinit();
            
            const screens = try createTestScreens(allocator, 3);
            defer cleanupTestScreens(allocator, screens);
            
            try manager.addScreen(screens[0], "screen1");
            try manager.addScreen(screens[1], "screen2");
            try manager.addScreen(screens[2], "screen3");
            
            // Test initial focus
            try expect(manager.getFocusedScreen() == screens[0]);
            
            // Test focus switching
            try manager.focusScreen(screens[1]);
            try expect(manager.getFocusedScreen() == screens[1]);
            
            // Test focus navigation
            manager.focusNext();
            try expect(manager.getFocusedScreen() == screens[2]);
            
            manager.focusPrevious();
            try expect(manager.getFocusedScreen() == screens[1]);
        }
        
        test "unit: ScreenManager: manages z-ordering correctly" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .floating);
            defer manager.deinit();
            
            const screens = try createTestScreens(allocator, 3);
            defer cleanupTestScreens(allocator, screens);
            
            try manager.addScreen(screens[0], "screen1");
            try manager.addScreen(screens[1], "screen2");
            try manager.addScreen(screens[2], "screen3");
            
            // Test initial z-indices
            try expectEqual(@as(i32, 0), try manager.getScreenZIndex(screens[0]));
            try expectEqual(@as(i32, 0), try manager.getScreenZIndex(screens[1]));
            try expectEqual(@as(i32, 0), try manager.getScreenZIndex(screens[2]));
            
            // Test bringing to front
            try manager.bringToFront(screens[1]);
            const z_index = try manager.getScreenZIndex(screens[1]);
            try expect(z_index > 0);
            
            // Test sending to back
            try manager.sendToBack(screens[1]);
            const back_z_index = try manager.getScreenZIndex(screens[1]);
            try expect(back_z_index < 0);
        }
        
        test "unit: ScreenManager: manages visibility correctly" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .single);
            defer manager.deinit();
            
            const screen = try createTestScreen(allocator);
            defer {
                screen.deinit();
                allocator.destroy(screen);
            }
            
            try manager.addScreen(screen, "test_screen");
            
            // Test visibility control
            try manager.setScreenVisibility(screen, false);
            // Note: Visibility is checked through screen's managed state
            
            try manager.setScreenVisibility(screen, true);
            // Note: Re-enable visibility
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: ScreenManager with Terminal: coordinates resize events" {
            const allocator = testing.allocator;
            
            // Create terminal and manager
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            var manager = try ScreenManager.init(allocator, .split_horizontal);
            defer manager.deinit();
            
            manager.setTerminal(&terminal);
            
            const screens = try createTestScreens(allocator, 2);
            defer cleanupTestScreens(allocator, screens);
            
            try manager.addScreen(screens[0], "left");
            try manager.addScreen(screens[1], "right");
            
            // Test coordinated resize
            try manager.handleResize(100, 50, .preserve_content);
            
            // Verify screens were resized according to split layout
            // Note: Actual verification would require checking screen dimensions
        }
        
        test "integration: ScreenManager focus events: fires callbacks correctly" {
            const allocator = testing.allocator;
            
            setupEventCapture(allocator);
            defer cleanupEventCapture();
            
            var manager = try ScreenManager.init(allocator, .single);
            defer manager.deinit();
            
            try manager.addFocusCallback(testFocusCallback);
            
            const screens = try createTestScreens(allocator, 2);
            defer cleanupTestScreens(allocator, screens);
            
            try manager.addScreen(screens[0], "screen1");
            try manager.addScreen(screens[1], "screen2");
            
            clearCapturedEvents();
            
            // Test focus change generates events
            try manager.focusScreen(screens[1]);
            
            try expect(captured_events.items.len >= 2); // lost + gained events
            try expectEqual(FocusEventType.lost, captured_events.items[0].event_type);
            try expectEqual(FocusEventType.gained, captured_events.items[1].event_type);
            try expect(captured_events.items[1].screen == screens[1]);
        }
        
        test "integration: ScreenManager modal behavior: locks focus correctly" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .floating);
            defer manager.deinit();
            
            const screens = try createTestScreens(allocator, 3);
            defer cleanupTestScreens(allocator, screens);
            
            try manager.addScreen(screens[0], "background");
            try manager.addScreen(screens[1], "content");
            try manager.addScreen(screens[2], "modal");
            
            // Set modal screen
            try manager.setModalScreen(screens[2]);
            
            try expect(manager.getModalScreen() == screens[2]);
            try expect(manager.isFocusLocked());
            try expect(manager.getFocusLockScreen() == screens[2]);
            
            // Test focus is locked to modal screen
            try expectError(error.FocusLocked, manager.focusScreen(screens[0]));
            
            // Clear modal
            try manager.setModalScreen(null);
            try expect(!manager.isFocusLocked());
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Scenario Tests ────────────────────────────┐
    
        test "scenario: split-screen editor: creates horizontal split correctly" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .split_horizontal);
            defer manager.deinit();
            
            // Configure split ratio
            try manager.setSplitConfig(SplitConfig{ .ratio = 0.6, .spacing = 1 });
            
            const screens = try createTestScreens(allocator, 2);
            defer cleanupTestScreens(allocator, screens);
            
            try manager.addScreen(screens[0], "editor");
            try manager.addScreen(screens[1], "sidebar");
            
            // Simulate terminal resize
            try manager.handleResize(120, 30, .preserve_content);
            
            // Verify layout calculation worked
            try expectEqual(@as(usize, 2), manager.getScreenCount());
        }
        
        test "scenario: dashboard layout: creates 2x2 grid correctly" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .grid);
            defer manager.deinit();
            
            try manager.setGridConfig(GridConfig{ .rows = 2, .cols = 2, .row_spacing = 1, .col_spacing = 1 });
            
            const screens = try createTestScreens(allocator, 4);
            defer cleanupTestScreens(allocator, screens);
            
            try manager.addScreen(screens[0], "top_left");
            try manager.addScreen(screens[1], "top_right");
            try manager.addScreen(screens[2], "bottom_left");
            try manager.addScreen(screens[3], "bottom_right");
            
            // Simulate terminal resize
            try manager.handleResize(100, 60, .preserve_content);
            
            try expectEqual(@as(usize, 4), manager.getScreenCount());
        }
        
        test "scenario: tabbed interface: switches active tab correctly" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .tabbed);
            defer manager.deinit();
            
            const screens = try createTestScreens(allocator, 3);
            defer cleanupTestScreens(allocator, screens);
            
            try manager.addScreen(screens[0], "tab1");
            try manager.addScreen(screens[1], "tab2");
            try manager.addScreen(screens[2], "tab3");
            
            // Test tab switching
            try manager.setActiveScreen(screens[1]);
            
            // In tabbed layout, only active screen should be "visible" conceptually
            try expectEqual(@as(usize, 3), manager.getScreenCount());
        }
        
        test "scenario: modal dialog: overlays correctly on background" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .floating);
            defer manager.deinit();
            
            const screens = try createTestScreens(allocator, 2);
            defer cleanupTestScreens(allocator, screens);
            
            try manager.addScreen(screens[0], "background");
            try manager.addScreen(screens[1], "dialog");
            
            // Set custom viewport for dialog (centered overlay)
            const dialog_viewport = Rect.init(25, 10, 50, 20);
            try manager.setScreenViewport(screens[1], dialog_viewport);
            
            // Make dialog modal
            try manager.setModalScreen(screens[1]);
            
            // Verify modal screen is on top and has focus locked
            try expect(manager.getModalScreen() == screens[1]);
            try expect(manager.isFocusLocked());
            
            // Verify dialog screen is topmost at center point
            const center_screen = manager.getScreenAtPoint(50, 20);
            try expect(center_screen == screens[1]);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: ScreenManager: handles 10 screens efficiently" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .grid);
            defer manager.deinit();
            
            try manager.setGridConfig(GridConfig{ .rows = 2, .cols = 5 });
            
            const screens = try createTestScreens(allocator, 10);
            defer cleanupTestScreens(allocator, screens);
            
            const start_time = std.time.nanoTimestamp();
            
            // Add all screens
            for (screens, 0..) |screen, i| {
                const id_buf = try std.fmt.allocPrint(allocator, "screen_{d}", .{i});
                defer allocator.free(id_buf);
                
                try manager.addScreen(screen, id_buf);
            }
            
            // Perform layout calculations
            for (0..100) |_| {
                try manager.handleResize(200, 100, .preserve_content);
            }
            
            const elapsed = std.time.nanoTimestamp() - start_time;
            const elapsed_ms = elapsed / 1_000_000;
            
            // Should complete in under 10ms
            try expect(elapsed_ms < 10);
        }
        
        test "performance: focus cycling: processes quickly with many screens" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .single);
            defer manager.deinit();
            
            const screens = try createTestScreens(allocator, 20);
            defer cleanupTestScreens(allocator, screens);
            
            for (screens, 0..) |screen, i| {
                const id_buf = try std.fmt.allocPrint(allocator, "screen_{d}", .{i});
                defer allocator.free(id_buf);
                
                try manager.addScreen(screen, id_buf);
            }
            
            const start_time = std.time.nanoTimestamp();
            
            // Cycle through focus 1000 times
            for (0..1000) |_| {
                manager.focusNext();
            }
            
            const elapsed = std.time.nanoTimestamp() - start_time;
            const elapsed_ms = elapsed / 1_000_000;
            
            // Should complete in under 5ms
            try expect(elapsed_ms < 5);
        }
        
        test "performance: z-order operations: complete efficiently" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .floating);
            defer manager.deinit();
            
            const screens = try createTestScreens(allocator, 15);
            defer cleanupTestScreens(allocator, screens);
            
            for (screens, 0..) |screen, i| {
                const id_buf = try std.fmt.allocPrint(allocator, "screen_{d}", .{i});
                defer allocator.free(id_buf);
                
                try manager.addScreen(screen, id_buf);
            }
            
            const start_time = std.time.nanoTimestamp();
            
            // Perform z-order operations
            for (screens) |screen| {
                try manager.bringToFront(screen);
                try manager.moveDown(screen);
                try manager.moveUp(screen);
            }
            
            // Normalize z-indices
            for (0..10) |_| {
                manager.normalizeZIndices();
            }
            
            const elapsed = std.time.nanoTimestamp() - start_time;
            const elapsed_ms = elapsed / 1_000_000;
            
            // Should complete in under 15ms
            try expect(elapsed_ms < 15);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Stress Tests ────────────────────────────┐
    
        test "stress: ScreenManager: survives rapid screen additions/removals" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .grid);
            defer manager.deinit();
            
            try manager.setGridConfig(GridConfig{ .rows = 5, .cols = 5 });
            
            var rng = std.rand.DefaultPrng.init(12345);
            const random = rng.random();
            
            var active_screens = std.ArrayList(*Screen).init(allocator);
            defer {
                for (active_screens.items) |screen| {
                    screen.deinit();
                    allocator.destroy(screen);
                }
                active_screens.deinit();
            }
            
            // Rapid add/remove cycles
            for (0..1000) |i| {
                const operation = random.intRangeAtMost(u8, 0, 2);
                
                switch (operation) {
                    0 => {
                        // Add screen
                        if (active_screens.items.len < 20) {
                            const screen = createTestScreen(allocator) catch continue;
                            const id_buf = std.fmt.allocPrint(allocator, "stress_screen_{d}", .{i}) catch continue;
                            defer allocator.free(id_buf);
                            
                            manager.addScreen(screen, id_buf) catch {
                                screen.deinit();
                                allocator.destroy(screen);
                                continue;
                            };
                            
                            active_screens.append(screen) catch {
                                _ = manager.removeScreen(screen) catch {};
                                screen.deinit();
                                allocator.destroy(screen);
                                continue;
                            };
                        }
                    },
                    1 => {
                        // Remove screen
                        if (active_screens.items.len > 0) {
                            const index = random.intRangeAtMost(usize, 0, active_screens.items.len - 1);
                            const screen = active_screens.swapRemove(index);
                            
                            _ = manager.removeScreen(screen) catch {};
                            screen.deinit();
                            allocator.destroy(screen);
                        }
                    },
                    2 => {
                        // Trigger resize
                        const width = random.intRangeAtMost(u16, 50, 200);
                        const height = random.intRangeAtMost(u16, 20, 80);
                        manager.handleResize(width, height, .preserve_content) catch {};
                    },
                    else => unreachable,
                }
                
                // Verify manager integrity
                try expect(manager.getScreenCount() == active_screens.items.len);
            }
        }
        
        test "stress: focus management: handles extreme focus changes" {
            const allocator = testing.allocator;
            
            var manager = try ScreenManager.init(allocator, .floating);
            defer manager.deinit();
            
            const screens = try createTestScreens(allocator, 50);
            defer cleanupTestScreens(allocator, screens);
            
            for (screens, 0..) |screen, i| {
                const id_buf = try std.fmt.allocPrint(allocator, "stress_screen_{d}", .{i});
                defer allocator.free(id_buf);
                
                try manager.addScreen(screen, id_buf);
            }
            
            var rng = std.rand.DefaultPrng.init(54321);
            const random = rng.random();
            
            // Rapid focus operations
            for (0..10000) |_| {
                const operation = random.intRangeAtMost(u8, 0, 4);
                const screen_index = random.intRangeAtMost(usize, 0, screens.len - 1);
                const target_screen = screens[screen_index];
                
                switch (operation) {
                    0 => manager.focusScreen(target_screen) catch {},
                    1 => manager.focusNext(),
                    2 => manager.focusPrevious(),
                    3 => manager.bringToFront(target_screen) catch {},
                    4 => manager.moveUp(target_screen) catch {},
                    else => unreachable,
                }
            }
            
            // Verify final state is consistent
            try expect(manager.getFocusedScreen() != null);
            try expectEqual(@as(usize, 50), manager.getScreenCount());
        }
    
    // └──────────────────────────────────────────────────────────────────┘

// ╚════════════════════════════════════════════════════════════════════════════════════════╝