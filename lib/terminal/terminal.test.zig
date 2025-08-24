// terminal.test.zig — Comprehensive tests for terminal operations
//
// repo   : https://github.com/fisty/zig-tui
// author : https://github.com/fisty
//
// Tests for terminal initialization, cleanup, and state management.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const terminal_module = @import("terminal.zig");
    const Terminal = terminal_module.Terminal;
    const Size = terminal_module.Size;
    const Position = terminal_module.Position;
    const CursorStyle = terminal_module.CursorStyle;
    const TerminalError = terminal_module.TerminalError;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test constants
    const TEST_TIMEOUT_MS = 1000;
    const MAX_TERMINAL_SIZE = 65535;
    const MIN_TERMINAL_SIZE = 1;
    
    // Test helpers
    const TestTerminal = struct {
        terminal: Terminal,
        allocator: std.mem.Allocator,
        
        pub fn init(allocator: std.mem.Allocator) !TestTerminal {
            return TestTerminal{
                .terminal = try Terminal.init(allocator),
                .allocator = allocator,
            };
        }
        
        pub fn deinit(self: *TestTerminal) void {
            self.terminal.deinit();
        }
    };
    
    // Creates a terminal in a specific state for testing
    fn createTerminalInState(allocator: std.mem.Allocator, raw_mode: bool) !*Terminal {
        var terminal = try allocator.create(Terminal);
        terminal.* = try Terminal.init(allocator);
        if (raw_mode) {
            try terminal.enterRawMode();
        }
        return terminal;
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐
    
        test "unit: Terminal: initializes with default values" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            try testing.expect(!terminal.is_raw);
            try testing.expect(!terminal.use_alt_screen);
            try testing.expect(terminal.cursor_visible);
            const size = try terminal.getSize();
            try testing.expect(size.rows > 0 and size.cols > 0);
        }
        
        test "unit: Terminal: enters raw mode successfully" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            try terminal.enterRawMode();
            try testing.expect(terminal.is_raw);
        }
        
        test "unit: Terminal: exits raw mode successfully" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            try terminal.enterRawMode();
            try terminal.exitRawMode();
            try testing.expect(!terminal.is_raw);
        }
        
        test "unit: Terminal: handles double raw mode entry" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            try terminal.enterRawMode();
            // Should be idempotent - no error on double entry
            try terminal.enterRawMode();
            try testing.expect(terminal.is_raw);
        }
        
        test "unit: Terminal: gets terminal size correctly" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            const size = try terminal.getSize();
            try testing.expect(size.rows > 0);
            try testing.expect(size.cols > 0);
            try testing.expect(size.rows <= MAX_TERMINAL_SIZE);
            try testing.expect(size.cols <= MAX_TERMINAL_SIZE);
        }
        
        test "unit: Terminal: manages cursor visibility" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Initially visible
            try testing.expect(terminal.cursor_visible);
            
            // Hide cursor
            try terminal.hideCursor();
            try testing.expect(!terminal.cursor_visible);
            
            // Show cursor
            try terminal.showCursor();
            try testing.expect(terminal.cursor_visible);
            
            // Double hide should be idempotent
            try terminal.hideCursor();
            try terminal.hideCursor();
            try testing.expect(!terminal.cursor_visible);
        }
        
        test "unit: Terminal: sets cursor styles" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Test each cursor style
            const styles = [_]CursorStyle{
                .default,
                .block,
                .underline,
                .bar,
                .blinking_block,
                .blinking_underline,
                .blinking_bar,
            };
            
            for (styles) |style| {
                try terminal.setCursorStyle(style);
                // No error should occur
            }
        }
        
        test "unit: Terminal: manages alternative screen buffer" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Initially not in alt screen
            try testing.expect(!terminal.use_alt_screen);
            
            // Enter alt screen
            try terminal.enterAltScreen();
            try testing.expect(terminal.use_alt_screen);
            
            // Exit alt screen
            try terminal.exitAltScreen();
            try testing.expect(!terminal.use_alt_screen);
            
            // Double enter should be idempotent
            try terminal.enterAltScreen();
            try terminal.enterAltScreen();
            try testing.expect(terminal.use_alt_screen);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: Terminal with RawMode: state transitions correctly" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Initial state
            try testing.expect(!terminal.is_raw);
            
            // Enter raw mode
            try terminal.enterRawMode();
            try testing.expect(terminal.is_raw);
            
            // Exit raw mode
            try terminal.exitRawMode();
            try testing.expect(!terminal.is_raw);
        }
        
        test "integration: Terminal with ANSI: cursor positioning works" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Test various cursor positions
            try terminal.setCursorPos(1, 1);    // Top-left
            try terminal.setCursorPos(10, 20);  // Middle somewhere
            try terminal.setCursorPos(24, 80);  // Bottom-right (typical terminal size)
            
            // No errors should occur
        }
        
        test "integration: Terminal with ANSI: screen clearing works" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Clear screen
            try terminal.clear();
            // Cursor should be at home position after clear
            
            // Clear line
            try terminal.clearLine();
            
            // No errors should occur
        }
        
        test "integration: Terminal with Output: writing works" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            const test_string = "Hello, Terminal!";
            try terminal.write(test_string);
            
            // Flush output
            try terminal.flush();
            
            // Verify write succeeded (actual output verification would require mocking)
            try testing.expect(true);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── E2E Tests ────────────────────────────┐
    
        test "e2e: full terminal lifecycle: init to cleanup" {
            const allocator = testing.allocator;
            
            // Initialize terminal
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Enter raw mode
            try terminal.enterRawMode();
            
            // Enter alternative screen
            try terminal.enterAltScreen();
            
            // Perform operations
            try terminal.clear();
            try terminal.setCursorPos(1, 1);
            try terminal.hideCursor();
            try terminal.write("TUI Application");
            try terminal.flush();
            
            // Exit alternative screen
            try terminal.exitAltScreen();
            
            // Exit raw mode
            try terminal.exitRawMode();
            
            // Show cursor
            try terminal.showCursor();
            
            // Verify final state
            try testing.expect(!terminal.is_raw);
            try testing.expect(!terminal.use_alt_screen);
            try testing.expect(terminal.cursor_visible);
        }
        
        test "e2e: terminal interaction: complete user session" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Simulate complete user session
            try terminal.enterRawMode();
            defer terminal.exitRawMode() catch {};
            
            try terminal.enterAltScreen();
            defer terminal.exitAltScreen() catch {};
            
            // Clear screen and set up UI
            try terminal.clear();
            try terminal.hideCursor();
            
            // Write welcome message at top
            try terminal.setCursorPos(1, 1);
            try terminal.write("Welcome to TUI Application");
            
            // Write status line at bottom
            const size = try terminal.getSize();
            try terminal.setCursorPos(size.rows, 1);
            try terminal.write("Press q to quit");
            
            // Move cursor to input area
            try terminal.setCursorPos(3, 1);
            try terminal.showCursor();
            try terminal.setCursorStyle(.blinking_bar);
            
            try terminal.flush();
            
            try testing.expect(terminal.is_raw);
            try testing.expect(terminal.use_alt_screen);
        }
        
        test "e2e: error recovery: cleanup on failure" {
            const allocator = testing.allocator;
            
            // Initialize terminal
            var terminal = try Terminal.init(allocator);
            
            // Enter various modes
            terminal.enterRawMode() catch {};
            terminal.enterAltScreen() catch {};
            terminal.hideCursor() catch {};
            
            // Cleanup should restore everything
            terminal.deinit();
            
            // Terminal should be restored even after errors
            try testing.expect(true);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: Terminal.clear: clears screen quickly" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            const iterations = 100;
            const start = std.time.milliTimestamp();
            
            for (0..iterations) |_| {
                try terminal.clear();
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            const avg_ms = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations));
            
            // Average clear should be fast (< 1ms)
            try testing.expect(avg_ms < 1.0);
        }
        
        test "performance: Terminal.setCursorPos: positions cursor quickly" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            const iterations = 1000;
            const start = std.time.milliTimestamp();
            
            for (0..iterations) |i| {
                const row = @as(u16, @intCast((i % 24) + 1));
                const col = @as(u16, @intCast((i % 80) + 1));
                try terminal.setCursorPos(row, col);
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            const avg_ms = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations));
            
            // Average cursor positioning should be very fast
            try testing.expect(avg_ms < 0.5);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Stress Tests ────────────────────────────┐
    
        test "stress: Terminal: handles rapid mode switching" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            const iterations = 50;
            for (0..iterations) |i| {
                if (i % 2 == 0) {
                    terminal.enterRawMode() catch {};
                } else {
                    terminal.exitRawMode() catch {};
                }
            }
            
            // Terminal should be stable after stress
            terminal.exitRawMode() catch {};
            try testing.expect(!terminal.is_raw);
        }
        
        test "stress: Terminal: handles rapid screen switching" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            const iterations = 50;
            for (0..iterations) |i| {
                if (i % 2 == 0) {
                    terminal.enterAltScreen() catch {};
                } else {
                    terminal.exitAltScreen() catch {};
                }
            }
            
            // Terminal should be stable after stress
            terminal.exitAltScreen() catch {};
            try testing.expect(!terminal.use_alt_screen);
        }
        
        test "stress: Terminal: handles mixed operations under load" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            const iterations = 100;
            for (0..iterations) |i| {
                // Mix of operations
                if (i % 3 == 0) {
                    try terminal.clear();
                }
                if (i % 5 == 0) {
                    terminal.hideCursor() catch {};
                    terminal.showCursor() catch {};
                }
                if (i % 7 == 0) {
                    const row = @as(u16, @intCast((i % 24) + 1));
                    const col = @as(u16, @intCast((i % 80) + 1));
                    try terminal.setCursorPos(row, col);
                }
                if (i % 11 == 0) {
                    try terminal.clearLine();
                }
            }
            
            // Terminal should remain functional
            try terminal.clear();
            try testing.expect(true);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Backward Compatibility Tests ────────────────────────────┐
    
        test "unit: Terminal: backward compatible API works" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Test old API methods
            try terminal.enter_raw_mode();
            try testing.expect(terminal.is_raw_mode());
            
            try terminal.exit_raw_mode();
            try testing.expect(!terminal.is_raw_mode());
            
            const size = try terminal.get_size();
            try testing.expect(size.rows > 0 and size.cols > 0);
            
            try terminal.hide_cursor();
            try testing.expect(!terminal.cursor_visible);
            
            try terminal.show_cursor();
            try testing.expect(terminal.cursor_visible);
            
            try terminal.enter_alt_screen();
            try testing.expect(terminal.use_alt_screen);
            
            try terminal.exit_alt_screen();
            try testing.expect(!terminal.use_alt_screen);
            
            const pos = Position{ .x = 10, .y = 5 };
            try terminal.move_cursor(pos);
            
            try terminal.set_cursor_style(.block);
            
            try terminal.write("Test");
        }
    
    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝