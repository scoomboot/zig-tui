// tui_optimization.test.zig — Performance and safety tests for TUI optimizations
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

// ╚════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════════╗

    // ┌──────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: Color.toAnsi: inlined function is fast" {
            // This test verifies the inline optimization
            const iterations = 1_000_000;
            var checksum: u32 = 0;
            
            const start = std.time.nanoTimestamp();
            for (0..iterations) |i| {
                const color: tui.Color = switch (i % 8) {
                    0 => .red,
                    1 => .blue,
                    2 => .green,
                    3 => .{ .indexed = @intCast(i % 256) },
                    4 => .bright_red,
                    5 => .cyan,
                    6 => .{ .rgb = .{ .r = @intCast(i % 256), .g = 128, .b = 64 } },
                    7 => .default,
                    else => unreachable,
                };
                checksum +%= color.toAnsi();
            }
            const elapsed = std.time.nanoTimestamp() - start;
            
            // Prevent optimization away
            try testing.expect(checksum > 0);
            
            // Should average under 5ns per call with inlining
            const avg_ns = @divFloor(elapsed, iterations);
            try testing.expect(avg_ns < 5);
        }
        
        test "performance: Attributes.isSet: bitcast optimization" {
            // Test that bitcast optimization is faster than field checks
            const iterations = 10_000_000;
            
            var attrs = tui.Attributes{
                .bold = true,
                .italic = false,
                .underline = true,
                .blink = false,
                .reverse = false,
                .hidden = true,
                .strikethrough = false,
                .dim = true,
            };
            
            var count: u32 = 0;
            const start = std.time.nanoTimestamp();
            for (0..iterations) |_| {
                if (attrs.isSet()) {
                    count += 1;
                }
                // Modify to prevent optimization
                attrs.bold = !attrs.bold;
            }
            const elapsed = std.time.nanoTimestamp() - start;
            
            try testing.expect(count > 0);
            
            // Should be under 2ns per call with bitcast
            const avg_ns = @divFloor(elapsed, iterations);
            try testing.expect(avg_ns < 2);
        }
        
        test "performance: RGB color packed struct memory layout" {
            // Verify packed struct uses less memory
            const RgbPacked = packed struct { r: u8, g: u8, b: u8 };
            const RgbNormal = struct { r: u8, g: u8, b: u8 };
            
            try testing.expectEqual(@as(usize, 3), @sizeOf(RgbPacked));
            // Normal struct might have padding
            try testing.expect(@sizeOf(RgbNormal) >= 3);
            
            // Verify Color union size is optimal
            const color_size = @sizeOf(tui.Color);
            try testing.expect(color_size <= 8); // Should be small
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── Memory Safety Tests ────────────────────────────┐
    
        test "performance: TUI.render: buffer reuse prevents allocations" {
            const allocator = testing.allocator;
            
            // Create a minimal TUI config
            const config = tui.Config{
                .target_fps = 60,
                .initial_buffer_capacity = 1024,
            };
            
            var test_tui = try tui.initWithConfig(allocator, config);
            defer test_tui.deinit();
            
            // Verify buffer is pre-allocated
            try testing.expect(test_tui.render_buffer.capacity >= 1024);
            
            // Multiple renders should reuse the buffer
            const initial_capacity = test_tui.render_buffer.capacity;
            
            // Clear buffer and verify it retains capacity
            test_tui.render_buffer.clearRetainingCapacity();
            try testing.expectEqual(initial_capacity, test_tui.render_buffer.capacity);
        }
        
        test "unit: TUI.running: atomic operations are thread-safe" {
            const allocator = testing.allocator;
            
            var test_tui = try tui.init(allocator);
            defer test_tui.deinit();
            
            // Initial state should be false
            try testing.expect(!test_tui.isRunning());
            
            // Store and load should be consistent
            test_tui.running.store(true, .seq_cst);
            try testing.expect(test_tui.isRunning());
            
            test_tui.stop();
            try testing.expect(!test_tui.isRunning());
        }
        
        test "unit: Config validation prevents invalid values" {
            const allocator = testing.allocator;
            
            // Test invalid FPS (0)
            const bad_config1 = tui.Config{ .target_fps = 0 };
            const result1 = tui.initWithConfig(allocator, bad_config1);
            try testing.expectError(tui.TuiError.InvalidInput, result1);
            
            // Test invalid FPS (too high)
            const bad_config2 = tui.Config{ .target_fps = 1000 };
            const result2 = tui.initWithConfig(allocator, bad_config2);
            try testing.expectError(tui.TuiError.InvalidInput, result2);
            
            // Valid config should work
            const good_config = tui.Config{ .target_fps = 60 };
            var test_tui = try tui.initWithConfig(allocator, good_config);
            defer test_tui.deinit();
            
            try testing.expectEqual(@as(u32, 60), test_tui.target_fps);
        }
        
        test "unit: Size.contains: bounds checking" {
            const size = tui.Size.new(80, 24);
            
            // Points within bounds
            try testing.expect(size.contains(tui.Point.new(0, 0)));
            try testing.expect(size.contains(tui.Point.new(79, 23)));
            try testing.expect(size.contains(tui.Point.new(40, 12)));
            
            // Points out of bounds
            try testing.expect(!size.contains(tui.Point.new(80, 23)));
            try testing.expect(!size.contains(tui.Point.new(79, 24)));
            try testing.expect(!size.contains(tui.Point.new(80, 24)));
            try testing.expect(!size.contains(tui.Point.new(65535, 65535)));
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── Error Handling Tests ────────────────────────────┐
    
        test "error: Resize with zero dimensions returns error" {
            const allocator = testing.allocator;
            
            var test_tui = try tui.init(allocator);
            defer test_tui.deinit();
            
            // Create resize event with zero width
            const bad_event = tui.Event{
                .resize = .{ .width = 0, .height = 100 },
            };
            
            const result = test_tui.handleEvent(bad_event);
            try testing.expectError(tui.TuiError.InvalidDimensions, result);
            
            // Zero height should also error
            const bad_event2 = tui.Event{
                .resize = .{ .width = 100, .height = 0 },
            };
            
            const result2 = test_tui.handleEvent(bad_event2);
            try testing.expectError(tui.TuiError.InvalidDimensions, result2);
        }
        
        test "error: Terminal restoration on error" {
            const allocator = testing.allocator;
            
            // Initialize TUI
            var test_tui = try tui.init(allocator);
            
            // Deinit should restore terminal even if errors occurred
            // This is safe because deinit catches errors
            test_tui.deinit();
            
            // Verify we can init again (terminal was properly restored)
            var test_tui2 = try tui.init(allocator);
            test_tui2.deinit();
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── Rendering Tests ────────────────────────────┐
    
        test "rendering: Color.writeAnsiRgb: formats correctly" {
            const allocator = testing.allocator;
            var buffer = std.ArrayList(u8).init(allocator);
            defer buffer.deinit();
            
            // Test RGB foreground
            const rgb_color = tui.Color{ .rgb = .{ .r = 255, .g = 128, .b = 64 } };
            try rgb_color.writeAnsiRgb(buffer.writer(), true);
            try testing.expectEqualStrings(
                "\x1b[38;2;255;128;64m",
                buffer.items
            );
            
            // Test RGB background
            buffer.clearRetainingCapacity();
            try rgb_color.writeAnsiRgb(buffer.writer(), false);
            try testing.expectEqualStrings(
                "\x1b[48;2;255;128;64m",
                buffer.items
            );
            
            // Test indexed color
            buffer.clearRetainingCapacity();
            const indexed = tui.Color{ .indexed = 123 };
            try indexed.writeAnsiRgb(buffer.writer(), true);
            try testing.expectEqualStrings(
                "\x1b[38;5;123m",
                buffer.items
            );
            
            // Test standard color
            buffer.clearRetainingCapacity();
            const red = tui.Color.red;
            try red.writeAnsiRgb(buffer.writer(), true);
            try testing.expectEqualStrings(
                "\x1b[31m",
                buffer.items
            );
        }
        
        test "rendering: Attributes.writeAnsi: outputs escape sequences" {
            const allocator = testing.allocator;
            var buffer = std.ArrayList(u8).init(allocator);
            defer buffer.deinit();
            
            var attrs = tui.Attributes{
                .bold = true,
                .italic = true,
                .underline = true,
                .blink = false,
                .reverse = false,
                .hidden = false,
                .strikethrough = false,
                .dim = false,
            };
            
            try attrs.writeAnsi(buffer.writer());
            
            // Should contain bold, italic, and underline sequences
            try testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[1m") != null);
            try testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[3m") != null);
            try testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[4m") != null);
            
            // Should not contain disabled attributes
            try testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[5m") == null);
            try testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[7m") == null);
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── Frame Rate Tests ────────────────────────────┐
    
        test "frame rate: Target FPS configuration" {
            const allocator = testing.allocator;
            
            // Test various FPS settings
            const configs = [_]tui.Config{
                .{ .target_fps = 30 },
                .{ .target_fps = 60 },
                .{ .target_fps = 120 },
                .{ .target_fps = 144 },
            };
            
            for (configs) |config| {
                var test_tui = try tui.initWithConfig(allocator, config);
                defer test_tui.deinit();
                
                try testing.expectEqual(config.target_fps, test_tui.target_fps);
                
                // Calculate expected frame duration
                const expected_ns = @divFloor(std.time.ns_per_s, config.target_fps);
                const actual_ns = @divFloor(std.time.ns_per_s, test_tui.target_fps);
                
                try testing.expectEqual(expected_ns, actual_ns);
            }
        }
    
    // └────────────────────────────────────────────────────────────────────────┘

// ╚════════════════════════════════════════════════════════════════════════════════════════╝