// widget.test.zig — Comprehensive tests for widget interface
//
// repo   : https://github.com/fisty/zig-tui
// author : https://github.com/fisty
//
// Tests for widget base interface, rendering, and event handling.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Widget = @import("widget.zig").Widget;
    const Screen = @import("../screen/screen.zig").Screen;
    const Event = @import("../event/event.zig").Event;
    const Rect = @import("../screen/utils/rect/rect.zig").Rect;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test constants
    const DEFAULT_WIDGET_WIDTH = 40;
    const DEFAULT_WIDGET_HEIGHT = 20;
    
    // Test widget implementation
    const TestWidget = struct {
        base: Widget,
        render_count: u32,
        handle_count: u32,
        test_data: []const u8,
        
        pub fn init(allocator: std.mem.Allocator, data: []const u8) !*TestWidget {
            const widget = try allocator.create(TestWidget);
            widget.* = TestWidget{
                .base = Widget{
                    .bounds = Rect{ .x = 0, .y = 0, .width = DEFAULT_WIDGET_WIDTH, .height = DEFAULT_WIDGET_HEIGHT },
                    .visible = true,
                    .focused = false,
                    .vtable = &vtable,
                },
                .render_count = 0,
                .handle_count = 0,
                .test_data = data,
            };
            return widget;
        }
        
        fn render(widget: *Widget, screen: *Screen) !void {
            const self = @fieldParentPtr(TestWidget, "base", widget);
            self.render_count += 1;
            
            // Draw test pattern
            const bounds = widget.bounds;
            for (bounds.y..bounds.y + bounds.height) |y| {
                for (bounds.x..bounds.x + bounds.width) |x| {
                    try screen.setCell(@intCast(x), @intCast(y), .{
                        .char = if (self.test_data.len > 0) self.test_data[0] else 'W',
                        .fg = .white,
                        .bg = .black,
                        .style = .none,
                    });
                }
            }
        }
        
        fn handleEvent(widget: *Widget, event: Event) !bool {
            const self = @fieldParentPtr(TestWidget, "base", widget);
            self.handle_count += 1;
            _ = event;
            return true;
        }
        
        const vtable = Widget.VTable{
            .render = render,
            .handleEvent = handleEvent,
        };
    };
    
    // Helper to create widget tree
    fn createWidgetTree(allocator: std.mem.Allocator) !*Widget {
        const root = try allocator.create(Widget);
        root.* = Widget{
            .bounds = Rect{ .x = 0, .y = 0, .width = 100, .height = 50 },
            .visible = true,
            .focused = true,
            .vtable = null,
        };
        
        root.children = std.ArrayList(*Widget).init(allocator);
        
        // Add child widgets
        for (0..3) |i| {
            const child = try TestWidget.init(allocator, "C");
            child.base.bounds = Rect{
                .x = @intCast(i * 30),
                .y = 10,
                .width = 25,
                .height = 10,
            };
            try root.children.?.append(&child.base);
        }
        
        return root;
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐
    
        test "unit: Widget: initializes with correct default values" {
            const allocator = testing.allocator;
            const widget = try TestWidget.init(allocator, "Test");
            defer allocator.destroy(widget);
            
            try testing.expect(widget.base.visible);
            try testing.expect(!widget.base.focused);
            try testing.expectEqual(@as(u16, DEFAULT_WIDGET_WIDTH), widget.base.bounds.width);
            try testing.expectEqual(@as(u16, DEFAULT_WIDGET_HEIGHT), widget.base.bounds.height);
        }
        
        test "unit: Widget: sets visibility correctly" {
            const allocator = testing.allocator;
            const widget = try TestWidget.init(allocator, "");
            defer allocator.destroy(widget);
            
            widget.base.visible = false;
            try testing.expect(!widget.base.visible);
            
            widget.base.visible = true;
            try testing.expect(widget.base.visible);
        }
        
        test "unit: Widget: sets focus state correctly" {
            const allocator = testing.allocator;
            const widget = try TestWidget.init(allocator, "");
            defer allocator.destroy(widget);
            
            widget.base.focused = true;
            try testing.expect(widget.base.focused);
            
            widget.base.focused = false;
            try testing.expect(!widget.base.focused);
        }
        
        test "unit: Widget: updates bounds correctly" {
            const allocator = testing.allocator;
            const widget = try TestWidget.init(allocator, "");
            defer allocator.destroy(widget);
            
            const new_bounds = Rect{ .x = 10, .y = 20, .width = 30, .height = 40 };
            widget.base.bounds = new_bounds;
            
            try testing.expectEqual(new_bounds.x, widget.base.bounds.x);
            try testing.expectEqual(new_bounds.y, widget.base.bounds.y);
            try testing.expectEqual(new_bounds.width, widget.base.bounds.width);
            try testing.expectEqual(new_bounds.height, widget.base.bounds.height);
        }
        
        test "unit: Widget: checks bounds contains point" {
            const allocator = testing.allocator;
            const widget = try TestWidget.init(allocator, "");
            defer allocator.destroy(widget);
            
            widget.base.bounds = Rect{ .x = 10, .y = 10, .width = 20, .height = 20 };
            
            // Inside bounds
            try testing.expect(widget.base.containsPoint(15, 15));
            try testing.expect(widget.base.containsPoint(10, 10));
            try testing.expect(widget.base.containsPoint(29, 29));
            
            // Outside bounds
            try testing.expect(!widget.base.containsPoint(5, 5));
            try testing.expect(!widget.base.containsPoint(30, 30));
            try testing.expect(!widget.base.containsPoint(100, 100));
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: Widget with Screen: renders correctly" {
            const allocator = testing.allocator;
            const widget = try TestWidget.init(allocator, "R");
            defer allocator.destroy(widget);
            
            var screen = try Screen.init(allocator, 100, 50);
            defer screen.deinit();
            
            // Render widget
            try widget.base.vtable.?.render(&widget.base, &screen);
            
            // Check render was called
            try testing.expectEqual(@as(u32, 1), widget.render_count);
            
            // Verify screen content
            const cell = screen.getCell(0, 0);
            try testing.expectEqual(@as(u32, 'R'), cell.char);
        }
        
        test "integration: Widget with Event: handles events" {
            const allocator = testing.allocator;
            const widget = try TestWidget.init(allocator, "E");
            defer allocator.destroy(widget);
            
            const event = Event{
                .type = .key,
                .data = .{ .key = .{ .key = 'A', .modifiers = 0 } },
            };
            
            // Handle event
            const handled = try widget.base.vtable.?.handleEvent(&widget.base, event);
            
            try testing.expect(handled);
            try testing.expectEqual(@as(u32, 1), widget.handle_count);
        }
        
        test "integration: Widget hierarchy: manages children" {
            const allocator = testing.allocator;
            const root = try createWidgetTree(allocator);
            defer {
                if (root.children) |children| {
                    for (children.items) |child| {
                        allocator.destroy(child);
                    }
                    children.deinit();
                }
                allocator.destroy(root);
            }
            
            // Check children
            try testing.expect(root.children != null);
            try testing.expectEqual(@as(usize, 3), root.children.?.items.len);
            
            // Verify child properties
            for (root.children.?.items, 0..) |child, i| {
                try testing.expectEqual(@as(u16, @intCast(i * 30)), child.bounds.x);
                try testing.expectEqual(@as(u16, 10), child.bounds.y);
            }
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── E2E Tests ────────────────────────────┐
    
        test "e2e: widget rendering pipeline: tree to screen" {
            const allocator = testing.allocator;
            const root = try createWidgetTree(allocator);
            defer {
                if (root.children) |children| {
                    for (children.items) |child| {
                        allocator.destroy(child);
                    }
                    children.deinit();
                }
                allocator.destroy(root);
            }
            
            var screen = try Screen.init(allocator, 100, 50);
            defer screen.deinit();
            
            // Render all widgets
            if (root.children) |children| {
                for (children.items) |child| {
                    if (child.visible and child.vtable != null) {
                        try child.vtable.?.render(child, &screen);
                    }
                }
            }
            
            // Verify rendering occurred
            for (root.children.?.items) |child| {
                const test_widget = @fieldParentPtr(TestWidget, "base", child);
                try testing.expectEqual(@as(u32, 1), test_widget.render_count);
            }
        }
        
        test "e2e: widget event propagation: root to focused" {
            const allocator = testing.allocator;
            const root = try createWidgetTree(allocator);
            defer {
                if (root.children) |children| {
                    for (children.items) |child| {
                        allocator.destroy(child);
                    }
                    children.deinit();
                }
                allocator.destroy(root);
            }
            
            // Focus second child
            if (root.children) |children| {
                children.items[1].focused = true;
            }
            
            const event = Event{
                .type = .key,
                .data = .{ .key = .{ .key = 'F', .modifiers = 0 } },
            };
            
            // Propagate event to focused widget
            if (root.children) |children| {
                for (children.items) |child| {
                    if (child.focused and child.vtable != null) {
                        _ = try child.vtable.?.handleEvent(child, event);
                    }
                }
            }
            
            // Verify only focused widget handled event
            for (root.children.?.items, 0..) |child, i| {
                const test_widget = @fieldParentPtr(TestWidget, "base", child);
                if (i == 1) {
                    try testing.expectEqual(@as(u32, 1), test_widget.handle_count);
                } else {
                    try testing.expectEqual(@as(u32, 0), test_widget.handle_count);
                }
            }
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: Widget.render: renders many widgets efficiently" {
            const allocator = testing.allocator;
            var screen = try Screen.init(allocator, 200, 100);
            defer screen.deinit();
            
            // Create many widgets
            var widgets = std.ArrayList(*TestWidget).init(allocator);
            defer {
                for (widgets.items) |widget| {
                    allocator.destroy(widget);
                }
                widgets.deinit();
            }
            
            for (0..100) |i| {
                const widget = try TestWidget.init(allocator, "P");
                widget.base.bounds = Rect{
                    .x = @intCast((i * 10) % 200),
                    .y = @intCast((i * 5) % 100),
                    .width = 8,
                    .height = 4,
                };
                try widgets.append(widget);
            }
            
            const start = std.time.milliTimestamp();
            
            // Render all widgets
            for (widgets.items) |widget| {
                try widget.base.vtable.?.render(&widget.base, &screen);
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should render 100 widgets quickly
            try testing.expect(elapsed < 100);
        }
        
        test "performance: Widget.handleEvent: processes events quickly" {
            const allocator = testing.allocator;
            const widget = try TestWidget.init(allocator, "E");
            defer allocator.destroy(widget);
            
            const event = Event{
                .type = .key,
                .data = .{ .key = .{ .key = 'T', .modifiers = 0 } },
            };
            
            const iterations = 10000;
            const start = std.time.milliTimestamp();
            
            for (0..iterations) |_| {
                _ = try widget.base.vtable.?.handleEvent(&widget.base, event);
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should handle 10k events quickly
            try testing.expect(elapsed < 100);
            try testing.expectEqual(@as(u32, iterations), widget.handle_count);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Stress Tests ────────────────────────────┐
    
        test "stress: Widget: handles deep widget hierarchy" {
            const allocator = testing.allocator;
            
            // Create deep hierarchy
            var widgets = std.ArrayList(*TestWidget).init(allocator);
            defer {
                for (widgets.items) |widget| {
                    allocator.destroy(widget);
                }
                widgets.deinit();
            }
            
            var parent: ?*Widget = null;
            
            for (0..100) |i| {
                const widget = try TestWidget.init(allocator, "D");
                try widgets.append(widget);
                
                if (parent) |p| {
                    if (p.children == null) {
                        p.children = std.ArrayList(*Widget).init(allocator);
                    }
                    try p.children.?.append(&widget.base);
                }
                
                parent = &widget.base;
            }
            
            // Should handle deep hierarchy
            try testing.expectEqual(@as(usize, 100), widgets.items.len);
        }
        
        test "stress: Widget: survives rapid state changes" {
            const allocator = testing.allocator;
            const widget = try TestWidget.init(allocator, "S");
            defer allocator.destroy(widget);
            
            var prng = std.rand.DefaultPrng.init(11111);
            const random = prng.random();
            
            // Rapid state changes
            for (0..10000) |_| {
                widget.base.visible = random.boolean();
                widget.base.focused = random.boolean();
                widget.base.bounds = Rect{
                    .x = random.intRangeLessThan(u16, 0, 100),
                    .y = random.intRangeLessThan(u16, 0, 100),
                    .width = random.intRangeLessThan(u16, 1, 100),
                    .height = random.intRangeLessThan(u16, 1, 100),
                };
            }
            
            // Widget should remain stable
            try testing.expect(widget.base.bounds.width > 0);
            try testing.expect(widget.base.bounds.height > 0);
        }
    
    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝