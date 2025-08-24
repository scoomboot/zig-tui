// layout.test.zig — Comprehensive tests for layout management
//
// repo   : https://github.com/fisty/zig-tui
// author : https://github.com/fisty
//
// Tests for layout algorithms, constraints, and widget positioning.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Layout = @import("layout.zig").Layout;
    const Widget = @import("../widget/widget.zig").Widget;
    const Rect = @import("../screen/utils/rect/rect.zig").Rect;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test constants
    const DEFAULT_CONTAINER_WIDTH = 100;
    const DEFAULT_CONTAINER_HEIGHT = 50;
    
    // Layout types for testing
    const LayoutType = enum {
        horizontal,
        vertical,
        grid,
        flex,
        absolute,
    };
    
    // Test constraint structure
    const Constraint = struct {
        min_width: ?u16 = null,
        max_width: ?u16 = null,
        min_height: ?u16 = null,
        max_height: ?u16 = null,
        flex: f32 = 1.0,
    };
    
    // Test helpers
    const TestLayout = struct {
        layout: Layout,
        allocator: std.mem.Allocator,
        
        pub fn init(allocator: std.mem.Allocator, layout_type: LayoutType) !TestLayout {
            return TestLayout{
                .layout = try Layout.init(allocator, layout_type),
                .allocator = allocator,
            };
        }
        
        pub fn deinit(self: *TestLayout) void {
            self.layout.deinit();
        }
    };
    
    // Creates a test widget with constraints
    fn createTestWidget(allocator: std.mem.Allocator, constraint: Constraint) !*Widget {
        const widget = try allocator.create(Widget);
        widget.* = Widget{
            .bounds = Rect{ .x = 0, .y = 0, .width = 10, .height = 10 },
            .visible = true,
            .focused = false,
            .vtable = null,
            .constraint = constraint,
        };
        return widget;
    }
    
    // Creates a container with children
    fn createContainer(allocator: std.mem.Allocator, child_count: usize) !*Widget {
        const container = try allocator.create(Widget);
        container.* = Widget{
            .bounds = Rect{ .x = 0, .y = 0, .width = DEFAULT_CONTAINER_WIDTH, .height = DEFAULT_CONTAINER_HEIGHT },
            .visible = true,
            .focused = false,
            .vtable = null,
        };
        
        container.children = std.ArrayList(*Widget).init(allocator);
        
        for (0..child_count) |_| {
            const child = try createTestWidget(allocator, .{});
            try container.children.?.append(child);
        }
        
        return container;
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐
    
        test "unit: Layout: initializes with correct type" {
            const allocator = testing.allocator;
            var layout = try Layout.init(allocator, .horizontal);
            defer layout.deinit();
            
            try testing.expectEqual(LayoutType.horizontal, layout.type);
        }
        
        test "unit: Layout: calculates horizontal layout correctly" {
            const allocator = testing.allocator;
            var layout = try Layout.init(allocator, .horizontal);
            defer layout.deinit();
            
            const container = try createContainer(allocator, 3);
            defer {
                if (container.children) |children| {
                    for (children.items) |child| {
                        allocator.destroy(child);
                    }
                    children.deinit();
                }
                allocator.destroy(container);
            }
            
            try layout.apply(container);
            
            // Children should be arranged horizontally
            const children = container.children.?.items;
            for (children, 0..) |child, i| {
                const expected_x = @as(u16, @intCast(i * (DEFAULT_CONTAINER_WIDTH / 3)));
                try testing.expectEqual(expected_x, child.bounds.x);
                try testing.expectEqual(@as(u16, 0), child.bounds.y);
            }
        }
        
        test "unit: Layout: calculates vertical layout correctly" {
            const allocator = testing.allocator;
            var layout = try Layout.init(allocator, .vertical);
            defer layout.deinit();
            
            const container = try createContainer(allocator, 3);
            defer {
                if (container.children) |children| {
                    for (children.items) |child| {
                        allocator.destroy(child);
                    }
                    children.deinit();
                }
                allocator.destroy(container);
            }
            
            try layout.apply(container);
            
            // Children should be arranged vertically
            const children = container.children.?.items;
            for (children, 0..) |child, i| {
                try testing.expectEqual(@as(u16, 0), child.bounds.x);
                const expected_y = @as(u16, @intCast(i * (DEFAULT_CONTAINER_HEIGHT / 3)));
                try testing.expectEqual(expected_y, child.bounds.y);
            }
        }
        
        test "unit: Layout: applies constraints correctly" {
            const allocator = testing.allocator;
            var layout = try Layout.init(allocator, .horizontal);
            defer layout.deinit();
            
            const container = try allocator.create(Widget);
            defer allocator.destroy(container);
            container.* = Widget{
                .bounds = Rect{ .x = 0, .y = 0, .width = 100, .height = 50 },
                .visible = true,
                .focused = false,
                .vtable = null,
            };
            
            container.children = std.ArrayList(*Widget).init(allocator);
            defer container.children.?.deinit();
            
            // Add child with constraints
            const child = try createTestWidget(allocator, .{
                .min_width = 20,
                .max_width = 40,
                .min_height = 10,
                .max_height = 30,
            });
            defer allocator.destroy(child);
            try container.children.?.append(child);
            
            try layout.apply(container);
            
            // Verify constraints are respected
            try testing.expect(child.bounds.width >= 20);
            try testing.expect(child.bounds.width <= 40);
            try testing.expect(child.bounds.height >= 10);
            try testing.expect(child.bounds.height <= 30);
        }
        
        test "unit: Layout: handles empty container" {
            const allocator = testing.allocator;
            var layout = try Layout.init(allocator, .horizontal);
            defer layout.deinit();
            
            const container = try allocator.create(Widget);
            defer allocator.destroy(container);
            container.* = Widget{
                .bounds = Rect{ .x = 0, .y = 0, .width = 100, .height = 50 },
                .visible = true,
                .focused = false,
                .vtable = null,
            };
            
            // No children
            container.children = std.ArrayList(*Widget).init(allocator);
            defer container.children.?.deinit();
            
            // Should not error on empty container
            try layout.apply(container);
            try testing.expectEqual(@as(usize, 0), container.children.?.items.len);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: Layout with flex weights: distributes space" {
            const allocator = testing.allocator;
            var layout = try Layout.init(allocator, .horizontal);
            defer layout.deinit();
            
            const container = try allocator.create(Widget);
            defer allocator.destroy(container);
            container.* = Widget{
                .bounds = Rect{ .x = 0, .y = 0, .width = 100, .height = 50 },
                .visible = true,
                .focused = false,
                .vtable = null,
            };
            
            container.children = std.ArrayList(*Widget).init(allocator);
            defer container.children.?.deinit();
            
            // Add children with different flex weights
            const child1 = try createTestWidget(allocator, .{ .flex = 1.0 });
            const child2 = try createTestWidget(allocator, .{ .flex = 2.0 });
            const child3 = try createTestWidget(allocator, .{ .flex = 1.0 });
            defer {
                allocator.destroy(child1);
                allocator.destroy(child2);
                allocator.destroy(child3);
            }
            
            try container.children.?.append(child1);
            try container.children.?.append(child2);
            try container.children.?.append(child3);
            
            try layout.apply(container);
            
            // Child2 should have twice the width of child1 and child3
            try testing.expectEqual(@as(u16, 25), child1.bounds.width);
            try testing.expectEqual(@as(u16, 50), child2.bounds.width);
            try testing.expectEqual(@as(u16, 25), child3.bounds.width);
        }
        
        test "integration: Grid layout: arranges in grid pattern" {
            const allocator = testing.allocator;
            var layout = try Layout.init(allocator, .grid);
            defer layout.deinit();
            
            layout.columns = 3;
            layout.rows = 2;
            
            const container = try createContainer(allocator, 6);
            defer {
                if (container.children) |children| {
                    for (children.items) |child| {
                        allocator.destroy(child);
                    }
                    children.deinit();
                }
                allocator.destroy(container);
            }
            
            try layout.apply(container);
            
            // Verify grid arrangement
            const children = container.children.?.items;
            const cell_width = DEFAULT_CONTAINER_WIDTH / 3;
            const cell_height = DEFAULT_CONTAINER_HEIGHT / 2;
            
            for (children, 0..) |child, i| {
                const col = i % 3;
                const row = i / 3;
                
                const expected_x = @as(u16, @intCast(col * cell_width));
                const expected_y = @as(u16, @intCast(row * cell_height));
                
                try testing.expectEqual(expected_x, child.bounds.x);
                try testing.expectEqual(expected_y, child.bounds.y);
            }
        }
        
        test "integration: Nested layouts: handles hierarchy" {
            const allocator = testing.allocator;
            
            // Create main container with vertical layout
            const main = try createContainer(allocator, 2);
            defer {
                if (main.children) |children| {
                    for (children.items) |child| {
                        if (child.children) |subchildren| {
                            for (subchildren.items) |subchild| {
                                allocator.destroy(subchild);
                            }
                            subchildren.deinit();
                        }
                        allocator.destroy(child);
                    }
                    children.deinit();
                }
                allocator.destroy(main);
            }
            
            var vertical_layout = try Layout.init(allocator, .vertical);
            defer vertical_layout.deinit();
            
            // First child is a horizontal container
            const first_child = main.children.?.items[0];
            first_child.children = std.ArrayList(*Widget).init(allocator);
            for (0..3) |_| {
                const subchild = try createTestWidget(allocator, .{});
                try first_child.children.?.append(subchild);
            }
            
            var horizontal_layout = try Layout.init(allocator, .horizontal);
            defer horizontal_layout.deinit();
            
            // Apply layouts
            try vertical_layout.apply(main);
            try horizontal_layout.apply(first_child);
            
            // Verify nested layout applied correctly
            try testing.expect(first_child.children != null);
            try testing.expectEqual(@as(usize, 3), first_child.children.?.items.len);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── E2E Tests ────────────────────────────┐
    
        test "e2e: complete layout system: complex UI arrangement" {
            const allocator = testing.allocator;
            
            // Create UI structure: header, body (with sidebar and content), footer
            const root = try allocator.create(Widget);
            defer allocator.destroy(root);
            root.* = Widget{
                .bounds = Rect{ .x = 0, .y = 0, .width = 200, .height = 100 },
                .visible = true,
                .focused = false,
                .vtable = null,
            };
            
            root.children = std.ArrayList(*Widget).init(allocator);
            defer root.children.?.deinit();
            
            // Header (height: 10)
            const header = try createTestWidget(allocator, .{ .min_height = 10, .max_height = 10 });
            defer allocator.destroy(header);
            
            // Body container
            const body = try allocator.create(Widget);
            defer allocator.destroy(body);
            body.* = Widget{
                .bounds = Rect{ .x = 0, .y = 0, .width = 200, .height = 80 },
                .visible = true,
                .focused = false,
                .vtable = null,
            };
            body.children = std.ArrayList(*Widget).init(allocator);
            defer body.children.?.deinit();
            
            // Sidebar (width: 50)
            const sidebar = try createTestWidget(allocator, .{ .min_width = 50, .max_width = 50 });
            defer allocator.destroy(sidebar);
            
            // Content (remaining space)
            const content = try createTestWidget(allocator, .{ .flex = 1.0 });
            defer allocator.destroy(content);
            
            // Footer (height: 10)
            const footer = try createTestWidget(allocator, .{ .min_height = 10, .max_height = 10 });
            defer allocator.destroy(footer);
            
            // Build hierarchy
            try root.children.?.append(header);
            try root.children.?.append(body);
            try root.children.?.append(footer);
            
            try body.children.?.append(sidebar);
            try body.children.?.append(content);
            
            // Apply layouts
            var vertical_layout = try Layout.init(allocator, .vertical);
            defer vertical_layout.deinit();
            var horizontal_layout = try Layout.init(allocator, .horizontal);
            defer horizontal_layout.deinit();
            
            try vertical_layout.apply(root);
            try horizontal_layout.apply(body);
            
            // Verify layout results
            try testing.expectEqual(@as(u16, 10), header.bounds.height);
            try testing.expectEqual(@as(u16, 80), body.bounds.height);
            try testing.expectEqual(@as(u16, 10), footer.bounds.height);
            try testing.expectEqual(@as(u16, 50), sidebar.bounds.width);
            try testing.expectEqual(@as(u16, 150), content.bounds.width);
        }
        
        test "e2e: responsive layout: adapts to container resize" {
            const allocator = testing.allocator;
            var layout = try Layout.init(allocator, .flex);
            defer layout.deinit();
            
            const container = try createContainer(allocator, 3);
            defer {
                if (container.children) |children| {
                    for (children.items) |child| {
                        allocator.destroy(child);
                    }
                    children.deinit();
                }
                allocator.destroy(container);
            }
            
            // Initial layout
            try layout.apply(container);
            
            // Store initial positions
            var initial_widths: [3]u16 = undefined;
            for (container.children.?.items, 0..) |child, i| {
                initial_widths[i] = child.bounds.width;
            }
            
            // Resize container
            container.bounds.width = 200;
            container.bounds.height = 100;
            
            // Re-apply layout
            try layout.apply(container);
            
            // Verify children adapted to new size
            for (container.children.?.items, 0..) |child, i| {
                try testing.expect(child.bounds.width > initial_widths[i]);
            }
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: Layout.apply: handles many widgets efficiently" {
            const allocator = testing.allocator;
            var layout = try Layout.init(allocator, .grid);
            defer layout.deinit();
            
            layout.columns = 10;
            layout.rows = 10;
            
            const container = try createContainer(allocator, 100);
            defer {
                if (container.children) |children| {
                    for (children.items) |child| {
                        allocator.destroy(child);
                    }
                    children.deinit();
                }
                allocator.destroy(container);
            }
            
            const start = std.time.milliTimestamp();
            
            // Apply layout multiple times
            for (0..100) |_| {
                try layout.apply(container);
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should layout 100 widgets 100 times quickly
            try testing.expect(elapsed < 100);
        }
        
        test "performance: Complex layout: calculates nested layouts fast" {
            const allocator = testing.allocator;
            
            // Create deeply nested structure
            const root = try createContainer(allocator, 5);
            defer {
                // Cleanup would be recursive in real implementation
                if (root.children) |children| {
                    for (children.items) |child| {
                        allocator.destroy(child);
                    }
                    children.deinit();
                }
                allocator.destroy(root);
            }
            
            // Add sub-containers
            for (root.children.?.items) |child| {
                child.children = std.ArrayList(*Widget).init(allocator);
                for (0..5) |_| {
                    const subchild = try createTestWidget(allocator, .{});
                    try child.children.?.append(subchild);
                }
            }
            
            var layout = try Layout.init(allocator, .flex);
            defer layout.deinit();
            
            const start = std.time.milliTimestamp();
            
            // Apply to all levels
            try layout.apply(root);
            for (root.children.?.items) |child| {
                try layout.apply(child);
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should handle nested layouts quickly
            try testing.expect(elapsed < 50);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Stress Tests ────────────────────────────┐
    
        test "stress: Layout: handles extreme widget counts" {
            const allocator = testing.allocator;
            var layout = try Layout.init(allocator, .horizontal);
            defer layout.deinit();
            
            const container = try createContainer(allocator, 1000);
            defer {
                if (container.children) |children| {
                    for (children.items) |child| {
                        allocator.destroy(child);
                    }
                    children.deinit();
                }
                allocator.destroy(container);
            }
            
            // Should handle 1000 widgets
            try layout.apply(container);
            
            // Verify all widgets positioned
            for (container.children.?.items) |child| {
                try testing.expect(child.bounds.width > 0);
            }
        }
        
        test "stress: Layout: survives rapid constraint changes" {
            const allocator = testing.allocator;
            var layout = try Layout.init(allocator, .flex);
            defer layout.deinit();
            
            const container = try createContainer(allocator, 10);
            defer {
                if (container.children) |children| {
                    for (children.items) |child| {
                        allocator.destroy(child);
                    }
                    children.deinit();
                }
                allocator.destroy(container);
            }
            
            var prng = std.rand.DefaultPrng.init(22222);
            const random = prng.random();
            
            // Rapidly change constraints and re-layout
            for (0..1000) |_| {
                for (container.children.?.items) |child| {
                    child.constraint = Constraint{
                        .min_width = random.intRangeLessThan(u16, 1, 50),
                        .max_width = random.intRangeLessThan(u16, 50, 100),
                        .flex = random.float(f32) * 3.0,
                    };
                }
                
                try layout.apply(container);
            }
            
            // Should remain stable
            try testing.expect(container.children.?.items.len == 10);
        }
    
    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝