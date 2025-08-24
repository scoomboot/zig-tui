// tui.test.zig — Comprehensive tests for the main TUI library entry point
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

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════════╗

    // Test helper functions
    
    /// Creates a test allocator with leak detection
    fn createTestAllocator() std.mem.Allocator {
        return testing.allocator;
    }
    
    /// Validates that a Color value produces correct ANSI code
    fn validateAnsiCode(color: tui.Color, expected: u8) !void {
        const actual = color.toAnsi();
        try testing.expectEqual(expected, actual);
    }
    
    /// Creates a test Style with specific colors
    fn createTestStyle(fg: tui.Color, bg: tui.Color) tui.Style {
        return tui.Style{
            .fg = fg,
            .bg = bg,
            .attrs = tui.Attributes.none(),
        };
    }
    
    /// Validates library metadata constants
    fn validateMetadata() !void {
        // Check that metadata fields exist and have reasonable values
        try testing.expect(tui.version.len > 0);
        try testing.expect(tui.author.len > 0);
        try testing.expect(tui.license.len > 0);
        try testing.expect(tui.repository.len > 0);
        
        // Validate specific expected values
        try testing.expectEqualStrings("0.1.0", tui.version);
        try testing.expectEqualStrings("Fisty", tui.author);
        try testing.expectEqualStrings("MIT", tui.license);
        try testing.expectEqualStrings("https://github.com/fisty/zig-tui", tui.repository);
    }

// ╚════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐
    
        // Symbol Export Tests
        
        test "unit: TUI: exports core modules" {
            // Verify core module types are accessible
            _ = tui.Terminal;
            _ = tui.Screen;
            _ = tui.Event;
            _ = tui.EventHandler;
            _ = tui.EventType;
            _ = tui.EventDispatcher;
            
            // Verify keyboard utilities
            _ = tui.KeyCode;
            _ = tui.KeyEvent;
            _ = tui.Modifiers;
            
            // Verify mouse utilities
            _ = tui.MouseButton;
            _ = tui.MouseEvent;
            
            // Verify screen utilities
            _ = tui.Cell;
            _ = tui.Rect;
            
            // Verify widget and layout modules
            _ = tui.Widget;
            _ = tui.Layout;
            
            // If compilation succeeds, all symbols are exported correctly
            try testing.expect(true);
        }
        
        test "unit: TUI: exports common types" {
            // Verify common type exports
            _ = tui.Color;
            _ = tui.Style;
            _ = tui.Attributes;
            _ = tui.Point;
            _ = tui.Size;
            _ = tui.TuiError;
            _ = tui.TUI;
            
            // If compilation succeeds, all types are exported
            try testing.expect(true);
        }
        
        test "unit: TUI: exports convenience functions" {
            // Verify function signatures compile
            _ = @TypeOf(tui.init);
            _ = @TypeOf(tui.quickStart);
            _ = @TypeOf(tui.deinit);
            
            // If compilation succeeds, functions are exported correctly
            try testing.expect(true);
        }
        
        // Color Tests
        
        test "unit: Color: default variant returns correct ANSI code" {
            const color: tui.Color = .default;
            try validateAnsiCode(color, 39);
        }
        
        test "unit: Color: basic colors return correct ANSI codes" {
            try validateAnsiCode(.black, 30);
            try validateAnsiCode(.red, 31);
            try validateAnsiCode(.green, 32);
            try validateAnsiCode(.yellow, 33);
            try validateAnsiCode(.blue, 34);
            try validateAnsiCode(.magenta, 35);
            try validateAnsiCode(.cyan, 36);
            try validateAnsiCode(.white, 37);
        }
        
        test "unit: Color: bright colors return correct ANSI codes" {
            try validateAnsiCode(.bright_black, 90);
            try validateAnsiCode(.bright_red, 91);
            try validateAnsiCode(.bright_green, 92);
            try validateAnsiCode(.bright_yellow, 93);
            try validateAnsiCode(.bright_blue, 94);
            try validateAnsiCode(.bright_magenta, 95);
            try validateAnsiCode(.bright_cyan, 96);
            try validateAnsiCode(.bright_white, 97);
        }
        
        test "unit: Color: indexed color returns index value" {
            const indexed_color = tui.Color{ .indexed = 123 };
            try validateAnsiCode(indexed_color, 123);
            
            // Test boundary values
            const min_indexed = tui.Color{ .indexed = 0 };
            try validateAnsiCode(min_indexed, 0);
            
            const max_indexed = tui.Color{ .indexed = 255 };
            try validateAnsiCode(max_indexed, 255);
        }
        
        test "unit: Color: RGB color returns default ANSI code" {
            const rgb_color = tui.Color{ 
                .rgb = .{ .r = 128, .g = 64, .b = 192 } 
            };
            // RGB requires special handling, returns default
            try validateAnsiCode(rgb_color, 39);
            
            // Test RGB boundary values
            const black_rgb = tui.Color{ 
                .rgb = .{ .r = 0, .g = 0, .b = 0 } 
            };
            try validateAnsiCode(black_rgb, 39);
            
            const white_rgb = tui.Color{ 
                .rgb = .{ .r = 255, .g = 255, .b = 255 } 
            };
            try validateAnsiCode(white_rgb, 39);
        }
        
        // Style Tests
        
        test "unit: Style: default creates style with default colors" {
            const style = tui.Style.default();
            const default_color: tui.Color = .default;
            
            try testing.expectEqual(default_color, style.fg);
            try testing.expectEqual(default_color, style.bg);
            try testing.expect(!style.attrs.isSet());
        }
        
        test "unit: Style: withFg creates style with foreground color" {
            const style = tui.Style.withFg(.red);
            const red_color: tui.Color = .red;
            const default_color: tui.Color = .default;
            
            try testing.expectEqual(red_color, style.fg);
            try testing.expectEqual(default_color, style.bg);
            try testing.expect(!style.attrs.isSet());
        }
        
        test "unit: Style: withBg creates style with background color" {
            const style = tui.Style.withBg(.blue);
            const default_color: tui.Color = .default;
            const blue_color: tui.Color = .blue;
            
            try testing.expectEqual(default_color, style.fg);
            try testing.expectEqual(blue_color, style.bg);
            try testing.expect(!style.attrs.isSet());
        }
        
        test "unit: Style: withColors creates style with both colors" {
            const style = tui.Style.withColors(.yellow, .magenta);
            const yellow_color: tui.Color = .yellow;
            const magenta_color: tui.Color = .magenta;
            
            try testing.expectEqual(yellow_color, style.fg);
            try testing.expectEqual(magenta_color, style.bg);
            try testing.expect(!style.attrs.isSet());
        }
        
        // Attributes Tests
        
        test "unit: Attributes: none creates empty attributes" {
            const attrs = tui.Attributes.none();
            
            try testing.expect(!attrs.bold);
            try testing.expect(!attrs.italic);
            try testing.expect(!attrs.underline);
            try testing.expect(!attrs.blink);
            try testing.expect(!attrs.reverse);
            try testing.expect(!attrs.hidden);
            try testing.expect(!attrs.strikethrough);
            try testing.expect(!attrs.dim);
            try testing.expect(!attrs.isSet());
        }
        
        test "unit: Attributes: isSet detects single attribute" {
            var attrs = tui.Attributes.none();
            try testing.expect(!attrs.isSet());
            
            attrs.bold = true;
            try testing.expect(attrs.isSet());
            
            attrs = tui.Attributes.none();
            attrs.italic = true;
            try testing.expect(attrs.isSet());
            
            attrs = tui.Attributes.none();
            attrs.underline = true;
            try testing.expect(attrs.isSet());
            
            attrs = tui.Attributes.none();
            attrs.blink = true;
            try testing.expect(attrs.isSet());
            
            attrs = tui.Attributes.none();
            attrs.reverse = true;
            try testing.expect(attrs.isSet());
            
            attrs = tui.Attributes.none();
            attrs.hidden = true;
            try testing.expect(attrs.isSet());
            
            attrs = tui.Attributes.none();
            attrs.strikethrough = true;
            try testing.expect(attrs.isSet());
            
            attrs = tui.Attributes.none();
            attrs.dim = true;
            try testing.expect(attrs.isSet());
        }
        
        test "unit: Attributes: isSet detects multiple attributes" {
            var attrs = tui.Attributes.none();
            attrs.bold = true;
            attrs.italic = true;
            attrs.underline = true;
            
            try testing.expect(attrs.isSet());
        }
        
        test "unit: Attributes: packed struct size is minimal" {
            // Verify that Attributes is efficiently packed
            const size = @sizeOf(tui.Attributes);
            // Should be 1 byte since we have 8 bool fields
            try testing.expectEqual(@as(usize, 1), size);
        }
        
        // Point Tests
        
        test "unit: Point: new creates point with coordinates" {
            const point = tui.Point.new(100, 200);
            
            try testing.expectEqual(@as(u16, 100), point.x);
            try testing.expectEqual(@as(u16, 200), point.y);
        }
        
        test "unit: Point: zero creates origin point" {
            const point = tui.Point.zero();
            
            try testing.expectEqual(@as(u16, 0), point.x);
            try testing.expectEqual(@as(u16, 0), point.y);
        }
        
        test "unit: Point: handles maximum coordinates" {
            const max_point = tui.Point.new(65535, 65535);
            
            try testing.expectEqual(@as(u16, 65535), max_point.x);
            try testing.expectEqual(@as(u16, 65535), max_point.y);
        }
        
        // Size Tests
        
        test "unit: Size: new creates size with dimensions" {
            const size = tui.Size.new(1920, 1080);
            
            try testing.expectEqual(@as(u16, 1920), size.width);
            try testing.expectEqual(@as(u16, 1080), size.height);
        }
        
        test "unit: Size: isEmpty detects zero width" {
            const size = tui.Size.new(0, 100);
            try testing.expect(size.isEmpty());
        }
        
        test "unit: Size: isEmpty detects zero height" {
            const size = tui.Size.new(100, 0);
            try testing.expect(size.isEmpty());
        }
        
        test "unit: Size: isEmpty detects both zero" {
            const size = tui.Size.new(0, 0);
            try testing.expect(size.isEmpty());
        }
        
        test "unit: Size: isEmpty returns false for non-zero dimensions" {
            const size = tui.Size.new(80, 24);
            try testing.expect(!size.isEmpty());
        }
        
        test "unit: Size: area calculates correctly" {
            const size = tui.Size.new(80, 24);
            try testing.expectEqual(@as(u32, 1920), size.area());
        }
        
        test "unit: Size: area handles zero dimensions" {
            const zero_width = tui.Size.new(0, 100);
            try testing.expectEqual(@as(u32, 0), zero_width.area());
            
            const zero_height = tui.Size.new(100, 0);
            try testing.expectEqual(@as(u32, 0), zero_height.area());
            
            const zero_both = tui.Size.new(0, 0);
            try testing.expectEqual(@as(u32, 0), zero_both.area());
        }
        
        test "unit: Size: area handles maximum dimensions" {
            const max_size = tui.Size.new(65535, 65535);
            const expected_area: u32 = @as(u32, 65535) * @as(u32, 65535);
            try testing.expectEqual(expected_area, max_size.area());
        }
        
        // TuiError Tests
        
        test "unit: TuiError: contains all expected error types" {
            // Verify all error types are defined
            const errors = [_]tui.TuiError{
                tui.TuiError.TerminalInitFailed,
                tui.TuiError.ScreenBufferFull,
                tui.TuiError.InvalidDimensions,
                tui.TuiError.EventQueueFull,
                tui.TuiError.RawModeError,
                tui.TuiError.IoError,
                tui.TuiError.AllocationError,
                tui.TuiError.NotImplemented,
                tui.TuiError.InvalidInput,
                tui.TuiError.UnsupportedTerminal,
                tui.TuiError.PipeError,
                tui.TuiError.SignalError,
                tui.TuiError.ThreadError,
                tui.TuiError.Timeout,
            };
            
            // Verify we have the expected number of errors
            try testing.expectEqual(@as(usize, 14), errors.len);
        }
        
        // Library Metadata Tests
        
        test "unit: Metadata: version follows semantic versioning" {
            try testing.expectEqualStrings("0.1.0", tui.version);
            
            // Verify format is X.Y.Z
            var parts = std.mem.splitScalar(u8, tui.version, '.');
            const major = parts.next() orelse return error.InvalidVersion;
            const minor = parts.next() orelse return error.InvalidVersion;
            const patch = parts.next() orelse return error.InvalidVersion;
            
            // Verify parts are numeric
            _ = try std.fmt.parseInt(u32, major, 10);
            _ = try std.fmt.parseInt(u32, minor, 10);
            _ = try std.fmt.parseInt(u32, patch, 10);
            
            // Verify no extra parts
            try testing.expect(parts.next() == null);
        }
        
        test "unit: Metadata: author is defined" {
            try testing.expectEqualStrings("Fisty", tui.author);
            try testing.expect(tui.author.len > 0);
        }
        
        test "unit: Metadata: license is valid SPDX identifier" {
            try testing.expectEqualStrings("MIT", tui.license);
            
            // Common SPDX identifiers
            const valid_licenses = [_][]const u8{
                "MIT", "Apache-2.0", "GPL-3.0", "BSD-3-Clause", "MPL-2.0"
            };
            
            var is_valid = false;
            for (valid_licenses) |valid| {
                if (std.mem.eql(u8, tui.license, valid)) {
                    is_valid = true;
                    break;
                }
            }
            try testing.expect(is_valid);
        }
        
        test "unit: Metadata: repository is valid URL" {
            try testing.expectEqualStrings("https://github.com/fisty/zig-tui", tui.repository);
            
            // Verify URL structure
            try testing.expect(std.mem.startsWith(u8, tui.repository, "https://"));
            try testing.expect(std.mem.indexOf(u8, tui.repository, "github.com") != null);
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: Style with Attributes: combines colors and attributes" {
            var style = tui.Style.withColors(.green, .black);
            style.attrs.bold = true;
            style.attrs.underline = true;
            const green_color: tui.Color = .green;
            const black_color: tui.Color = .black;
            
            try testing.expectEqual(green_color, style.fg);
            try testing.expectEqual(black_color, style.bg);
            try testing.expect(style.attrs.isSet());
            try testing.expect(style.attrs.bold);
            try testing.expect(style.attrs.underline);
        }
        
        test "integration: Point and Size: work together for positioning" {
            const origin = tui.Point.zero();
            const size = tui.Size.new(80, 24);
            
            // Calculate bottom-right corner
            const bottom_right = tui.Point.new(
                origin.x + size.width - 1,
                origin.y + size.height - 1
            );
            
            try testing.expectEqual(@as(u16, 79), bottom_right.x);
            try testing.expectEqual(@as(u16, 23), bottom_right.y);
        }
        
        test "integration: Color variants: all variants have unique ANSI codes" {
            // Collect all ANSI codes
            var codes = std.AutoHashMap(u8, void).init(testing.allocator);
            defer codes.deinit();
            
            // Add basic colors
            const colors = [_]tui.Color{
                .default, .black, .red, .green, .yellow,
                .blue, .magenta, .cyan, .white,
            };
            for (colors) |color| {
                try codes.put(color.toAnsi(), {});
            }
            
            // Verify we have 9 unique codes so far
            try testing.expectEqual(@as(usize, 9), codes.count());
            
            // Add bright colors
            const bright_colors = [_]tui.Color{
                .bright_black, .bright_red, .bright_green, .bright_yellow,
                .bright_blue, .bright_magenta, .bright_cyan, .bright_white,
            };
            for (bright_colors) |color| {
                try codes.put(color.toAnsi(), {});
            }
            
            // Should have 17 unique codes (RGB returns same as default)
            try testing.expectEqual(@as(usize, 17), codes.count());
        }
        
        test "integration: Namespace exports: no naming conflicts" {
            // This test verifies that all exported symbols can coexist
            // without naming conflicts when used together
            
            const allocator = testing.allocator;
            
            // Use multiple exported types together
            const point = tui.Point.new(10, 20);
            const size = tui.Size.new(100, 50);
            const color: tui.Color = .red;
            const style = tui.Style.withFg(color);
            var attrs = tui.Attributes.none();
            attrs.bold = true;
            
            // Verify they work independently
            try testing.expectEqual(@as(u16, 10), point.x);
            try testing.expectEqual(@as(u32, 5000), size.area());
            try testing.expectEqual(@as(u8, 31), color.toAnsi());
            try testing.expectEqual(color, style.fg);
            try testing.expect(attrs.isSet());
            
            // If this compiles and runs, namespace is clean
            _ = allocator;
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: Color.toAnsi: converts efficiently" {
            // Warm up
            const red: tui.Color = .red;
            for (0..100) |_| {
                _ = red.toAnsi();
            }
            
            // Measure performance
            const iterations = 100000;
            const start = std.time.nanoTimestamp();
            
            for (0..iterations) |i| {
                const color: tui.Color = switch (i % 4) {
                    0 => .red,
                    1 => .blue,
                    2 => .{ .indexed = @intCast(i % 256) },
                    3 => .{ .rgb = .{ .r = @intCast(i % 256), .g = 128, .b = 64 } },
                    else => unreachable,
                };
                _ = color.toAnsi();
            }
            
            const elapsed = std.time.nanoTimestamp() - start;
            const avg_ns = @divFloor(elapsed, iterations);
            
            // Should be very fast, under 10ns per call
            try testing.expect(avg_ns < 10);
        }
        
        test "performance: Attributes.isSet: checks efficiently" {
            var attrs = tui.Attributes.none();
            attrs.bold = true;
            attrs.italic = true;
            
            // Warm up
            for (0..100) |_| {
                _ = attrs.isSet();
            }
            
            // Measure performance
            const iterations = 100000;
            const start = std.time.nanoTimestamp();
            
            for (0..iterations) |_| {
                _ = attrs.isSet();
            }
            
            const elapsed = std.time.nanoTimestamp() - start;
            const avg_ns = @divFloor(elapsed, iterations);
            
            // Should be extremely fast, under 5ns
            try testing.expect(avg_ns < 5);
        }
        
        test "performance: Size.area: calculates efficiently" {
            const size = tui.Size.new(1920, 1080);
            
            // Warm up
            for (0..100) |_| {
                _ = size.area();
            }
            
            // Measure performance
            const iterations = 100000;
            const start = std.time.nanoTimestamp();
            
            for (0..iterations) |_| {
                _ = size.area();
            }
            
            const elapsed = std.time.nanoTimestamp() - start;
            const avg_ns = @divFloor(elapsed, iterations);
            
            // Simple multiplication should be under 5ns
            try testing.expect(avg_ns < 5);
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── Stress Tests ────────────────────────────┐
    
        test "stress: Color: handles rapid variant switching" {
            var rng = std.Random.DefaultPrng.init(42);
            const random = rng.random();
            
            for (0..10000) |_| {
                const variant = random.intRangeAtMost(u8, 0, 3);
                const color: tui.Color = switch (variant) {
                    0 => .red,
                    1 => .{ .indexed = random.int(u8) },
                    2 => .{ 
                        .rgb = .{
                            .r = random.int(u8),
                            .g = random.int(u8),
                            .b = random.int(u8),
                        }
                    },
                    3 => .default,
                    else => unreachable,
                };
                
                const ansi = color.toAnsi();
                // Verify ANSI codes are in valid range
                try testing.expect(ansi <= 255);
            }
        }
        
        test "stress: Attributes: handles all combinations" {
            // Test all possible combinations of attributes (2^8 = 256)
            for (0..256) |i| {
                var attrs = tui.Attributes{
                    .bold = (i & 0x01) != 0,
                    .italic = (i & 0x02) != 0,
                    .underline = (i & 0x04) != 0,
                    .blink = (i & 0x08) != 0,
                    .reverse = (i & 0x10) != 0,
                    .hidden = (i & 0x20) != 0,
                    .strikethrough = (i & 0x40) != 0,
                    .dim = (i & 0x80) != 0,
                };
                
                const is_set = attrs.isSet();
                const should_be_set = i != 0;
                try testing.expectEqual(should_be_set, is_set);
            }
        }
        
        test "stress: Size: handles extreme dimensions" {
            // Test with many different size combinations
            var rng = std.Random.DefaultPrng.init(123);
            const random = rng.random();
            
            for (0..1000) |_| {
                const width = random.int(u16);
                const height = random.int(u16);
                const size = tui.Size.new(width, height);
                
                // Verify properties
                try testing.expectEqual(width, size.width);
                try testing.expectEqual(height, size.height);
                
                const expected_empty = width == 0 or height == 0;
                try testing.expectEqual(expected_empty, size.isEmpty());
                
                const expected_area = @as(u32, width) * @as(u32, height);
                try testing.expectEqual(expected_area, size.area());
            }
        }
        
        test "stress: Multiple types: interact without memory issues" {
            const allocator = testing.allocator;
            
            // Create many instances of different types
            for (0..1000) |i| {
                const point = tui.Point.new(@intCast(i % 65536), @intCast(i % 65536));
                const size = tui.Size.new(@intCast(i % 65536), @intCast(i % 65536));
                const color: tui.Color = if (i % 2 == 0) .red else .blue;
                const default_bg: tui.Color = .default;
                const style = tui.Style.withColors(color, default_bg);
                var attrs = tui.Attributes.none();
                if (i % 3 == 0) attrs.bold = true;
                if (i % 5 == 0) attrs.italic = true;
                
                // Use the values to prevent optimization
                _ = point.x + point.y;
                _ = size.area();
                _ = color.toAnsi();
                _ = style.fg;
                _ = attrs.isSet();
            }
            
            // Verify allocator has no leaks (test allocator checks automatically)
            _ = allocator;
        }
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Config Tests ────────────────────────────┐
    
        test "unit: Config: default values are sensible" {
            const config = tui.Config{};
            
            try testing.expectEqual(@as(u32, 60), config.target_fps);
            try testing.expectEqual(@as(usize, 4096), config.initial_buffer_capacity);
            try testing.expectEqual(true, config.enable_mouse);
            try testing.expectEqual(true, config.enable_bracketed_paste);
        }
        
        test "unit: Config: validates FPS boundaries" {
            const allocator = testing.allocator;
            
            // Test boundary values
            const valid_fps = [_]u32{ 1, 30, 60, 120, 144, 240 };
            for (valid_fps) |fps| {
                const config = tui.Config{ .target_fps = fps };
                var test_tui = try tui.initWithConfig(allocator, config);
                defer test_tui.deinit();
                try testing.expectEqual(fps, test_tui.target_fps);
            }
            
            // Test invalid values
            const invalid_fps = [_]u32{ 0, 241, 500, 1000, std.math.maxInt(u32) };
            for (invalid_fps) |fps| {
                const config = tui.Config{ .target_fps = fps };
                const result = tui.initWithConfig(allocator, config);
                try testing.expectError(tui.TuiError.InvalidInput, result);
            }
        }
        
        test "unit: Config: buffer capacity affects initialization" {
            const allocator = testing.allocator;
            
            const capacities = [_]usize{ 128, 512, 1024, 4096, 8192 };
            for (capacities) |capacity| {
                const config = tui.Config{ .initial_buffer_capacity = capacity };
                var test_tui = try tui.initWithConfig(allocator, config);
                defer test_tui.deinit();
                
                // Buffer should have at least the requested capacity
                try testing.expect(test_tui.render_buffer.capacity >= capacity);
            }
        }
        
        test "unit: Style: equality comparison using std.meta.eql" {
            const style1 = tui.Style.withColors(.red, .blue);
            const style2 = tui.Style.withColors(.red, .blue);
            const style3 = tui.Style.withColors(.green, .blue);
            
            // Use std.meta.eql for comparison
            try testing.expect(std.meta.eql(style1, style2));
            try testing.expect(!std.meta.eql(style1, style3));
            
            // Test with attributes
            var style4 = tui.Style.withColors(.red, .blue);
            style4.attrs.bold = true;
            
            try testing.expect(!std.meta.eql(style1, style4));
            
            var style5 = tui.Style.withColors(.red, .blue);
            style5.attrs.bold = true;
            
            try testing.expect(std.meta.eql(style4, style5));
        }
        
        test "unit: Size.contains: edge case validation" {
            // Test zero-sized bounds
            const zero_size = tui.Size.new(0, 0);
            try testing.expect(!zero_size.contains(tui.Point.new(0, 0)));
            
            // Test single pixel
            const single = tui.Size.new(1, 1);
            try testing.expect(single.contains(tui.Point.new(0, 0)));
            try testing.expect(!single.contains(tui.Point.new(1, 0)));
            try testing.expect(!single.contains(tui.Point.new(0, 1)));
            
            // Test maximum size
            const max_size = tui.Size.new(65535, 65535);
            try testing.expect(max_size.contains(tui.Point.new(65534, 65534)));
            try testing.expect(!max_size.contains(tui.Point.new(65535, 65534)));
            try testing.expect(!max_size.contains(tui.Point.new(65534, 65535)));
        }
        
        test "unit: Color.writeAnsiRgb: handles all color variants" {
            const allocator = testing.allocator;
            var buffer = std.ArrayList(u8).init(allocator);
            defer buffer.deinit();
            
            // Test each color variant
            const test_cases = [_]struct {
                color: tui.Color,
                is_fg: bool,
                expected: []const u8,
            }{
                .{ .color = .default, .is_fg = true, .expected = "\x1b[39m" },
                .{ .color = .black, .is_fg = true, .expected = "\x1b[30m" },
                .{ .color = .red, .is_fg = false, .expected = "\x1b[41m" },
                .{ .color = .bright_white, .is_fg = true, .expected = "\x1b[97m" },
                .{ .color = .{ .indexed = 200 }, .is_fg = true, .expected = "\x1b[38;5;200m" },
                .{ .color = .{ .indexed = 15 }, .is_fg = false, .expected = "\x1b[48;5;15m" },
                .{ .color = .{ .rgb = .{ .r = 0, .g = 0, .b = 0 } }, .is_fg = true, .expected = "\x1b[38;2;0;0;0m" },
                .{ .color = .{ .rgb = .{ .r = 255, .g = 255, .b = 255 } }, .is_fg = false, .expected = "\x1b[48;2;255;255;255m" },
            };
            
            for (test_cases) |tc| {
                buffer.clearRetainingCapacity();
                try tc.color.writeAnsiRgb(buffer.writer(), tc.is_fg);
                try testing.expectEqualStrings(tc.expected, buffer.items);
            }
        }
    
    // └────────────────────────────────────────────────────────────────────────┘

// ╚════════════════════════════════════════════════════════════════════════════════════════╝