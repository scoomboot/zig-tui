// raw_mode.test.zig — Comprehensive tests for raw mode terminal operations
//
// repo   : https://github.com/fisty/zig-tui
// author : https://github.com/fisty
// Vibe coded by fisty.
//
// Tests for terminal raw mode management and state restoration.

// ╔════════════════════════════════════ PACK ════════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const builtin = @import("builtin");
    const posix = std.posix;
    
    const raw_mode_module = @import("raw_mode.zig");
    const RawMode = raw_mode_module.RawMode;
    const RawModeError = raw_mode_module.RawModeError;
    const TerminalState = raw_mode_module.TerminalState;
    const cleanupGlobalRawMode = raw_mode_module.cleanupGlobalRawMode;
    const ensureCleanupOnExit = raw_mode_module.ensureCleanupOnExit;

// ╚════════════════════════════════════════════════════════════════════════════════════╝

// ╔════════════════════════════════════ INIT ════════════════════════════════════════╗

    // Helper to check if we're in a real terminal environment
    fn isRealTerminal() bool {
        const stdin = std.io.getStdIn();
        if (builtin.os.tag == .windows) {
            // Windows terminal detection would go here
            return false; // Skip in CI/testing environments
        } else {
            return posix.isatty(stdin.handle);
        }
    }

    // Helper to simulate terminal operations in non-TTY environments
    fn skipIfNotTerminal() !void {
        if (!isRealTerminal()) {
            return error.SkipZigTest;
        }
    }

    // Helper to create a test RawMode instance
    fn createTestRawMode() RawMode {
        return RawMode.init();
    }

    // Helper to safely test raw mode operations
    fn withRawMode(testFn: fn(*RawMode) anyerror!void) !void {
        var raw_mode = createTestRawMode();
        
        // Ensure cleanup happens even if test fails
        defer {
            if (raw_mode.isRaw()) {
                raw_mode.forceCleanup();
            }
        }
        
        try testFn(&raw_mode);
    }

    // Helper to measure operation time in microseconds
    fn measureMicroseconds(comptime func: fn() anyerror!void) !u64 {
        const start = std.time.microTimestamp();
        try func();
        return @intCast(std.time.microTimestamp() - start);
    }

// ╚════════════════════════════════════════════════════════════════════════════════════╝

// ╔════════════════════════════════════ TEST ════════════════════════════════════════╗

    // ┌────────────────────────────────── Unit Tests ──────────────────────────────────┐
    // └──────────────────────────────────────────────────────────────────────────────────┘

    test "unit: RawMode: initializes in normal mode" {
        var raw_mode = RawMode.init();
        
        try testing.expect(!raw_mode.isRaw());
        try testing.expect(!raw_mode.state.is_raw);
        
        if (builtin.os.tag == .windows) {
            try testing.expectEqual(@as(u32, 0), raw_mode.state.original_mode);
        }
    }

    test "unit: RawMode: init returns correct struct fields" {
        const raw_mode = RawMode.init();
        
        // Verify struct has expected fields
        try testing.expect(@TypeOf(raw_mode.state) == TerminalState);
        try testing.expect(@TypeOf(raw_mode.stdin_fd) == posix.fd_t);
        
        // Verify stdin_fd is set to stdin handle
        const expected_fd = std.io.getStdIn().handle;
        try testing.expectEqual(expected_fd, raw_mode.stdin_fd);
    }

    test "unit: RawMode: isRaw reflects internal state accurately" {
        var raw_mode = createTestRawMode();
        
        // Initially should not be raw
        try testing.expect(!raw_mode.isRaw());
        
        // Manually set internal state (simulating successful enter)
        raw_mode.state.is_raw = true;
        try testing.expect(raw_mode.isRaw());
        
        // Reset state
        raw_mode.state.is_raw = false;
        try testing.expect(!raw_mode.isRaw());
    }

    test "unit: RawMode: enter returns AlreadyInRawMode when already enabled" {
        var raw_mode = createTestRawMode();
        
        // Manually set as already in raw mode
        raw_mode.state.is_raw = true;
        
        // Should return error
        const result = raw_mode.enter();
        try testing.expectError(RawModeError.AlreadyInRawMode, result);
    }

    test "unit: RawMode: exit returns NotInRawMode when not enabled" {
        var raw_mode = createTestRawMode();
        
        // Ensure not in raw mode
        raw_mode.state.is_raw = false;
        
        // Should return error
        const result = raw_mode.exit();
        try testing.expectError(RawModeError.NotInRawMode, result);
    }

    test "unit: RawMode: setReadTimeout returns error when not in raw mode" {
        var raw_mode = createTestRawMode();
        
        // Ensure not in raw mode
        raw_mode.state.is_raw = false;
        
        const result = raw_mode.setReadTimeout(10);
        try testing.expectError(RawModeError.NotInRawMode, result);
    }

    test "unit: RawMode: setReadMinChars returns error when not in raw mode" {
        var raw_mode = createTestRawMode();
        
        // Ensure not in raw mode
        raw_mode.state.is_raw = false;
        
        const result = raw_mode.setReadMinChars(1);
        try testing.expectError(RawModeError.NotInRawMode, result);
    }

    test "unit: RawMode: forceCleanup safely handles non-raw state" {
        var raw_mode = createTestRawMode();
        
        // Should not crash when not in raw mode
        raw_mode.forceCleanup();
        
        // State should remain unchanged
        try testing.expect(!raw_mode.state.is_raw);
    }

    test "unit: RawMode: forceCleanup resets state when in raw mode" {
        var raw_mode = createTestRawMode();
        
        // Simulate being in raw mode
        raw_mode.state.is_raw = true;
        
        // Force cleanup
        raw_mode.forceCleanup();
        
        // Should no longer be in raw mode
        try testing.expect(!raw_mode.state.is_raw);
    }

    test "unit: TerminalState: platform-specific structure correct" {
        if (builtin.os.tag == .windows) {
            const state = TerminalState{
                .original_mode = 0,
                .is_raw = false,
            };
            
            try testing.expect(!state.is_raw);
            try testing.expectEqual(@as(u32, 0), state.original_mode);
        } else {
            const state = TerminalState{
                .original_termios = undefined,
                .is_raw = false,
            };
            
            try testing.expect(!state.is_raw);
        }
    }

    // ┌──────────────────────────────── Integration Tests ────────────────────────────────┐
    // └──────────────────────────────────────────────────────────────────────────────────┘

    test "integration: RawMode: complete enter/exit cycle in real terminal" {
        try skipIfNotTerminal();
        
        try withRawMode(struct {
            fn testFn(raw_mode: *RawMode) !void {
                // Start in normal mode
                try testing.expect(!raw_mode.isRaw());
                
                // Enter raw mode
                try raw_mode.enter();
                try testing.expect(raw_mode.isRaw());
                
                // Exit raw mode
                try raw_mode.exit();
                try testing.expect(!raw_mode.isRaw());
            }
        }.testFn);
    }

    test "integration: RawMode: preserves terminal state across mode changes" {
        try skipIfNotTerminal();
        
        try withRawMode(struct {
            fn testFn(raw_mode: *RawMode) !void {
                // Get initial terminal state (if POSIX)
                var initial_termios: ?posix.termios = null;
                if (builtin.os.tag != .windows) {
                    initial_termios = posix.tcgetattr(raw_mode.stdin_fd) catch null;
                }
                
                // Enter and exit raw mode
                try raw_mode.enter();
                try raw_mode.exit();
                
                // Terminal should be restored (if POSIX)
                if (initial_termios) |initial| {
                    const current = posix.tcgetattr(raw_mode.stdin_fd) catch {
                        return;
                    };
                    
                    // Key flags should be restored
                    try testing.expectEqual(initial.lflag.ECHO, current.lflag.ECHO);
                    try testing.expectEqual(initial.lflag.ICANON, current.lflag.ICANON);
                }
            }
        }.testFn);
    }

    test "integration: RawMode: setReadTimeout modifies terminal settings" {
        try skipIfNotTerminal();
        
        // Skip on Windows as it returns UnsupportedPlatform
        if (builtin.os.tag == .windows) {
            return error.SkipZigTest;
        }
        
        try withRawMode(struct {
            fn testFn(raw_mode: *RawMode) !void {
                try raw_mode.enter();
                
                // Set timeout to 5 deciseconds (0.5 seconds)
                try raw_mode.setReadTimeout(5);
                
                // Verify timeout was set (POSIX only)
                const termios = try posix.tcgetattr(raw_mode.stdin_fd);
                try testing.expectEqual(@as(u8, 5), termios.cc[@intFromEnum(posix.V.TIME)]);
                try testing.expectEqual(@as(u8, 0), termios.cc[@intFromEnum(posix.V.MIN)]);
                
                try raw_mode.exit();
            }
        }.testFn);
    }

    test "integration: RawMode: setReadMinChars modifies terminal settings" {
        try skipIfNotTerminal();
        
        // Skip on Windows as it returns UnsupportedPlatform
        if (builtin.os.tag == .windows) {
            return error.SkipZigTest;
        }
        
        try withRawMode(struct {
            fn testFn(raw_mode: *RawMode) !void {
                try raw_mode.enter();
                
                // Set min chars to 3
                try raw_mode.setReadMinChars(3);
                
                // Verify min chars was set (POSIX only)
                const termios = try posix.tcgetattr(raw_mode.stdin_fd);
                try testing.expectEqual(@as(u8, 3), termios.cc[@intFromEnum(posix.V.MIN)]);
                
                try raw_mode.exit();
            }
        }.testFn);
    }

    test "integration: RawMode: global registration prevents multiple instances" {
        try skipIfNotTerminal();
        
        var raw_mode1 = createTestRawMode();
        defer {
            if (raw_mode1.isRaw()) {
                raw_mode1.forceCleanup();
            }
        }
        
        var raw_mode2 = createTestRawMode();
        defer {
            if (raw_mode2.isRaw()) {
                raw_mode2.forceCleanup();
            }
        }
        
        // First instance should succeed
        try raw_mode1.enter();
        
        // Second instance should fail
        const result = raw_mode2.enter();
        try testing.expectError(RawModeError.AlreadyInRawMode, result);
        
        // Cleanup first instance
        try raw_mode1.exit();
        
        // Now second instance should succeed
        try raw_mode2.enter();
        try raw_mode2.exit();
    }

    test "integration: cleanupGlobalRawMode: safely handles cleanup" {
        try skipIfNotTerminal();
        
        var raw_mode = createTestRawMode();
        
        // Enter raw mode
        try raw_mode.enter();
        try testing.expect(raw_mode.isRaw());
        
        // Global cleanup should restore terminal
        cleanupGlobalRawMode();
        
        // Should no longer be in raw mode
        try testing.expect(!raw_mode.isRaw());
    }

    // ┌────────────────────────────────── E2E Tests ──────────────────────────────────┐
    // └──────────────────────────────────────────────────────────────────────────────────┘

    test "e2e: full terminal session: enter raw mode and handle input" {
        try skipIfNotTerminal();
        
        var raw_mode = createTestRawMode();
        defer {
            if (raw_mode.isRaw()) {
                raw_mode.forceCleanup();
            }
        }
        
        // Complete session workflow
        try raw_mode.enter();
        
        // Configure for non-blocking reads
        if (builtin.os.tag != .windows) {
            try raw_mode.setReadTimeout(1); // 0.1 second timeout
            try raw_mode.setReadMinChars(0); // Non-blocking
        }
        
        // Verify we're in raw mode
        try testing.expect(raw_mode.isRaw());
        
        // Clean exit
        try raw_mode.exit();
        try testing.expect(!raw_mode.isRaw());
    }

    test "e2e: error recovery: terminal restored after forced cleanup" {
        try skipIfNotTerminal();
        
        var raw_mode = createTestRawMode();
        
        // Enter raw mode
        try raw_mode.enter();
        
        // Simulate unexpected error requiring forced cleanup
        raw_mode.forceCleanup();
        
        // Terminal should be restored
        try testing.expect(!raw_mode.isRaw());
        
        // Should be able to enter raw mode again
        try raw_mode.enter();
        try raw_mode.exit();
    }

    test "e2e: signal handling setup: ensures cleanup on exit called" {
        // This just verifies the function exists and can be called
        // Actual signal testing would require process manipulation
        ensureCleanupOnExit();
        
        // Function should be callable multiple times
        ensureCleanupOnExit();
        
        // No crash means success
        try testing.expect(true);
    }

    // ┌──────────────────────────────── Performance Tests ────────────────────────────────┐
    // └──────────────────────────────────────────────────────────────────────────────────┘

    test "performance: RawMode: rapid enter/exit cycles complete quickly" {
        try skipIfNotTerminal();
        
        var raw_mode = createTestRawMode();
        defer {
            if (raw_mode.isRaw()) {
                raw_mode.forceCleanup();
            }
        }
        
        const iterations = 50;
        const start = std.time.microTimestamp();
        
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            try raw_mode.enter();
            try raw_mode.exit();
        }
        
        const elapsed_us = @as(u64, @intCast(std.time.microTimestamp() - start));
        const avg_us_per_cycle = elapsed_us / iterations;
        
        // Each enter/exit cycle should be reasonably fast
        // Allow up to 10ms per cycle (very generous for terminal operations)
        try testing.expect(avg_us_per_cycle < 10_000);
    }

    test "performance: RawMode: initialization is lightweight" {
        const iterations = 10_000;
        
        const start = std.time.microTimestamp();
        
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            _ = RawMode.init();
        }
        
        const elapsed_us = @as(u64, @intCast(std.time.microTimestamp() - start));
        const avg_us_per_init = elapsed_us / iterations;
        
        // Initialization should be very fast (< 1 microsecond)
        try testing.expect(avg_us_per_init < 1);
    }

    test "performance: RawMode: isRaw check is instant" {
        var raw_mode = createTestRawMode();
        
        const iterations = 1_000_000;
        const start = std.time.microTimestamp();
        
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            _ = raw_mode.isRaw();
        }
        
        const elapsed_us = @as(u64, @intCast(std.time.microTimestamp() - start));
        
        // Million checks should complete in under 100ms
        try testing.expect(elapsed_us < 100_000);
    }

    // ┌────────────────────────────────── Stress Tests ───────────────────────────────────┐
    // └──────────────────────────────────────────────────────────────────────────────────┘

    test "stress: RawMode: handles rapid state queries under load" {
        var raw_mode = createTestRawMode();
        
        var prng = std.Random.DefaultPrng.init(42);
        const random = prng.random();
        
        const iterations = 100_000;
        var true_count: usize = 0;
        var false_count: usize = 0;
        
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            // Randomly set internal state
            raw_mode.state.is_raw = random.boolean();
            
            // Query and verify consistency
            const is_raw = raw_mode.isRaw();
            try testing.expectEqual(raw_mode.state.is_raw, is_raw);
            
            if (is_raw) {
                true_count += 1;
            } else {
                false_count += 1;
            }
        }
        
        // Should have roughly equal distribution
        try testing.expect(true_count > iterations / 3);
        try testing.expect(false_count > iterations / 3);
    }

    test "stress: RawMode: survives many forced cleanups" {
        try skipIfNotTerminal();
        
        const iterations = 100;
        
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            var raw_mode = createTestRawMode();
            
            // Enter raw mode
            try raw_mode.enter();
            
            // Force cleanup instead of normal exit
            raw_mode.forceCleanup();
            
            // Verify state is clean
            try testing.expect(!raw_mode.isRaw());
        }
    }

    test "stress: RawMode: error conditions don't corrupt state" {
        var raw_mode = createTestRawMode();
        
        const iterations = 1000;
        var error_count: usize = 0;
        
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            // Try various error-inducing operations
            const op = i % 4;
            
            switch (op) {
                0 => {
                    // Try to exit when not in raw mode
                    raw_mode.state.is_raw = false;
                    raw_mode.exit() catch {
                        error_count += 1;
                    };
                },
                1 => {
                    // Try to enter when already in raw mode
                    raw_mode.state.is_raw = true;
                    raw_mode.enter() catch {
                        error_count += 1;
                    };
                },
                2 => {
                    // Try to set timeout when not in raw mode
                    raw_mode.state.is_raw = false;
                    raw_mode.setReadTimeout(5) catch {
                        error_count += 1;
                    };
                },
                3 => {
                    // Try to set min chars when not in raw mode
                    raw_mode.state.is_raw = false;
                    raw_mode.setReadMinChars(1) catch {
                        error_count += 1;
                    };
                },
                else => unreachable,
            }
            
            // State should remain consistent
            const expected_raw = (op == 1);
            try testing.expectEqual(expected_raw, raw_mode.state.is_raw);
        }
        
        // Should have caught many errors
        try testing.expect(error_count > iterations / 2);
    }

    test "stress: cleanupGlobalRawMode: handles repeated calls safely" {
        // Cleanup should be idempotent
        const iterations = 1000;
        
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            cleanupGlobalRawMode();
        }
        
        // No crash means success
        try testing.expect(true);
    }

// ╚════════════════════════════════════════════════════════════════════════════════════╝