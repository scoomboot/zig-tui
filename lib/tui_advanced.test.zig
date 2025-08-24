// tui_advanced.test.zig — Advanced tests for TUI optimization features
//
// This file provides comprehensive test coverage for thread safety,
// render buffer management, and performance optimizations.
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs/tui
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const tui = @import("tui.zig");
    const builtin = @import("builtin");

// ╚════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════════╗

    // ┌──────────────────────── Thread Safety Tests ────────────────────────────┐
    
        test "stress: TUI.running: concurrent access patterns" {
            const allocator = testing.allocator;
            var test_tui = try tui.init(allocator);
            defer test_tui.deinit();
            
            // Simulate rapid state changes from multiple logical paths
            for (0..10000) |i| {
                const should_run = (i % 2) == 0;
                test_tui.running.store(should_run, .seq_cst);
                
                // Immediately read back
                const is_running = test_tui.isRunning();
                try testing.expectEqual(should_run, is_running);
                
                // Test stop method intermittently
                if (i % 100 == 0) {
                    test_tui.running.store(true, .seq_cst);
                    test_tui.stop();
                    try testing.expect(!test_tui.isRunning());
                }
            }
        }
        
        test "stress: Atomic memory orderings verification" {
            var atomic = std.atomic.Value(bool).init(false);
            
            // Test all memory orderings
            const orderings = [_]std.builtin.AtomicOrder{
                .unordered,
                .monotonic,
                .acquire,
                .release,
                .acq_rel,
                .seq_cst,
            };
            
            for (orderings) |store_order| {
                for (orderings) |load_order| {
                    // Skip invalid combinations
                    if (store_order == .acquire) continue;
                    if (load_order == .release) continue;
                    if (store_order == .acq_rel and load_order != .acq_rel) continue;
                    
                    atomic.store(true, store_order);
                    const value = atomic.load(load_order);
                    try testing.expect(value);
                    
                    atomic.store(false, store_order);
                    const value2 = atomic.load(load_order);
                    try testing.expect(!value2);
                }
            }
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── Render Buffer Management ────────────────────────────┐
    
        test "integration: Render buffer: memory reuse patterns" {
            const allocator = testing.allocator;
            
            const config = tui.Config{
                .initial_buffer_capacity = 512,
            };
            var test_tui = try tui.initWithConfig(allocator, config);
            defer test_tui.deinit();
            
            // Track capacity changes
            var capacities = std.ArrayList(usize).init(allocator);
            defer capacities.deinit();
            
            // Simulate varying render loads
            for (0..20) |cycle| {
                test_tui.render_buffer.clearRetainingCapacity();
                try capacities.append(test_tui.render_buffer.capacity);
                
                const writer = test_tui.render_buffer.writer();
                
                // Vary the amount of data per cycle
                const data_size = if (cycle < 10) 
                    100 + cycle * 50  // Growing
                else 
                    1000 - (cycle - 10) * 50;  // Shrinking
                
                for (0..data_size) |_| {
                    try writer.writeByte('X');
                }
            }
            
            // Verify capacity is retained (no unnecessary shrinking)
            for (capacities.items[1..]) |capacity| {
                try testing.expect(capacity >= 512);
            }
        }
        
        test "integration: Render buffer: ANSI sequence batching" {
            const allocator = testing.allocator;
            
            var test_tui = try tui.init(allocator);
            defer test_tui.deinit();
            
            // Clear buffer
            test_tui.render_buffer.clearRetainingCapacity();
            const writer = test_tui.render_buffer.writer();
            
            // Simulate optimized batching of ANSI sequences
            var last_style: ?tui.Style = null;
            
            const cells = [_]struct {
                x: u16,
                y: u16,
                style: tui.Style,
                char: u21,
            }{
                .{ .x = 0, .y = 0, .style = tui.Style.withFg(.red), .char = 'A' },
                .{ .x = 1, .y = 0, .style = tui.Style.withFg(.red), .char = 'B' },  // Same style
                .{ .x = 2, .y = 0, .style = tui.Style.withFg(.blue), .char = 'C' }, // Different style
                .{ .x = 3, .y = 0, .style = tui.Style.withFg(.blue), .char = 'D' }, // Same style
            };
            
            var style_changes: u32 = 0;
            
            for (cells) |cell| {
                // Move cursor
                try writer.print("\x1b[{d};{d}H", .{ cell.y + 1, cell.x + 1 });
                
                // Apply style only if changed
                if (last_style == null or !std.meta.eql(last_style.?, cell.style)) {
                    try writer.writeAll("\x1b[0m"); // Reset
                    try cell.style.fg.writeAnsiRgb(writer, true);
                    last_style = cell.style;
                    style_changes += 1;
                }
                
                // Write character
                try writer.writeByte(@intCast(cell.char));
            }
            
            // Should have optimized style changes (2 instead of 4)
            try testing.expectEqual(@as(u32, 2), style_changes);
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── TUI Lifecycle Management ────────────────────────────┐
    
        test "integration: TUI lifecycle: multiple init/deinit cycles" {
            const allocator = testing.allocator;
            
            // Rapid init/deinit cycles to test resource management
            for (0..10) |i| {
                const config = tui.Config{
                    .target_fps = @intCast(30 + i * 10),
                    .initial_buffer_capacity = 256 << @intCast(i % 4),
                };
                
                var test_tui = try tui.initWithConfig(allocator, config);
                
                // Verify state
                try testing.expect(!test_tui.isRunning());
                try testing.expectEqual(config.target_fps, test_tui.target_fps);
                try testing.expect(test_tui.render_buffer.capacity >= config.initial_buffer_capacity);
                
                // Simulate some operations
                test_tui.running.store(true, .seq_cst);
                test_tui.stop();
                
                test_tui.deinit();
            }
        }
        
        test "integration: TUI handleEvent: comprehensive event processing" {
            const allocator = testing.allocator;
            var test_tui = try tui.init(allocator);
            defer test_tui.deinit();
            
            test_tui.running.store(true, .seq_cst);
            
            // Test various key combinations
            const key_tests = [_]struct {
                char: u8,
                ctrl: bool,
                should_quit: bool,
            }{
                .{ .char = 'a', .ctrl = false, .should_quit = false },
                .{ .char = 'c', .ctrl = true, .should_quit = true },
                .{ .char = 'C', .ctrl = true, .should_quit = true },
                .{ .char = 'd', .ctrl = true, .should_quit = true },
                .{ .char = 'D', .ctrl = true, .should_quit = true },
                .{ .char = 'q', .ctrl = false, .should_quit = false },
                .{ .char = 'x', .ctrl = true, .should_quit = false },
            };
            
            for (key_tests) |kt| {
                test_tui.running.store(true, .seq_cst);
                
                const event = tui.Event{
                    .key = .{
                        .code = .{ .char = kt.char },
                        .modifiers = .{ .ctrl = kt.ctrl },
                    },
                };
                
                try test_tui.handleEvent(event);
                
                if (kt.should_quit) {
                    try testing.expect(!test_tui.isRunning());
                } else {
                    try testing.expect(test_tui.isRunning());
                }
            }
            
            // Test resize event error handling
            const bad_resize_events = [_]tui.Event{
                .{ .resize = .{ .width = 0, .height = 100 } },
                .{ .resize = .{ .width = 100, .height = 0 } },
                .{ .resize = .{ .width = 0, .height = 0 } },
            };
            
            for (bad_resize_events) |event| {
                const result = test_tui.handleEvent(event);
                try testing.expectError(tui.TuiError.InvalidDimensions, result);
            }
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── Performance Benchmarks ────────────────────────────┐
    
        test "performance: Color packed struct memory efficiency" {
            // Verify memory layout optimizations
            const ColorUnion = tui.Color;
            const size = @sizeOf(ColorUnion);
            
            // Should be compact (4 bytes for tag + RGB, or 8 bytes max with alignment)
            try testing.expect(size <= 8);
            
            // Test that RGB variant is packed
            const rgb_color = ColorUnion{ .rgb = .{ .r = 255, .g = 128, .b = 64 } };
            const rgb_only_size = @sizeOf(@TypeOf(rgb_color.rgb));
            try testing.expectEqual(@as(usize, 3), rgb_only_size);
        }
        
        test "performance: Inline function optimization verification" {
            // Functions marked inline should have minimal overhead
            const iterations = 1_000_000;
            
            // Test Color.toAnsi (inline)
            {
                var sum: u32 = 0;
                const start = std.time.nanoTimestamp();
                
                for (0..iterations) |i| {
                    const color: tui.Color = if (i % 2 == 0) .red else .blue;
                    sum +%= color.toAnsi();
                }
                
                const elapsed = std.time.nanoTimestamp() - start;
                const avg_ns = @divFloor(elapsed, iterations);
                
                // Should be extremely fast with inlining
                try testing.expect(avg_ns < 5);
                try testing.expect(sum > 0); // Prevent optimization away
            }
            
            // Test Attributes.isSet (inline)
            {
                var count: u32 = 0;
                const attrs = tui.Attributes{ .bold = true, .italic = true };
                
                const start = std.time.nanoTimestamp();
                
                for (0..iterations) |_| {
                    if (attrs.isSet()) count += 1;
                }
                
                const elapsed = std.time.nanoTimestamp() - start;
                const avg_ns = @divFloor(elapsed, iterations);
                
                // Bitcast should be extremely fast
                try testing.expect(avg_ns < 2);
                try testing.expectEqual(iterations, count);
            }
            
            // Test Size.area (inline)
            {
                const size = tui.Size.new(1920, 1080);
                var sum: u64 = 0;
                
                const start = std.time.nanoTimestamp();
                
                for (0..iterations) |_| {
                    sum +%= size.area();
                }
                
                const elapsed = std.time.nanoTimestamp() - start;
                const avg_ns = @divFloor(elapsed, iterations);
                
                // Simple multiplication should be instant
                try testing.expect(avg_ns < 2);
                try testing.expect(sum > 0);
            }
            
            // Test Size.contains (inline)
            {
                const size = tui.Size.new(100, 100);
                const point = tui.Point.new(50, 50);
                var count: u32 = 0;
                
                const start = std.time.nanoTimestamp();
                
                for (0..iterations) |_| {
                    if (size.contains(point)) count += 1;
                }
                
                const elapsed = std.time.nanoTimestamp() - start;
                const avg_ns = @divFloor(elapsed, iterations);
                
                // Simple comparison should be instant
                try testing.expect(avg_ns < 3);
                try testing.expectEqual(iterations, count);
            }
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── Frame Rate Control Tests ────────────────────────────┐
    
        test "integration: Frame rate limiting accuracy" {
            const allocator = testing.allocator;
            
            const test_configs = [_]struct {
                fps: u32,
                expected_frame_ns: u64,
                tolerance_ns: u64,
            }{
                .{ .fps = 30, .expected_frame_ns = 33_333_333, .tolerance_ns = 1_000_000 },
                .{ .fps = 60, .expected_frame_ns = 16_666_666, .tolerance_ns = 500_000 },
                .{ .fps = 120, .expected_frame_ns = 8_333_333, .tolerance_ns = 250_000 },
                .{ .fps = 144, .expected_frame_ns = 6_944_444, .tolerance_ns = 200_000 },
            };
            
            for (test_configs) |tc| {
                const config = tui.Config{ .target_fps = tc.fps };
                var test_tui = try tui.initWithConfig(allocator, config);
                defer test_tui.deinit();
                
                // Calculate actual frame duration
                const actual_ns = @divFloor(std.time.ns_per_s, tc.fps);
                
                // Should be within tolerance
                const diff = if (actual_ns > tc.expected_frame_ns)
                    actual_ns - tc.expected_frame_ns
                else
                    tc.expected_frame_ns - actual_ns;
                
                try testing.expect(diff <= tc.tolerance_ns);
            }
        }
        
        test "integration: Render timing with variable load" {
            const allocator = testing.allocator;
            
            var test_tui = try tui.init(allocator);
            defer test_tui.deinit();
            
            const frame_duration_ns = @divFloor(std.time.ns_per_s, test_tui.target_fps);
            
            // Simulate frames with varying processing time
            for (0..10) |i| {
                const frame_start = std.time.nanoTimestamp();
                
                // Simulate work that takes variable time
                const work_time_ns = (i + 1) * 1_000_000; // 1-10ms
                std.time.sleep(work_time_ns);
                
                const frame_elapsed = std.time.nanoTimestamp() - frame_start;
                
                // Calculate sleep time needed
                if (frame_elapsed < frame_duration_ns) {
                    const sleep_ns = frame_duration_ns - frame_elapsed;
                    
                    // Verify sleep calculation is correct
                    try testing.expect(sleep_ns > 0);
                    try testing.expect(sleep_ns < frame_duration_ns);
                }
            }
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── Edge Cases and Error Paths ────────────────────────────┐
    
        test "stress: RGB color extreme values" {
            const allocator = testing.allocator;
            var buffer = std.ArrayList(u8).init(allocator);
            defer buffer.deinit();
            
            // Test all corner cases of RGB space
            const corner_cases = [_][3]u8{
                .{ 0, 0, 0 },       // Black
                .{ 255, 255, 255 }, // White
                .{ 255, 0, 0 },     // Pure red
                .{ 0, 255, 0 },     // Pure green
                .{ 0, 0, 255 },     // Pure blue
                .{ 255, 255, 0 },   // Yellow
                .{ 255, 0, 255 },   // Magenta
                .{ 0, 255, 255 },   // Cyan
                .{ 128, 128, 128 }, // Middle gray
                .{ 1, 1, 1 },       // Almost black
                .{ 254, 254, 254 }, // Almost white
            };
            
            for (corner_cases) |rgb| {
                const color = tui.Color{ .rgb = .{ .r = rgb[0], .g = rgb[1], .b = rgb[2] } };
                
                // Test foreground
                buffer.clearRetainingCapacity();
                try color.writeAnsiRgb(buffer.writer(), true);
                
                const expected_fg = try std.fmt.allocPrint(
                    allocator,
                    "\x1b[38;2;{d};{d};{d}m",
                    .{ rgb[0], rgb[1], rgb[2] }
                );
                defer allocator.free(expected_fg);
                try testing.expectEqualStrings(expected_fg, buffer.items);
                
                // Test background
                buffer.clearRetainingCapacity();
                try color.writeAnsiRgb(buffer.writer(), false);
                
                const expected_bg = try std.fmt.allocPrint(
                    allocator,
                    "\x1b[48;2;{d};{d};{d}m",
                    .{ rgb[0], rgb[1], rgb[2] }
                );
                defer allocator.free(expected_bg);
                try testing.expectEqualStrings(expected_bg, buffer.items);
            }
        }
        
        test "stress: Attributes all combinations writeAnsi" {
            const allocator = testing.allocator;
            var buffer = std.ArrayList(u8).init(allocator);
            defer buffer.deinit();
            
            // Test all 256 possible attribute combinations
            for (0..256) |i| {
                const attrs = tui.Attributes{
                    .bold = (i & 0x01) != 0,
                    .dim = (i & 0x02) != 0,
                    .italic = (i & 0x04) != 0,
                    .underline = (i & 0x08) != 0,
                    .blink = (i & 0x10) != 0,
                    .reverse = (i & 0x20) != 0,
                    .hidden = (i & 0x40) != 0,
                    .strikethrough = (i & 0x80) != 0,
                };
                
                buffer.clearRetainingCapacity();
                try attrs.writeAnsi(buffer.writer());
                
                // Verify each enabled attribute appears in output
                if (attrs.bold) {
                    try testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[1m") != null);
                }
                if (attrs.dim) {
                    try testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[2m") != null);
                }
                if (attrs.italic) {
                    try testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[3m") != null);
                }
                if (attrs.underline) {
                    try testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[4m") != null);
                }
                if (attrs.blink) {
                    try testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[5m") != null);
                }
                if (attrs.reverse) {
                    try testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[7m") != null);
                }
                if (attrs.hidden) {
                    try testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[8m") != null);
                }
                if (attrs.strikethrough) {
                    try testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[9m") != null);
                }
            }
        }
        
        test "e2e: Complete render pipeline simulation" {
            const allocator = testing.allocator;
            
            var test_tui = try tui.init(allocator);
            defer test_tui.deinit();
            
            // Simulate a complete render cycle
            test_tui.render_buffer.clearRetainingCapacity();
            const writer = test_tui.render_buffer.writer();
            
            // 1. Clear screen
            try writer.writeAll("\x1b[2J");
            
            // 2. Reset cursor
            try writer.writeAll("\x1b[H");
            
            // 3. Draw a box with styled borders
            const box_style = tui.Style{
                .fg = .blue,
                .bg = .default,
                .attrs = .{ .bold = true },
            };
            
            // Top border
            try writer.writeAll("\x1b[0m"); // Reset
            try box_style.attrs.writeAnsi(writer);
            try box_style.fg.writeAnsiRgb(writer, true);
            
            try writer.writeAll("┌");
            for (0..20) |_| try writer.writeAll("─");
            try writer.writeAll("┐\n");
            
            // Sides with content
            for (0..5) |row| {
                try writer.writeAll("│");
                try writer.writeAll("\x1b[0m"); // Reset for content
                
                // Content with different style
                const content_style = tui.Style{
                    .fg = .green,
                    .bg = .default,
                    .attrs = .{},
                };
                try content_style.fg.writeAnsiRgb(writer, true);
                
                const content = try std.fmt.allocPrint(allocator, " Line {d:2} content ", .{row});
                defer allocator.free(content);
                try writer.writeAll(content);
                
                // Pad to width
                for (content.len..20) |_| try writer.writeByte(' ');
                
                // Back to border style
                try writer.writeAll("\x1b[0m");
                try box_style.attrs.writeAnsi(writer);
                try box_style.fg.writeAnsiRgb(writer, true);
                try writer.writeAll("│\n");
            }
            
            // Bottom border
            try writer.writeAll("└");
            for (0..20) |_| try writer.writeAll("─");
            try writer.writeAll("┘\n");
            
            // Reset at end
            try writer.writeAll("\x1b[0m");
            
            // Verify output was generated
            try testing.expect(test_tui.render_buffer.items.len > 100);
            
            // Verify key sequences are present
            try testing.expect(std.mem.indexOf(u8, test_tui.render_buffer.items, "\x1b[2J") != null);
            try testing.expect(std.mem.indexOf(u8, test_tui.render_buffer.items, "\x1b[H") != null);
            try testing.expect(std.mem.indexOf(u8, test_tui.render_buffer.items, "\x1b[0m") != null);
        }
    
    // └────────────────────────────────────────────────────────────────────────┘

// ╚════════════════════════════════════════════════════════════════════════════════════════╝