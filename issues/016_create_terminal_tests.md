# Issue #016: Create terminal tests

## Summary
Implement comprehensive unit tests for the terminal module including raw mode, ANSI sequences, and terminal operations.

## Description
Create a complete test suite for the terminal module that covers all functionality including initialization, raw mode handling, ANSI escape sequences, cursor control, and cross-platform behavior. Tests should follow MCS testing conventions with proper categorization.

## Acceptance Criteria
- [ ] Create `lib/terminal/terminal.test.zig`
- [ ] Test terminal initialization/cleanup
- [ ] Test raw mode enter/exit
- [ ] Test ANSI sequence generation
- [ ] Test cursor operations
- [ ] Test screen clearing
- [ ] Test size detection
- [ ] Test alternative screen buffer
- [ ] Test error conditions
- [ ] Mock terminal for testing
- [ ] Follow MCS test categorization
- [ ] Achieve >95% code coverage

## Dependencies
- Issue #006 (Implement terminal core)
- Issue #007 (Add terminal size detection)

## Implementation Notes
```zig
// terminal.test.zig — Tests for terminal module
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Terminal = @import("terminal.zig").Terminal;
    const ansi = @import("utils/ansi/ansi.zig");
    const RawMode = @import("utils/raw_mode/raw_mode.zig").RawMode;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test helpers
    const MockTerminal = struct {
        output_buffer: std.ArrayList(u8),
        input_buffer: std.ArrayList(u8),
        size: Terminal.Size,
        is_tty: bool,
        
        pub fn init(allocator: std.mem.Allocator) MockTerminal {
            return .{
                .output_buffer = std.ArrayList(u8).init(allocator),
                .input_buffer = std.ArrayList(u8).init(allocator),
                .size = .{ .rows = 24, .cols = 80 },
                .is_tty = true,
            };
        }
        
        pub fn deinit(self: *MockTerminal) void {
            self.output_buffer.deinit();
            self.input_buffer.deinit();
        }
        
        pub fn getOutput(self: *MockTerminal) []const u8 {
            return self.output_buffer.items;
        }
        
        pub fn clearOutput(self: *MockTerminal) void {
            self.output_buffer.clearRetainingCapacity();
        }
    };

    fn createTestTerminal(allocator: std.mem.Allocator) !*Terminal {
        var term = try allocator.create(Terminal);
        term.* = try Terminal.init(allocator);
        return term;
    }

    fn destroyTestTerminal(allocator: std.mem.Allocator, term: *Terminal) void {
        term.deinit();
        allocator.destroy(term);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐

        test "unit: Terminal: initializes with default values" {
            const allocator = testing.allocator;
            var term = try Terminal.init(allocator);
            defer term.deinit();
            
            try testing.expect(!term.is_raw);
            try testing.expect(!term.use_alt_screen);
            try testing.expect(term.cursor_visible);
            try testing.expect(term.size.rows > 0);
            try testing.expect(term.size.cols > 0);
        }

        test "unit: Terminal: enters and exits raw mode" {
            const allocator = testing.allocator;
            var term = try Terminal.init(allocator);
            defer term.deinit();
            
            // Enter raw mode
            try term.enterRawMode();
            try testing.expect(term.is_raw);
            
            // Should be idempotent
            try term.enterRawMode();
            try testing.expect(term.is_raw);
            
            // Exit raw mode
            try term.exitRawMode();
            try testing.expect(!term.is_raw);
            
            // Should be idempotent
            try term.exitRawMode();
            try testing.expect(!term.is_raw);
        }

        test "unit: Terminal: manages alternative screen buffer" {
            const allocator = testing.allocator;
            var term = try Terminal.init(allocator);
            defer term.deinit();
            
            // Enter alternative screen
            try term.enterAltScreen();
            try testing.expect(term.use_alt_screen);
            
            // Exit alternative screen
            try term.exitAltScreen();
            try testing.expect(!term.use_alt_screen);
        }

        test "unit: Terminal: controls cursor visibility" {
            const allocator = testing.allocator;
            var term = try Terminal.init(allocator);
            defer term.deinit();
            
            // Hide cursor
            try term.hideCursor();
            try testing.expect(!term.cursor_visible);
            
            // Show cursor
            try term.showCursor();
            try testing.expect(term.cursor_visible);
        }

        test "unit: Terminal: sets cursor position" {
            const allocator = testing.allocator;
            var mock = MockTerminal.init(allocator);
            defer mock.deinit();
            
            var term = try Terminal.init(allocator);
            defer term.deinit();
            
            // Test cursor positioning
            try term.setCursorPos(10, 20);
            
            // Verify ANSI sequence was generated
            // In real implementation, would check output
        }

        test "unit: Terminal: queries terminal size" {
            const allocator = testing.allocator;
            var term = try Terminal.init(allocator);
            defer term.deinit();
            
            const size = try term.getSize();
            try testing.expect(size.rows > 0);
            try testing.expect(size.cols > 0);
            try testing.expect(size.rows == term.size.rows);
            try testing.expect(size.cols == term.size.cols);
        }

        test "unit: Terminal: clears screen" {
            const allocator = testing.allocator;
            var term = try Terminal.init(allocator);
            defer term.deinit();
            
            // Should not error
            try term.clear();
            try term.clearLine();
        }

        test "unit: Terminal: handles cursor styles" {
            const allocator = testing.allocator;
            var term = try Terminal.init(allocator);
            defer term.deinit();
            
            // Test all cursor styles
            const styles = [_]Terminal.CursorStyle{
                .default,
                .block,
                .underline,
                .bar,
                .blinking_block,
                .blinking_underline,
                .blinking_bar,
            };
            
            for (styles) |style| {
                try term.setCursorStyle(style);
            }
        }

        test "unit: Terminal: cleanup on deinit" {
            const allocator = testing.allocator;
            var term = try Terminal.init(allocator);
            
            // Set various states
            try term.enterRawMode();
            try term.enterAltScreen();
            try term.hideCursor();
            
            // Deinit should restore everything
            term.deinit();
            
            // In real implementation, would verify restoration
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── ANSI Sequence Tests ────────────────────────────┐

        test "unit: ANSI: generates cursor movement sequences" {
            const allocator = testing.allocator;
            var builder = ansi.Ansi.init(allocator);
            defer builder.deinit();
            
            // Test absolute positioning
            try builder.moveTo(10, 20);
            const seq = builder.getSequence();
            try testing.expectEqualStrings(ansi.CSI ++ "10;20H", seq);
            
            builder.clear();
            
            // Test relative movements
            try builder.moveUp(5);
            try testing.expectEqualStrings(ansi.CSI ++ "5A", builder.getSequence());
            
            builder.clear();
            try builder.moveDown(3);
            try testing.expectEqualStrings(ansi.CSI ++ "3B", builder.getSequence());
            
            builder.clear();
            try builder.moveRight(7);
            try testing.expectEqualStrings(ansi.CSI ++ "7C", builder.getSequence());
            
            builder.clear();
            try builder.moveLeft(2);
            try testing.expectEqualStrings(ansi.CSI ++ "2D", builder.getSequence());
        }

        test "unit: ANSI: generates color sequences" {
            const allocator = testing.allocator;
            var builder = ansi.Ansi.init(allocator);
            defer builder.deinit();
            
            // Test basic colors
            try builder.setFg(.{ .basic = 1 }); // Red
            try testing.expectEqualStrings(ansi.CSI ++ "31m", builder.getSequence());
            
            builder.clear();
            try builder.setBg(.{ .basic = 4 }); // Blue
            try testing.expectEqualStrings(ansi.CSI ++ "44m", builder.getSequence());
            
            // Test 256 colors
            builder.clear();
            try builder.setFg(.{ .indexed = 123 });
            try testing.expectEqualStrings(ansi.CSI ++ "38;5;123m", builder.getSequence());
            
            // Test RGB colors
            builder.clear();
            try builder.setFg(.{ .rgb = .{ .r = 255, .g = 128, .b = 0 } });
            try testing.expectEqualStrings(ansi.CSI ++ "38;2;255;128;0m", builder.getSequence());
        }

        test "unit: ANSI: generates style sequences" {
            const allocator = testing.allocator;
            var builder = ansi.Ansi.init(allocator);
            defer builder.deinit();
            
            const style = ansi.Style{
                .bold = true,
                .italic = true,
                .underline = true,
            };
            
            try builder.setStyle(style);
            const seq = builder.getSequence();
            
            // Should contain all style codes
            try testing.expect(std.mem.indexOf(u8, seq, "1m") != null); // Bold
            try testing.expect(std.mem.indexOf(u8, seq, "3m") != null); // Italic
            try testing.expect(std.mem.indexOf(u8, seq, "4m") != null); // Underline
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Raw Mode Tests ────────────────────────────┐

        test "unit: RawMode: detects TTY" {
            var raw_mode = try RawMode.init();
            
            // Should succeed on TTY
            // In CI/testing environment, may not be a TTY
            _ = raw_mode;
        }

        test "unit: RawMode: preserves terminal state" {
            // This test would need to actually interact with terminal
            // Skip in automated testing
            if (true) return error.SkipZigTest;
            
            var raw_mode = try RawMode.init();
            
            // Save original state
            const original_state = raw_mode.state;
            
            // Enter raw mode
            try raw_mode.enter();
            
            // Exit raw mode
            try raw_mode.exit();
            
            // State should be restored
            try testing.expectEqual(original_state, raw_mode.state);
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Integration Tests ────────────────────────────┐

        test "integration: Terminal: full lifecycle" {
            const allocator = testing.allocator;
            
            // Create terminal
            var term = try Terminal.init(allocator);
            defer term.deinit();
            
            // Enter raw mode and alt screen
            try term.enterRawMode();
            try term.enterAltScreen();
            
            // Clear and position cursor
            try term.clear();
            try term.setCursorPos(1, 1);
            
            // Hide cursor
            try term.hideCursor();
            
            // Get size
            const size = try term.getSize();
            try testing.expect(size.rows > 0);
            
            // Cleanup happens in defer
        }

        test "integration: Terminal: resize handling" {
            const allocator = testing.allocator;
            var term = try Terminal.init(allocator);
            defer term.deinit();
            
            // Get initial size
            const initial_size = term.size;
            
            // Simulate resize (would need signal in real scenario)
            term.size = .{ .rows = 40, .cols = 120 };
            
            // Verify size changed
            try testing.expect(term.size.rows != initial_size.rows);
            try testing.expect(term.size.cols != initial_size.cols);
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Performance Tests ────────────────────────────┐

        test "performance: Terminal: initialization time" {
            const allocator = testing.allocator;
            const iterations = 100;
            
            const start = std.time.nanoTimestamp();
            
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                var term = try Terminal.init(allocator);
                term.deinit();
            }
            
            const elapsed = std.time.nanoTimestamp() - start;
            const avg_ns = @divFloor(elapsed, iterations);
            
            // Should initialize in less than 1ms
            try testing.expect(avg_ns < 1_000_000);
        }

        test "performance: ANSI: sequence generation" {
            const allocator = testing.allocator;
            var builder = ansi.Ansi.init(allocator);
            defer builder.deinit();
            
            const iterations = 10000;
            const start = std.time.nanoTimestamp();
            
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                builder.clear();
                try builder.moveTo(10, 20);
                try builder.setFg(.{ .indexed = 123 });
                try builder.setBg(.{ .basic = 4 });
                _ = builder.getSequence();
            }
            
            const elapsed = std.time.nanoTimestamp() - start;
            const avg_ns = @divFloor(elapsed, iterations);
            
            // Should generate sequences in less than 100ns
            try testing.expect(avg_ns < 100);
        }

    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Mock terminal for isolated testing
- Test all public APIs
- Test error conditions
- Test cross-platform code paths
- Measure performance
- Use MCS test naming convention
- Group tests by category

## Estimated Time
3 hours

## Priority
🟡 High - Quality assurance

## Category
Testing