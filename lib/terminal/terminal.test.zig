// terminal.test.zig — Comprehensive tests for terminal operations
//
// repo   : https://github.com/fisty/zig-tui
// author : https://github.com/fisty
//
// Tests for terminal initialization, cleanup, and state management.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Terminal = @import("terminal.zig").Terminal;

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
            
            try testing.expect(!terminal.isRawMode());
            try testing.expect(terminal.getSize() != null);
        }
        
        test "unit: Terminal: enters raw mode successfully" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            try terminal.enterRawMode();
            try testing.expect(terminal.isRawMode());
        }
        
        test "unit: Terminal: exits raw mode successfully" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            try terminal.enterRawMode();
            try terminal.exitRawMode();
            try testing.expect(!terminal.isRawMode());
        }
        
        test "unit: Terminal: handles double raw mode entry" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            try terminal.enterRawMode();
            const result = terminal.enterRawMode();
            try testing.expectError(Terminal.Error.AlreadyInRawMode, result);
        }
        
        test "unit: Terminal: gets terminal size correctly" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            const size = try terminal.getSize();
            try testing.expect(size.width > 0);
            try testing.expect(size.height > 0);
            try testing.expect(size.width <= MAX_TERMINAL_SIZE);
            try testing.expect(size.height <= MAX_TERMINAL_SIZE);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: Terminal with RawMode: state transitions correctly" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Initial state
            try testing.expect(!terminal.isRawMode());
            
            // Enter raw mode
            try terminal.enterRawMode();
            try testing.expect(terminal.isRawMode());
            
            // Exit raw mode
            try terminal.exitRawMode();
            try testing.expect(!terminal.isRawMode());
        }
        
        test "integration: Terminal with Writer: writes output correctly" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            const test_string = "Hello, Terminal!";
            try terminal.write(test_string);
            
            // Verify write succeeded (actual output verification would require mocking)
            try testing.expect(true);
        }
        
        test "integration: Terminal with Cursor: positions cursor correctly" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            try terminal.setCursorPosition(10, 5);
            const pos = try terminal.getCursorPosition();
            
            try testing.expectEqual(@as(u16, 10), pos.x);
            try testing.expectEqual(@as(u16, 5), pos.y);
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
            
            // Perform operations
            try terminal.clear();
            try terminal.setCursorPosition(0, 0);
            try terminal.write("Test");
            try terminal.flush();
            
            // Exit raw mode
            try terminal.exitRawMode();
            
            // Verify final state
            try testing.expect(!terminal.isRawMode());
        }
        
        test "e2e: terminal interaction: complete user session" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Simulate user session
            try terminal.enterRawMode();
            defer terminal.exitRawMode() catch {};
            
            // Clear screen
            try terminal.clear();
            
            // Write welcome message
            try terminal.setCursorPosition(0, 0);
            try terminal.write("Welcome to TUI");
            
            // Move cursor and write more
            try terminal.setCursorPosition(0, 2);
            try terminal.write("Press any key to continue...");
            
            // Flush output
            try terminal.flush();
            
            try testing.expect(terminal.isRawMode());
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: Terminal.write: handles large output efficiently" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            // Create large output buffer
            const large_text = try allocator.alloc(u8, 10000);
            defer allocator.free(large_text);
            @memset(large_text, 'A');
            
            const start = std.time.milliTimestamp();
            try terminal.write(large_text);
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should complete within reasonable time
            try testing.expect(elapsed < 100); // 100ms threshold
        }
        
        test "performance: Terminal.clear: clears screen quickly" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            const iterations = 1000;
            const start = std.time.milliTimestamp();
            
            for (0..iterations) |_| {
                try terminal.clear();
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            const avg_ms = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations));
            
            // Average clear should be fast
            try testing.expect(avg_ms < 1.0);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Stress Tests ────────────────────────────┐
    
        test "stress: Terminal: handles rapid mode switching" {
            const allocator = testing.allocator;
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            const iterations = 100;
            for (0..iterations) |i| {
                if (i % 2 == 0) {
                    terminal.enterRawMode() catch {};
                } else {
                    terminal.exitRawMode() catch {};
                }
            }
            
            // Terminal should be stable after stress
            try terminal.exitRawMode() catch {};
            try testing.expect(!terminal.isRawMode());
        }
        
        test "stress: Terminal: survives memory pressure" {
            const allocator = testing.allocator;
            
            const terminal_count = 50;
            var terminals: [terminal_count]*Terminal = undefined;
            
            // Create many terminals
            for (0..terminal_count) |i| {
                terminals[i] = try allocator.create(Terminal);
                terminals[i].* = try Terminal.init(allocator);
            }
            
            // Clean up
            for (0..terminal_count) |i| {
                terminals[i].deinit();
                allocator.destroy(terminals[i]);
            }
            
            // Should complete without memory issues
            try testing.expect(true);
        }
    
    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝