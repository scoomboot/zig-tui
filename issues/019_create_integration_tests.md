# Issue #019: Create integration tests

## Summary
Implement comprehensive integration tests that validate the interaction between all core TUI modules.

## Description
Create integration tests that verify the complete TUI system works correctly when all components are combined. Tests should cover terminal initialization with screen rendering, event processing with screen updates, and complete application lifecycle scenarios.

## Acceptance Criteria
- [ ] Create integration test suite
- [ ] Test terminal + screen integration
- [ ] Test event + screen updates
- [ ] Test complete render pipeline
- [ ] Test resize handling across modules
- [ ] Test error propagation
- [ ] Test resource cleanup
- [ ] Test cross-module state consistency
- [ ] Create example mini-applications
- [ ] Follow MCS test categorization
- [ ] Document integration patterns

## Dependencies
- Issue #016 (Create terminal tests)
- Issue #017 (Create screen tests)
- Issue #018 (Create event tests)

## Implementation Notes
```zig
// integration_tests.zig — Cross-module integration tests
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const tui = @import("../tui.zig");
    const Terminal = @import("../terminal/terminal.zig").Terminal;
    const Screen = @import("../screen/screen.zig").Screen;
    const EventLoop = @import("../event/event.zig").EventLoop;
    const Event = @import("../event/event.zig").Event;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test application structure
    const TestApp = struct {
        allocator: std.mem.Allocator,
        terminal: Terminal,
        screen: Screen,
        event_loop: EventLoop,
        running: bool,
        render_count: u32,
        event_count: u32,
        
        pub fn init(allocator: std.mem.Allocator) !TestApp {
            var terminal = try Terminal.init(allocator);
            errdefer terminal.deinit();
            
            const size = try terminal.getSize();
            var screen = try Screen.init(allocator, size.cols, size.rows);
            errdefer screen.deinit();
            
            var event_loop = try EventLoop.init(allocator, .{
                .mode = .polling,
            });
            errdefer event_loop.deinit();
            
            return TestApp{
                .allocator = allocator,
                .terminal = terminal,
                .screen = screen,
                .event_loop = event_loop,
                .running = false,
                .render_count = 0,
                .event_count = 0,
            };
        }
        
        pub fn deinit(self: *TestApp) void {
            self.event_loop.deinit();
            self.screen.deinit();
            self.terminal.deinit();
        }
        
        pub fn run(self: *TestApp) !void {
            self.running = true;
            
            try self.terminal.enterRawMode();
            defer self.terminal.exitRawMode() catch {};
            
            try self.terminal.enterAltScreen();
            defer self.terminal.exitAltScreen() catch {};
            
            // Register event handler
            try self.event_loop.addHandler(
                .{ .type_mask = .{ .key = true } },
                handleEvent,
                self,
            );
            
            // Run for a few frames
            var frames: u32 = 0;
            while (frames < 5 and self.running) : (frames += 1) {
                // Process events
                _ = try self.event_loop.step();
                
                // Render
                try self.render();
                
                // Small delay
                std.time.sleep(10 * std.time.ns_per_ms);
            }
        }
        
        fn handleEvent(event: Event, context: *anyopaque) void {
            const app = @ptrCast(*TestApp, @alignCast(@alignOf(TestApp), context));
            app.event_count += 1;
            
            switch (event) {
                .key => |key| {
                    if (key.isChar('q')) {
                        app.running = false;
                    }
                },
                else => {},
            }
        }
        
        fn render(self: *TestApp) !void {
            try self.screen.render(&self.terminal);
            self.render_count += 1;
        }
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Basic Integration ────────────────────────────┐

        test "integration: TUI: complete initialization" {
            const allocator = testing.allocator;
            
            const tui_instance = try tui.init(allocator);
            defer {
                tui_instance.terminal.deinit();
                tui_instance.screen.deinit();
                tui_instance.events.deinit();
            }
            
            // All components should be initialized
            try testing.expect(tui_instance.terminal.size.rows > 0);
            try testing.expect(tui_instance.screen.width > 0);
            try testing.expect(tui_instance.events.queue.isEmpty());
        }

        test "integration: Terminal+Screen: rendering pipeline" {
            const allocator = testing.allocator;
            
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            var screen = try Screen.init(allocator, 40, 10);
            defer screen.deinit();
            
            // Draw something
            try screen.writeText(5, 5, "Hello TUI", .{
                .fg = tui.Color.green,
                .bg = tui.Color.blue,
            });
            
            // Render to terminal
            try screen.render(&terminal);
            
            // Screen should have rendered
            try testing.expect(screen.render_stats.frames_rendered > 0);
        }

        test "integration: Event+Screen: interactive updates" {
            const allocator = testing.allocator;
            
            var screen = try Screen.init(allocator, 40, 10);
            defer screen.deinit();
            
            var event_loop = try EventLoop.init(allocator, .{});
            defer event_loop.deinit();
            
            var cursor_x: u16 = 0;
            var cursor_y: u16 = 0;
            
            // Handler that updates screen based on keys
            const Context = struct {
                screen: *Screen,
                x: *u16,
                y: *u16,
            };
            
            var ctx = Context{
                .screen = &screen,
                .x = &cursor_x,
                .y = &cursor_y,
            };
            
            try event_loop.addHandler(
                .{ .type_mask = .{ .key = true } },
                struct {
                    fn handle(event: Event, context: *anyopaque) void {
                        const c = @ptrCast(*Context, @alignCast(@alignOf(Context), context));
                        
                        switch (event) {
                            .key => |key| switch (key.code) {
                                .special => |s| switch (s) {
                                    .arrow_right => c.x.* = @min(c.x.* + 1, c.screen.width - 1),
                                    .arrow_left => c.x.* = if (c.x.* > 0) c.x.* - 1 else 0,
                                    .arrow_down => c.y.* = @min(c.y.* + 1, c.screen.height - 1),
                                    .arrow_up => c.y.* = if (c.y.* > 0) c.y.* - 1 else 0,
                                    else => {},
                                },
                                else => {},
                            },
                            else => {},
                        }
                        
                        // Update screen
                        c.screen.setCell(c.x.*, c.y.*, Cell.init('*', null, null, null)) catch {};
                    }
                }.handle,
                &ctx,
            );
            
            // Simulate arrow key events
            try event_loop.queue.push(.{
                .key = .{
                    .code = .{ .special = .arrow_right },
                    .modifiers = .{},
                    .timestamp = std.time.milliTimestamp(),
                },
            });
            
            _ = try event_loop.step();
            
            try testing.expectEqual(@as(u16, 1), cursor_x);
            try testing.expect(screen.getCell(1, 0).?.isChar('*'));
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Application Lifecycle ────────────────────────────┐

        test "integration: App: complete lifecycle" {
            if (true) return error.SkipZigTest; // Skip in CI
            
            const allocator = testing.allocator;
            
            var app = try TestApp.init(allocator);
            defer app.deinit();
            
            try app.run();
            
            // App should have rendered frames
            try testing.expect(app.render_count > 0);
        }

        test "integration: App: clean shutdown" {
            const allocator = testing.allocator;
            
            var app = try TestApp.init(allocator);
            
            // Simulate quit event
            try app.event_loop.queue.push(.{
                .key = .{
                    .code = .{ .char = 'q' },
                    .modifiers = .{},
                    .timestamp = std.time.milliTimestamp(),
                },
            });
            
            // Process event
            _ = try app.event_loop.step();
            TestApp.handleEvent(
                try app.event_loop.queue.tryPop() orelse unreachable,
                &app,
            );
            
            try testing.expect(!app.running);
            
            app.deinit();
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Resize Handling ────────────────────────────┐

        test "integration: Resize: coordinated resize" {
            const allocator = testing.allocator;
            
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            var screen = try Screen.init(allocator, 80, 24);
            defer screen.deinit();
            
            var event_loop = try EventLoop.init(allocator, .{});
            defer event_loop.deinit();
            
            // Add content
            try screen.writeText(10, 10, "Before resize", .{});
            
            // Simulate resize event
            const new_size = Terminal.Size{ .rows = 40, .cols = 120 };
            
            try event_loop.queue.push(.{
                .resize = .{
                    .width = new_size.cols,
                    .height = new_size.rows,
                    .timestamp = std.time.milliTimestamp(),
                },
            });
            
            // Handle resize
            if (event_loop.queue.tryPop()) |event| {
                switch (event) {
                    .resize => |resize| {
                        try screen.resize(resize.width, resize.height);
                        terminal.size = new_size;
                    },
                    else => {},
                }
            }
            
            try testing.expectEqual(@as(u16, 120), screen.width);
            try testing.expectEqual(@as(u16, 40), screen.height);
            
            // Content should be preserved
            try testing.expect(screen.getCell(10, 10).?.isChar('B'));
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Error Handling ────────────────────────────┐

        test "integration: Error: propagation across modules" {
            const allocator = testing.allocator;
            
            // Try to create screen with invalid size
            try testing.expectError(
                error.InvalidDimensions,
                Screen.init(allocator, 0, 0)
            );
            
            // Terminal should handle non-TTY gracefully
            // (This would need mock terminal for proper testing)
        }

        test "integration: Error: resource cleanup on failure" {
            const allocator = testing.allocator;
            
            // Use failing allocator to test cleanup
            var failing_allocator = testing.FailingAllocator.init(allocator, .{
                .fail_index = 5, // Fail on 5th allocation
            });
            
            // Should clean up partial initialization
            const result = TestApp.init(failing_allocator.allocator());
            try testing.expectError(error.OutOfMemory, result);
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Complex Scenarios ────────────────────────────┐

        test "integration: Scenario: text editor simulation" {
            const allocator = testing.allocator;
            
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            var screen = try Screen.init(allocator, 80, 24);
            defer screen.deinit();
            
            // Draw editor UI
            try drawEditorUI(&screen);
            
            // Add some text
            const text = "Hello, TUI Editor!";
            try screen.writeText(1, 2, text, .{});
            
            // Draw status line
            try screen.drawHLine(0, 22, 80, '─', .{});
            try screen.writeText(1, 23, "test.txt - 1 line", .{});
            
            // Render
            try screen.render(&terminal);
            
            // Verify UI elements
            try testing.expect(screen.getCell(0, 0).?.isChar('┌'));
            try testing.expect(screen.getCell(79, 0).?.isChar('┐'));
            try testing.expect(screen.getCell(5, 2).?.isChar(','));
        }

        fn drawEditorUI(screen: *Screen) !void {
            const width = screen.width;
            const height = screen.height;
            
            // Draw border
            try screen.drawHLine(0, 0, width, '─', .{});
            try screen.drawHLine(0, height - 2, width, '─', .{});
            try screen.drawVLine(0, 0, height - 1, '│', .{});
            try screen.drawVLine(width - 1, 0, height - 1, '│', .{});
            
            // Corners
            try screen.setCell(0, 0, Cell.init('┌', null, null, null));
            try screen.setCell(width - 1, 0, Cell.init('┐', null, null, null));
            try screen.setCell(0, height - 2, Cell.init('└', null, null, null));
            try screen.setCell(width - 1, height - 2, Cell.init('┘', null, null, null));
        }

        test "integration: Scenario: menu navigation" {
            const allocator = testing.allocator;
            
            var screen = try Screen.init(allocator, 40, 10);
            defer screen.deinit();
            
            var event_loop = try EventLoop.init(allocator, .{});
            defer event_loop.deinit();
            
            // Menu items
            const menu_items = [_][]const u8{
                "New File",
                "Open File",
                "Save File",
                "Exit",
            };
            
            var selected_index: usize = 0;
            
            // Draw menu
            for (menu_items, 0..) |item, i| {
                const style = if (i == selected_index) Style.bold_only else Style.none;
                const bg = if (i == selected_index) tui.Color.blue else tui.Color.default;
                
                try screen.writeText(2, @intCast(u16, i + 2), item, .{
                    .bg = bg,
                    .style = style,
                });
            }
            
            // Simulate navigation
            try event_loop.queue.push(.{
                .key = .{
                    .code = .{ .special = .arrow_down },
                    .modifiers = .{},
                    .timestamp = std.time.milliTimestamp(),
                },
            });
            
            if (event_loop.queue.tryPop()) |event| {
                switch (event) {
                    .key => |key| {
                        if (key.code == .special and key.code.special == .arrow_down) {
                            selected_index = (selected_index + 1) % menu_items.len;
                        }
                    },
                    else => {},
                }
            }
            
            try testing.expectEqual(@as(usize, 1), selected_index);
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Performance Integration ────────────────────────────┐

        test "performance: Integration: full render cycle" {
            const allocator = testing.allocator;
            
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            var screen = try Screen.init(allocator, 80, 24);
            defer screen.deinit();
            
            // Fill screen with content
            var y: u16 = 0;
            while (y < 24) : (y += 1) {
                const text = "The quick brown fox jumps over the lazy dog. ";
                try screen.writeText(0, y, text ++ text, .{});
            }
            
            const iterations = 100;
            const start = std.time.nanoTimestamp();
            
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                // Make small change
                try screen.setCell(i % 80, i % 24, Cell.init('X', null, null, null));
                
                // Render
                try screen.render(&terminal);
            }
            
            const elapsed = std.time.nanoTimestamp() - start;
            const avg_ms = @divFloor(elapsed, iterations) / std.time.ns_per_ms;
            
            // Should complete full render cycle in less than 16ms
            try testing.expect(avg_ms < 16);
        }

    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Test all module combinations
- Validate state consistency
- Test error propagation
- Test resource management
- Create realistic scenarios
- Measure integrated performance
- Document patterns discovered

## Estimated Time
4 hours

## Priority
🟡 High - System validation

## Category
Testing