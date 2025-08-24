// rect.test.zig — Comprehensive tests for rectangle utilities
//
// repo   : https://github.com/fisty/zig-tui
// author : https://github.com/fisty
//
// Tests for rectangle operations, intersections, and containment.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Rect = @import("rect.zig").Rect;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test constants
    const MAX_COORD: u16 = 65535;
    const MAX_SIZE: u16 = 10000;
    
    // Test helpers
    fn createRect(x: u16, y: u16, width: u16, height: u16) Rect {
        return Rect{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        };
    }
    
    fn createSquare(x: u16, y: u16, size: u16) Rect {
        return Rect{
            .x = x,
            .y = y,
            .width = size,
            .height = size,
        };
    }
    
    fn createRectFromPoints(x1: u16, y1: u16, x2: u16, y2: u16) Rect {
        return Rect{
            .x = @min(x1, x2),
            .y = @min(y1, y2),
            .width = if (x2 > x1) x2 - x1 else x1 - x2,
            .height = if (y2 > y1) y2 - y1 else y1 - y2,
        };
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐
    
        test "unit: Rect: initializes with correct values" {
            const rect = createRect(10, 20, 30, 40);
            
            try testing.expectEqual(@as(u16, 10), rect.x);
            try testing.expectEqual(@as(u16, 20), rect.y);
            try testing.expectEqual(@as(u16, 30), rect.width);
            try testing.expectEqual(@as(u16, 40), rect.height);
        }
        
        test "unit: Rect: calculates area correctly" {
            const rect = createRect(0, 0, 10, 20);
            try testing.expectEqual(@as(u32, 200), rect.area());
            
            const square = createSquare(0, 0, 15);
            try testing.expectEqual(@as(u32, 225), square.area());
            
            const empty = createRect(0, 0, 0, 0);
            try testing.expectEqual(@as(u32, 0), empty.area());
        }
        
        test "unit: Rect: checks if empty correctly" {
            const empty1 = createRect(10, 10, 0, 10);
            try testing.expect(empty1.isEmpty());
            
            const empty2 = createRect(10, 10, 10, 0);
            try testing.expect(empty2.isEmpty());
            
            const empty3 = createRect(10, 10, 0, 0);
            try testing.expect(empty3.isEmpty());
            
            const non_empty = createRect(10, 10, 5, 5);
            try testing.expect(!non_empty.isEmpty());
        }
        
        test "unit: Rect: checks point containment correctly" {
            const rect = createRect(10, 20, 30, 40);
            
            // Inside points
            try testing.expect(rect.containsPoint(10, 20)); // Top-left
            try testing.expect(rect.containsPoint(39, 59)); // Bottom-right - 1
            try testing.expect(rect.containsPoint(25, 40)); // Center
            
            // Outside points
            try testing.expect(!rect.containsPoint(9, 20));   // Left of rect
            try testing.expect(!rect.containsPoint(10, 19));  // Above rect
            try testing.expect(!rect.containsPoint(40, 40));  // Right of rect
            try testing.expect(!rect.containsPoint(25, 60));  // Below rect
        }
        
        test "unit: Rect: gets bounds correctly" {
            const rect = createRect(10, 20, 30, 40);
            
            try testing.expectEqual(@as(u16, 10), rect.left());
            try testing.expectEqual(@as(u16, 40), rect.right());
            try testing.expectEqual(@as(u16, 20), rect.top());
            try testing.expectEqual(@as(u16, 60), rect.bottom());
        }
        
        test "unit: Rect: gets center point correctly" {
            const rect = createRect(10, 20, 30, 40);
            const center = rect.center();
            
            try testing.expectEqual(@as(u16, 25), center.x);
            try testing.expectEqual(@as(u16, 40), center.y);
            
            const square = createSquare(0, 0, 10);
            const sq_center = square.center();
            
            try testing.expectEqual(@as(u16, 5), sq_center.x);
            try testing.expectEqual(@as(u16, 5), sq_center.y);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: Rect intersection: calculates correctly" {
            const rect1 = createRect(10, 10, 30, 30);
            const rect2 = createRect(20, 20, 30, 30);
            
            const intersection = rect1.intersect(rect2);
            try testing.expect(intersection != null);
            
            if (intersection) |inter| {
                try testing.expectEqual(@as(u16, 20), inter.x);
                try testing.expectEqual(@as(u16, 20), inter.y);
                try testing.expectEqual(@as(u16, 20), inter.width);
                try testing.expectEqual(@as(u16, 20), inter.height);
            }
            
            // Non-intersecting rectangles
            const rect3 = createRect(100, 100, 10, 10);
            const no_intersection = rect1.intersect(rect3);
            try testing.expect(no_intersection == null);
        }
        
        test "integration: Rect union: combines rectangles" {
            const rect1 = createRect(10, 10, 20, 20);
            const rect2 = createRect(20, 20, 30, 30);
            
            const union_rect = rect1.union(rect2);
            
            try testing.expectEqual(@as(u16, 10), union_rect.x);
            try testing.expectEqual(@as(u16, 10), union_rect.y);
            try testing.expectEqual(@as(u16, 40), union_rect.width);
            try testing.expectEqual(@as(u16, 40), union_rect.height);
            
            // Union with itself
            const self_union = rect1.union(rect1);
            try testing.expect(rect1.equals(self_union));
        }
        
        test "integration: Rect containment: checks rect in rect" {
            const outer = createRect(10, 10, 50, 50);
            const inner = createRect(20, 20, 10, 10);
            const partial = createRect(30, 30, 40, 40);
            const outside = createRect(100, 100, 10, 10);
            
            try testing.expect(outer.containsRect(inner));
            try testing.expect(!outer.containsRect(partial));
            try testing.expect(!outer.containsRect(outside));
            
            // Self containment
            try testing.expect(outer.containsRect(outer));
        }
        
        test "integration: Rect splitting: divides rectangles" {
            const allocator = testing.allocator;
            const rect = createRect(0, 0, 100, 100);
            
            // Split horizontally
            const h_splits = try rect.splitHorizontal(allocator, 2);
            defer allocator.free(h_splits);
            
            try testing.expectEqual(@as(usize, 2), h_splits.len);
            try testing.expectEqual(@as(u16, 50), h_splits[0].height);
            try testing.expectEqual(@as(u16, 50), h_splits[1].height);
            
            // Split vertically
            const v_splits = try rect.splitVertical(allocator, 4);
            defer allocator.free(v_splits);
            
            try testing.expectEqual(@as(usize, 4), v_splits.len);
            for (v_splits) |split| {
                try testing.expectEqual(@as(u16, 25), split.width);
            }
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── E2E Tests ────────────────────────────┐
    
        test "e2e: rect layout system: complex positioning" {
            const allocator = testing.allocator;
            
            // Create screen bounds
            const screen = createRect(0, 0, 800, 600);
            
            // Create UI regions
            const header = createRect(0, 0, 800, 50);
            const sidebar = createRect(0, 50, 200, 550);
            const content = createRect(200, 50, 600, 500);
            const footer = createRect(200, 550, 600, 50);
            
            // Verify no overlaps except at edges
            try testing.expect(header.bottom() == sidebar.top());
            try testing.expect(sidebar.right() == content.left());
            try testing.expect(content.bottom() == footer.top());
            
            // Verify all fit within screen
            try testing.expect(screen.containsRect(header));
            try testing.expect(screen.containsRect(sidebar));
            try testing.expect(screen.containsRect(content));
            try testing.expect(screen.containsRect(footer));
            
            // Calculate total coverage
            const total_area = header.area() + sidebar.area() + content.area() + footer.area();
            try testing.expectEqual(screen.area(), total_area);
        }
        
        test "e2e: rect clipping: viewport rendering" {
            // Viewport
            const viewport = createRect(100, 100, 200, 150);
            
            // Objects to render
            const objects = [_]Rect{
                createRect(50, 50, 100, 100),    // Partially outside top-left
                createRect(150, 120, 50, 50),    // Fully inside
                createRect(250, 200, 100, 100),  // Partially outside bottom-right
                createRect(400, 400, 50, 50),    // Completely outside
            };
            
            var visible_count: u32 = 0;
            
            for (objects) |obj| {
                if (obj.intersect(viewport)) |visible| {
                    visible_count += 1;
                    
                    // Clipped region should be within viewport
                    try testing.expect(viewport.containsRect(visible));
                }
            }
            
            // Should have 3 visible objects
            try testing.expectEqual(@as(u32, 3), visible_count);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: Rect operations: handles many rectangles" {
            const allocator = testing.allocator;
            
            const rect_count = 10000;
            var rects = try allocator.alloc(Rect, rect_count);
            defer allocator.free(rects);
            
            // Initialize rectangles
            var prng = std.rand.DefaultPrng.init(44444);
            const random = prng.random();
            
            for (rects) |*rect| {
                rect.* = createRect(
                    random.intRangeLessThan(u16, 0, 1000),
                    random.intRangeLessThan(u16, 0, 1000),
                    random.intRangeLessThan(u16, 1, 100),
                    random.intRangeLessThan(u16, 1, 100)
                );
            }
            
            const start = std.time.milliTimestamp();
            
            // Perform intersection tests
            var intersection_count: u32 = 0;
            for (rects[0..100]) |rect1| {
                for (rects[100..200]) |rect2| {
                    if (rect1.intersect(rect2)) |_| {
                        intersection_count += 1;
                    }
                }
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should handle 10k intersection tests quickly
            try testing.expect(elapsed < 100);
        }
        
        test "performance: Rect.containsPoint: checks many points quickly" {
            const rect = createRect(100, 100, 500, 500);
            
            var prng = std.rand.DefaultPrng.init(55555);
            const random = prng.random();
            
            const iterations = 1000000;
            var inside_count: u32 = 0;
            
            const start = std.time.milliTimestamp();
            
            for (0..iterations) |_| {
                const x = random.intRangeLessThan(u16, 0, 1000);
                const y = random.intRangeLessThan(u16, 0, 1000);
                
                if (rect.containsPoint(x, y)) {
                    inside_count += 1;
                }
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should check 1M points quickly
            try testing.expect(elapsed < 100);
            
            // Roughly 25% should be inside (500*500 / 1000*1000)
            try testing.expect(inside_count > 200000);
            try testing.expect(inside_count < 300000);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Stress Tests ────────────────────────────┐
    
        test "stress: Rect: handles extreme coordinates" {
            // Maximum coordinates
            const max_rect = createRect(MAX_COORD - 100, MAX_COORD - 100, 100, 100);
            try testing.expectEqual(@as(u16, MAX_COORD - 100), max_rect.x);
            try testing.expectEqual(@as(u16, MAX_COORD), max_rect.right());
            
            // Zero rect
            const zero_rect = createRect(0, 0, 0, 0);
            try testing.expect(zero_rect.isEmpty());
            try testing.expectEqual(@as(u32, 0), zero_rect.area());
            
            // Very large rect
            const large_rect = createRect(0, 0, MAX_SIZE, MAX_SIZE);
            try testing.expectEqual(@as(u32, @as(u32, MAX_SIZE) * MAX_SIZE), large_rect.area());
        }
        
        test "stress: Rect: survives random operations" {
            const allocator = testing.allocator;
            var prng = std.rand.DefaultPrng.init(66666);
            const random = prng.random();
            
            var rect = createRect(500, 500, 100, 100);
            
            // Perform random operations
            for (0..10000) |_| {
                const op = random.intRangeLessThan(u8, 0, 5);
                
                switch (op) {
                    0 => {
                        // Move
                        rect.x = random.intRangeLessThan(u16, 0, 1000);
                        rect.y = random.intRangeLessThan(u16, 0, 1000);
                    },
                    1 => {
                        // Resize
                        rect.width = random.intRangeLessThan(u16, 1, 500);
                        rect.height = random.intRangeLessThan(u16, 1, 500);
                    },
                    2 => {
                        // Intersect with random rect
                        const other = createRect(
                            random.intRangeLessThan(u16, 0, 1000),
                            random.intRangeLessThan(u16, 0, 1000),
                            random.intRangeLessThan(u16, 1, 200),
                            random.intRangeLessThan(u16, 1, 200)
                        );
                        _ = rect.intersect(other);
                    },
                    3 => {
                        // Union with random rect
                        const other = createRect(
                            random.intRangeLessThan(u16, 0, 1000),
                            random.intRangeLessThan(u16, 0, 1000),
                            random.intRangeLessThan(u16, 1, 200),
                            random.intRangeLessThan(u16, 1, 200)
                        );
                        rect = rect.union(other);
                    },
                    4 => {
                        // Check random point
                        const x = random.intRangeLessThan(u16, 0, 2000);
                        const y = random.intRangeLessThan(u16, 0, 2000);
                        _ = rect.containsPoint(x, y);
                    },
                    else => unreachable,
                }
                
                // Verify invariants
                try testing.expect(rect.width > 0 or rect.isEmpty());
                try testing.expect(rect.height > 0 or rect.isEmpty());
            }
        }
    
    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝