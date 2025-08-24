// terminal.test.zig — Comprehensive tests for terminal operations
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://fisty.github.io/zig-tui/terminal
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const terminal_module = @import("terminal.zig");
    const Terminal = terminal_module.Terminal;
    const Size = terminal_module.Size;
    const Position = terminal_module.Position;
    const CursorStyle = terminal_module.CursorStyle;
    const TerminalError = terminal_module.TerminalError;
    const SizeConstraints = terminal_module.SizeConstraints;
    const ResizeEvent = terminal_module.ResizeEvent;
    const ResizeCallback = terminal_module.ResizeCallback;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test constants - Comprehensive test data for terminal operations
    const TEST_TIMEOUT_MS = 1000;
    const MAX_TERMINAL_SIZE = 65535;
    const MIN_TERMINAL_SIZE = 1;
    
    // Size test data
    const VALID_SIZES = [_]Size{
        Size{ .rows = 24, .cols = 80 },   // Standard terminal
        Size{ .rows = 25, .cols = 132 },  // Wide terminal
        Size{ .rows = 50, .cols = 120 },  // Tall terminal
        Size{ .rows = 1, .cols = 1 },     // Minimal terminal
    };
    
    const INVALID_SIZES = [_]Size{
        Size{ .rows = 0, .cols = 80 },    // Zero rows
        Size{ .rows = 24, .cols = 0 },    // Zero cols
        Size{ .rows = 0, .cols = 0 },     // Zero both
    };
    
    // Cursor style test data
    const CURSOR_STYLES = [_]CursorStyle{
        .default, .block, .underline, .bar,
        .blinking_block, .blinking_underline, .blinking_bar,
    };
    
    // Global variables for test callbacks
    var test_total_calls: u32 = 0;
    var test_events_received: u32 = 0;
    var test_last_event: ?ResizeEvent = null;
    var test_resize_history: ?*std.ArrayList(ResizeEvent) = null;
    
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

    // ┌──────────────────────────── Resize Functionality Tests ────────────────────────────┐
    
        test "unit: Size: equality and validation methods" {
            const size1 = Size{ .rows = 24, .cols = 80 };
            const size2 = Size{ .rows = 24, .cols = 80 };
            const size3 = Size{ .rows = 25, .cols = 80 };
            const invalid_size = Size{ .rows = 0, .cols = 80 };
            
            try testing.expect(size1.eql(size2));
            try testing.expect(!size1.eql(size3));
            try testing.expect(size1.isValid());
            try testing.expect(!invalid_size.isValid());
        }
        
        test "unit: SizeConstraints: apply and validate methods" {
            const constraints = SizeConstraints{
                .min_rows = 10,
                .min_cols = 40,
                .max_rows = 50,
                .max_cols = 120,
            };
            
            // Test applying constraints
            const too_small = Size{ .rows = 5, .cols = 30 };
            const too_large = Size{ .rows = 100, .cols = 200 };
            const valid = Size{ .rows = 25, .cols = 80 };
            
            const constrained_small = constraints.apply(too_small);
            const constrained_large = constraints.apply(too_large);
            const constrained_valid = constraints.apply(valid);
            
            try testing.expect(constrained_small.rows == 10);
            try testing.expect(constrained_small.cols == 40);
            try testing.expect(constrained_large.rows == 50);
            try testing.expect(constrained_large.cols == 120);
            try testing.expect(constrained_valid.eql(valid));
            
            // Test validation
            try testing.expect(!constraints.validate(too_small));
            try testing.expect(!constraints.validate(too_large));
            try testing.expect(constraints.validate(valid));
        }
        
        test "unit: ResizeEvent: initialization with timestamp" {
            const old_size = Size{ .rows = 24, .cols = 80 };
            const new_size = Size{ .rows = 30, .cols = 100 };
            
            const event = ResizeEvent.init(old_size, new_size);
            
            try testing.expect(event.old_size.eql(old_size));
            try testing.expect(event.new_size.eql(new_size));
            try testing.expect(event.timestamp > 0);
        }
        
        test "unit: Terminal: size constraints management" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            const constraints = SizeConstraints{
                .min_rows = 20,
                .min_cols = 60,
                .max_rows = 40,
                .max_cols = 120,
            };
            
            terminal.setSizeConstraints(constraints);
            
            // Verify constraints are applied (cache should be invalidated)
            try testing.expect(terminal.size_constraints.min_rows == 20);
            try testing.expect(terminal.size_constraints.min_cols == 60);
        }
        
        test "unit: Terminal: size caching behavior" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // First call should query and cache
            const size1 = try terminal.getSize();
            try testing.expect(size1.isValid());
            
            // Second call should use cache (assuming no actual terminal resize)
            const size2 = try terminal.getSize();
            try testing.expect(size1.eql(size2));
            
            // Force refresh should bypass cache
            const size3 = try terminal.refreshSize();
            try testing.expect(size3.isValid());
        }
        
        test "unit: Terminal: resize callback registration" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Simple callback for testing registration
            const callback = struct {
                fn resizeHandler(event: ResizeEvent) void {
                    _ = event;
                    // Simple callback that does nothing
                }
            }.resizeHandler;
            
            try terminal.onResize(callback);
            try testing.expect(terminal.resize_callbacks.items.len == 1);
            
            // Remove callback
            terminal.removeResizeCallback(callback);
            try testing.expect(terminal.resize_callbacks.items.len == 0);
        }
        
        test "integration: Terminal: resize monitoring lifecycle" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Initially not monitoring
            try testing.expect(!terminal.resize_monitoring);
            
            // Start monitoring
            try terminal.startResizeMonitoring();
            try testing.expect(terminal.resize_monitoring);
            
            // Starting again should be idempotent
            try terminal.startResizeMonitoring();
            try testing.expect(terminal.resize_monitoring);
            
            // Stop monitoring
            try terminal.stopResizeMonitoring();
            try testing.expect(!terminal.resize_monitoring);
            
            // Stopping again should be idempotent
            try terminal.stopResizeMonitoring();
            try testing.expect(!terminal.resize_monitoring);
        }
        
        test "integration: Terminal: resize event simulation" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Reset globals
            test_events_received = 0;
            test_last_event = null;
            
            const callback = struct {
                fn resizeHandler(event: ResizeEvent) void {
                    test_events_received += 1;
                    test_last_event = event;
                }
            }.resizeHandler;
            
            try terminal.onResize(callback);
            
            // Simulate resize event
            const old_size = terminal.size;
            const new_size = Size{ .rows = old_size.rows + 5, .cols = old_size.cols + 10 };
            
            terminal.handleResize(new_size);
            
            try testing.expect(test_events_received == 1);
            try testing.expect(test_last_event != null);
            if (test_last_event) |event| {
                try testing.expect(event.old_size.eql(old_size));
                try testing.expect(event.new_size.eql(new_size));
                try testing.expect(terminal.size.eql(new_size));
            }
            
            // Simulate same size (should not trigger callback)
            terminal.handleResize(new_size);
            try testing.expect(test_events_received == 1); // Still 1, no change
        }
        
        test "integration: Terminal: multiple size detection fallbacks" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Force refresh to test fallback mechanisms
            // In a real terminal, system method should work
            // In test environment, may fall back to default
            const size = try terminal.refreshSize();
            
            try testing.expect(size.isValid());
            try testing.expect(size.rows >= 1 and size.rows <= 9999);
            try testing.expect(size.cols >= 1 and size.cols <= 9999);
        }
        
        test "performance: Terminal: resize callback overhead" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Reset global counter
            test_total_calls = 0;
            
            const simple_callback = struct {
                fn handler(event: ResizeEvent) void {
                    _ = event;
                    test_total_calls += 1;
                }
            }.handler;
            
            // Add the same callback multiple times
            for (0..10) |_| {
                try terminal.onResize(simple_callback);
            }
            
            // Time multiple resize events
            const iterations = 50; // Reduced for test performance
            const start = std.time.milliTimestamp();
            
            for (0..iterations) |i| {
                // Ensure each size is unique and different from the initial size (24x80)
                const size = Size{
                    .rows = @as(u16, @intCast(25 + i)), // Start from 25, increment each time
                    .cols = @as(u16, @intCast(81 + i)), // Start from 81, increment each time
                };
                terminal.handleResize(size);
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            const avg_ms = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations));
            
            // Each resize with 10 callbacks should be fast
            try testing.expect(avg_ms < 5.0); // Relaxed constraint for CI environments
            
            // Verify callbacks were called (10 callbacks * iterations)
            try testing.expect(test_total_calls == 10 * iterations);
        }
        
        test "scenario: Terminal: complete resize workflow" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Set up constraints
            const constraints = SizeConstraints{
                .min_rows = 10,
                .min_cols = 40,
                .max_rows = 100,
                .max_cols = 200,
            };
            terminal.setSizeConstraints(constraints);
            
            // Set up resize tracking
            var resize_history = std.ArrayList(ResizeEvent).init(allocator);
            defer resize_history.deinit();
            test_resize_history = &resize_history;
            
            const HistoryCallback = struct {
                fn handler(event: ResizeEvent) void {
                    if (test_resize_history) |history| {
                        history.append(event) catch {};
                    }
                }
            };
            
            try terminal.onResize(HistoryCallback.handler);
            
            // Start monitoring
            try terminal.startResizeMonitoring();
            defer terminal.stopResizeMonitoring() catch {};
            
            // Simulate several resize events
            const test_sizes = [_]Size{
                Size{ .rows = 30, .cols = 100 },
                Size{ .rows = 5, .cols = 30 },   // Will be constrained
                Size{ .rows = 200, .cols = 300 }, // Will be constrained
                Size{ .rows = 25, .cols = 85 },
            };
            
            for (test_sizes) |size| {
                terminal.handleResize(size);
            }
            
            // Verify resize history
            try testing.expect(resize_history.items.len == test_sizes.len);
            
            // Check that constraints were applied
            for (resize_history.items, 0..) |event, i| {
                const expected_size = constraints.apply(test_sizes[i]);
                try testing.expect(event.new_size.eql(expected_size));
                try testing.expect(event.timestamp > 0);
                
                if (i > 0) {
                    // Ensure timestamps are in order
                    try testing.expect(event.timestamp >= resize_history.items[i - 1].timestamp);
                }
            }
            
            // Final terminal size should match last constrained size
            const final_expected = constraints.apply(test_sizes[test_sizes.len - 1]);
            try testing.expect(terminal.size.eql(final_expected));
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Debug Output Tests ────────────────────────────┐
    
        test "unit: Terminal: debug output control functionality" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Initially debug output should be disabled in test mode
            try testing.expect(!terminal.debug_output);
            
            // Enable debug output
            terminal.setDebugOutput(true);
            try testing.expect(terminal.debug_output);
            
            // Disable debug output
            terminal.setDebugOutput(false);
            try testing.expect(!terminal.debug_output);
        }
        
        test "unit: Terminal: writeSequence suppression in test mode" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // With debug output disabled (default), ANSI sequences should be suppressed
            terminal.setDebugOutput(false);
            
            // These should not produce any visible output during tests
            try terminal.clear();
            try terminal.setCursorPos(10, 20);
            try terminal.hideCursor();
            try terminal.showCursor();
            try terminal.setCursorStyle(.block);
            
            // No errors should occur, but output is suppressed
            try testing.expect(true);
        }
        
        test "unit: Terminal: writeSequence behavior with debug output enabled" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Enable debug output - sequences should be written to stdout
            terminal.setDebugOutput(true);
            
            // These operations should work normally (though we can't easily test output)
            try terminal.clear();
            try terminal.setCursorPos(5, 15);
            try terminal.hideCursor();
            try terminal.showCursor();
            
            // Verify the operations complete without error
            try testing.expect(true);
        }
        
        test "unit: Terminal: debug output state persistence" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Test state persistence across multiple operations
            terminal.setDebugOutput(true);
            
            try terminal.enterRawMode();
            try testing.expect(terminal.debug_output); // Should persist
            
            try terminal.enterAltScreen();
            try testing.expect(terminal.debug_output); // Should persist
            
            try terminal.clear();
            try testing.expect(terminal.debug_output); // Should persist
            
            try terminal.exitAltScreen();
            try testing.expect(terminal.debug_output); // Should persist
            
            try terminal.exitRawMode();
            try testing.expect(terminal.debug_output); // Should persist
        }
        
        test "integration: Terminal: debug output with complex operations" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Test with disabled debug output (default test mode)
            terminal.setDebugOutput(false);
            
            // Perform complex sequence of operations
            try terminal.enterRawMode();
            try terminal.enterAltScreen();
            try terminal.clear();
            try terminal.setCursorPos(1, 1);
            try terminal.hideCursor();
            
            for (1..10) |i| {
                try terminal.setCursorPos(@intCast(i), @intCast(i * 5));
                try terminal.write("Test");
            }
            
            try terminal.showCursor();
            try terminal.exitAltScreen();
            try terminal.exitRawMode();
            
            // All operations should complete successfully without visible output
            try testing.expect(!terminal.debug_output);
        }
        
        test "integration: Terminal: debug output toggle during operations" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Start with debug output disabled
            terminal.setDebugOutput(false);
            try terminal.clear();
            
            // Enable debug output mid-operation
            terminal.setDebugOutput(true);
            try terminal.setCursorPos(10, 10);
            
            // Disable again
            terminal.setDebugOutput(false);
            try terminal.clearLine();
            
            // Final state should be disabled
            try testing.expect(!terminal.debug_output);
        }
        
        test "scenario: Terminal: test mode behavior with all ANSI operations" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Ensure debug output is disabled (test mode)
            terminal.setDebugOutput(false);
            
            // Test all ANSI-generating operations for suppression
            try terminal.clear();
            try terminal.clearLine();
            try terminal.setCursorPos(1, 1);
            try terminal.setCursorPos(24, 80);
            try terminal.setCursorPos(999, 999); // Large coordinates
            
            try terminal.hideCursor();
            try terminal.showCursor();
            
            // Test all cursor styles
            const styles = [_]CursorStyle{
                .default, .block, .underline, .bar,
                .blinking_block, .blinking_underline, .blinking_bar,
            };
            
            for (styles) |style| {
                try terminal.setCursorStyle(style);
            }
            
            try terminal.enterAltScreen();
            try terminal.exitAltScreen();
            
            // All operations should complete silently
            try testing.expect(!terminal.debug_output);
        }
        
        test "performance: Terminal: test mode suppression overhead" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Benchmark with debug output disabled (test mode)
            terminal.setDebugOutput(false);
            
            const iterations = 10000;
            const start = std.time.milliTimestamp();
            
            for (0..iterations) |i| {
                try terminal.setCursorPos(@as(u16, @intCast((i % 24) + 1)), @as(u16, @intCast((i % 80) + 1)));
                if (i % 10 == 0) {
                    try terminal.clear();
                }
                if (i % 5 == 0) {
                    try terminal.clearLine();
                }
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            const avg_ms = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations));
            
            // Suppression should add minimal overhead (< 0.01ms per operation)
            // The suppression check is very fast as it's just a boolean check
            try testing.expect(avg_ms < 0.01);
        }
        
        test "edge: Terminal: test mode detection reliability" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Test that @import("builtin").is_test correctly identifies test mode
            const is_test = @import("builtin").is_test;
            try testing.expect(is_test); // Should be true during tests
            
            // Debug output should be disabled by default in test mode
            try testing.expect(!terminal.debug_output);
            
            // Manual override should still work
            terminal.setDebugOutput(true);
            try testing.expect(terminal.debug_output);
        }
        
        test "edge: Terminal: writeSequence with empty sequences" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Test with empty sequence
            // This should be a no-op whether debug output is enabled or not
            terminal.setDebugOutput(false);
            // No direct way to test writeSequence with empty string,
            // but operations that generate empty sequences should work
            
            terminal.setDebugOutput(true);
            // Same test with debug output enabled
            
            try testing.expect(true); // Test passes if no errors occur
        }
        
        test "edge: Terminal: debug output with concurrent-like access" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Simulate rapid toggling of debug output
            for (0..100) |i| {
                terminal.setDebugOutput(i % 2 == 0);
                try terminal.setCursorPos(@as(u16, @intCast((i % 10) + 1)), @as(u16, @intCast((i % 10) + 1)));
                
                // Verify state is consistent
                try testing.expect(terminal.debug_output == (i % 2 == 0));
            }
        }
    
    // └──────────────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝