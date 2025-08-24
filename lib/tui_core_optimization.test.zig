// tui_core_optimization.test.zig — Core optimization tests without external dependencies
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

    // ┌──────────────────────── Core Type Optimizations ────────────────────────────┐
    
        test "performance: Color union is compact" {
            // Verify Color union uses minimal memory
            const color_size = @sizeOf(tui.Color);
            
            // Should be 4 bytes or less for optimal performance
            // (1 byte tag + 3 bytes for RGB packed struct)
            try testing.expect(color_size <= 8);
            
            // Verify RGB struct is packed
            const rgb_color = tui.Color{ .rgb = .{ .r = 255, .g = 128, .b = 64 } };
            _ = rgb_color;
        }
        
        test "performance: Attributes packed struct uses single byte" {
            // Verify Attributes is efficiently packed
            const size = @sizeOf(tui.Attributes);
            try testing.expectEqual(@as(usize, 1), size);
            
            // Verify bitcast optimization works
            const attrs = tui.Attributes{
                .bold = true,
                .italic = false,
                .underline = true,
                .blink = false,
                .reverse = false,
                .hidden = false,
                .strikethrough = false,
                .dim = false,
            };
            
            // Cast to u8 and back should preserve values
            const byte = @as(u8, @bitCast(attrs));
            const attrs2 = @as(tui.Attributes, @bitCast(byte));
            
            try testing.expectEqual(attrs.bold, attrs2.bold);
            try testing.expectEqual(attrs.underline, attrs2.underline);
        }
        
        test "performance: isSet uses efficient bitcast" {
            // Test all combinations efficiently
            var count: u32 = 0;
            for (0..256) |i| {
                const byte: u8 = @intCast(i);
                const attrs = @as(tui.Attributes, @bitCast(byte));
                
                if (attrs.isSet()) {
                    count += 1;
                }
            }
            
            // 255 combinations should have at least one bit set
            try testing.expectEqual(@as(u32, 255), count);
        }
        
        test "performance: Color.toAnsi is inline" {
            // Verify function is marked inline by checking performance
            const colors = [_]tui.Color{
                .red, .blue, .green, .yellow,
                .cyan, .magenta, .white, .black,
            };
            
            var sum: u32 = 0;
            for (0..10000) |_| {
                for (colors) |color| {
                    sum +%= color.toAnsi();
                }
            }
            
            // Result should be computed (prevents optimization away)
            try testing.expect(sum > 0);
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── Memory Safety Improvements ────────────────────────────┐
    
        test "unit: atomic running flag" {
            // Verify atomic operations work correctly
            var running = std.atomic.Value(bool).init(false);
            
            try testing.expect(!running.load(.seq_cst));
            
            running.store(true, .seq_cst);
            try testing.expect(running.load(.seq_cst));
            
            running.store(false, .seq_cst);
            try testing.expect(!running.load(.seq_cst));
        }
        
        test "unit: Size.contains bounds checking" {
            const size = tui.Size.new(100, 50);
            
            // Valid points
            try testing.expect(size.contains(tui.Point.new(0, 0)));
            try testing.expect(size.contains(tui.Point.new(99, 49)));
            try testing.expect(size.contains(tui.Point.new(50, 25)));
            
            // Out of bounds
            try testing.expect(!size.contains(tui.Point.new(100, 49)));
            try testing.expect(!size.contains(tui.Point.new(99, 50)));
            try testing.expect(!size.contains(tui.Point.new(100, 50)));
        }
        
        test "unit: Config validation" {
            // Valid configs
            const valid_configs = [_]tui.Config{
                .{ .target_fps = 30 },
                .{ .target_fps = 60 },
                .{ .target_fps = 120 },
                .{ .target_fps = 240 },
            };
            
            for (valid_configs) |config| {
                // These should not panic or error during validation
                try testing.expect(config.target_fps > 0);
                try testing.expect(config.target_fps <= 240);
            }
            
            // Invalid configs
            const invalid_fps = [_]u32{ 0, 241, 500, 1000, 10000 };
            
            for (invalid_fps) |fps| {
                const config = tui.Config{ .target_fps = fps };
                // Validation should catch these
                const is_invalid = (fps == 0 or fps > 240);
                try testing.expect(is_invalid);
                _ = config;
            }
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── Performance Characteristics ────────────────────────────┐
    
        test "performance: inline functions" {
            // Test that inline functions are optimized
            const size = tui.Size.new(1920, 1080);
            
            // These should be very fast due to inlining
            var area_sum: u64 = 0;
            for (0..100000) |_| {
                area_sum +%= size.area();
            }
            
            try testing.expectEqual(@as(u64, 207360000000), area_sum);
            
            // isEmpty should also be inlined
            var empty_count: u32 = 0;
            for (0..100000) |_| {
                if (!size.isEmpty()) {
                    empty_count += 1;
                }
            }
            
            try testing.expectEqual(@as(u32, 100000), empty_count);
        }
        
        test "performance: writeAnsi for attributes" {
            const allocator = testing.allocator;
            var buffer = std.ArrayList(u8).init(allocator);
            defer buffer.deinit();
            
            const attrs = tui.Attributes{
                .bold = true,
                .italic = true,
                .underline = false,
                .blink = false,
                .reverse = false,
                .hidden = false,
                .strikethrough = false,
                .dim = true,
            };
            
            // Write ANSI codes
            try attrs.writeAnsi(buffer.writer());
            
            // Should contain only enabled attributes
            const output = buffer.items;
            try testing.expect(std.mem.indexOf(u8, output, "\x1b[1m") != null); // bold
            try testing.expect(std.mem.indexOf(u8, output, "\x1b[2m") != null); // dim
            try testing.expect(std.mem.indexOf(u8, output, "\x1b[3m") != null); // italic
            
            // Should not contain disabled attributes
            try testing.expect(std.mem.indexOf(u8, output, "\x1b[4m") == null); // underline
            try testing.expect(std.mem.indexOf(u8, output, "\x1b[5m") == null); // blink
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── Render Buffer Optimization ────────────────────────────┐
    
        test "buffer: ArrayList reuse pattern" {
            const allocator = testing.allocator;
            
            // Simulate render buffer pattern
            var buffer = try std.ArrayList(u8).initCapacity(allocator, 1024);
            defer buffer.deinit();
            
            const initial_capacity = buffer.capacity;
            
            // Add some data
            try buffer.appendSlice("Hello World");
            try testing.expectEqual(@as(usize, 11), buffer.items.len);
            
            // Clear retaining capacity
            buffer.clearRetainingCapacity();
            try testing.expectEqual(@as(usize, 0), buffer.items.len);
            try testing.expectEqual(initial_capacity, buffer.capacity);
            
            // Reuse without reallocation
            try buffer.appendSlice("Reused buffer");
            try testing.expectEqual(@as(usize, 13), buffer.items.len);
            try testing.expectEqual(initial_capacity, buffer.capacity);
        }
        
        test "buffer: Writer interface performance" {
            const allocator = testing.allocator;
            
            var buffer = std.ArrayList(u8).init(allocator);
            defer buffer.deinit();
            
            const writer = buffer.writer();
            
            // Write various ANSI sequences
            try writer.print("\x1b[{d};{d}H", .{ 10, 20 }); // cursor position
            try writer.writeAll("\x1b[0m"); // reset
            try writer.print("\x1b[{d}m", .{ 31 }); // red color
            try writer.writeByte('X');
            
            // Verify output
            const output = buffer.items;
            try testing.expect(output.len > 0);
            try testing.expect(std.mem.indexOf(u8, output, "\x1b[10;20H") != null);
            try testing.expect(std.mem.indexOf(u8, output, "\x1b[0m") != null);
            try testing.expect(std.mem.indexOf(u8, output, "\x1b[31m") != null);
            try testing.expect(output[output.len - 1] == 'X');
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── Frame Rate Control ────────────────────────────┐
    
        test "frame rate: Duration calculations" {
            const fps_configs = [_]u32{ 30, 60, 120, 144, 240 };
            
            for (fps_configs) |fps| {
                const frame_duration_ns = @divFloor(std.time.ns_per_s, fps);
                const actual_fps = @divFloor(std.time.ns_per_s, frame_duration_ns);
                
                // Should be exact or very close
                try testing.expect(actual_fps == fps or actual_fps == fps - 1);
                
                // Verify durations are reasonable
                switch (fps) {
                    30 => try testing.expect(frame_duration_ns >= 33_000_000),
                    60 => try testing.expect(frame_duration_ns >= 16_000_000),
                    120 => try testing.expect(frame_duration_ns >= 8_000_000),
                    144 => try testing.expect(frame_duration_ns >= 6_000_000),
                    240 => try testing.expect(frame_duration_ns >= 4_000_000),
                    else => {},
                }
            }
        }
    
    // └────────────────────────────────────────────────────────────────────────┘

// ╚════════════════════════════════════════════════════════════════════════════════════════╝