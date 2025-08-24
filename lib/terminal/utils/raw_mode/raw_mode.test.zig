// raw_mode.test.zig — Comprehensive tests for raw mode terminal operations
//
// repo   : https://github.com/fisty/zig-tui
// author : https://github.com/fisty
//
// Tests for terminal raw mode management and state restoration.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const RawMode = @import("raw_mode.zig").RawMode;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test constants
    const TERMIOS_FLAGS = struct {
        const ECHO = 0x0008;
        const ICANON = 0x0100;
        const ISIG = 0x0001;
        const IXON = 0x0400;
        const IEXTEN = 0x8000;
        const ICRNL = 0x0100;
        const OPOST = 0x0001;
    };
    
    // Test terminal state
    const TestTerminalState = struct {
        echo_enabled: bool,
        canonical_mode: bool,
        signals_enabled: bool,
        flow_control: bool,
        
        pub fn default() TestTerminalState {
            return .{
                .echo_enabled = true,
                .canonical_mode = true,
                .signals_enabled = true,
                .flow_control = true,
            };
        }
        
        pub fn rawMode() TestTerminalState {
            return .{
                .echo_enabled = false,
                .canonical_mode = false,
                .signals_enabled = false,
                .flow_control = false,
            };
        }
    };
    
    // Test helpers
    fn createTestRawMode(allocator: std.mem.Allocator) !*RawMode {
        const raw_mode = try allocator.create(RawMode);
        raw_mode.* = try RawMode.init();
        return raw_mode;
    }
    
    fn simulateTerminalState(state: TestTerminalState) !void {
        // In real implementation, this would set actual terminal flags
        _ = state;
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐
    
        test "unit: RawMode: initializes in normal mode" {
            var raw_mode = try RawMode.init();
            defer raw_mode.deinit();
            
            try testing.expect(!raw_mode.isEnabled());
            try testing.expect(raw_mode.getOriginalState() != null);
        }
        
        test "unit: RawMode: enters raw mode successfully" {
            var raw_mode = try RawMode.init();
            defer raw_mode.deinit();
            
            try raw_mode.enable();
            try testing.expect(raw_mode.isEnabled());
        }
        
        test "unit: RawMode: exits raw mode successfully" {
            var raw_mode = try RawMode.init();
            defer raw_mode.deinit();
            
            try raw_mode.enable();
            try raw_mode.disable();
            try testing.expect(!raw_mode.isEnabled());
        }
        
        test "unit: RawMode: saves terminal state before entering" {
            var raw_mode = try RawMode.init();
            defer raw_mode.deinit();
            
            const original_state = raw_mode.getOriginalState();
            try testing.expect(original_state != null);
            
            try raw_mode.enable();
            
            // Original state should be preserved
            const saved_state = raw_mode.getOriginalState();
            try testing.expectEqual(original_state, saved_state);
        }
        
        test "unit: RawMode: handles double enable gracefully" {
            var raw_mode = try RawMode.init();
            defer raw_mode.deinit();
            
            try raw_mode.enable();
            const result = raw_mode.enable();
            try testing.expectError(RawMode.Error.AlreadyEnabled, result);
        }
        
        test "unit: RawMode: handles disable when not enabled" {
            var raw_mode = try RawMode.init();
            defer raw_mode.deinit();
            
            const result = raw_mode.disable();
            try testing.expectError(RawMode.Error.NotEnabled, result);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: RawMode state transitions: complete cycle" {
            var raw_mode = try RawMode.init();
            defer raw_mode.deinit();
            
            // Start in normal mode
            try testing.expect(!raw_mode.isEnabled());
            
            // Enter raw mode
            try raw_mode.enable();
            try testing.expect(raw_mode.isEnabled());
            
            // Verify terminal flags would be set
            const flags = raw_mode.getCurrentFlags();
            try testing.expect(flags != null);
            
            // Exit raw mode
            try raw_mode.disable();
            try testing.expect(!raw_mode.isEnabled());
            
            // Terminal should be restored
            const restored_flags = raw_mode.getCurrentFlags();
            try testing.expect(restored_flags != null);
        }
        
        test "integration: RawMode with signal handling: manages signals" {
            var raw_mode = try RawMode.init();
            defer raw_mode.deinit();
            
            // Set up signal handler
            var signal_received = false;
            const handler = struct {
                fn handle(sig: c_int, data: *anyopaque) void {
                    _ = sig;
                    const received = @as(*bool, @ptrCast(@alignCast(data)));
                    received.* = true;
                }
            }.handle;
            
            try raw_mode.setSignalHandler(handler, &signal_received);
            
            // Enable raw mode
            try raw_mode.enable();
            
            // Simulate Ctrl+C (would be actual signal in real impl)
            try raw_mode.simulateSignal(2); // SIGINT
            
            // Handler should be called
            try testing.expect(signal_received);
            
            // Cleanup should happen
            try raw_mode.disable();
        }
        
        test "integration: RawMode with stdin: configures input correctly" {
            const allocator = testing.allocator;
            var raw_mode = try RawMode.init();
            defer raw_mode.deinit();
            
            // Enable raw mode
            try raw_mode.enable();
            
            // Check stdin configuration
            const stdin_flags = try raw_mode.getStdinFlags(allocator);
            defer allocator.free(stdin_flags);
            
            // Verify raw mode flags
            try testing.expect(!stdin_flags.echo);
            try testing.expect(!stdin_flags.canonical);
            try testing.expect(!stdin_flags.signals);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── E2E Tests ────────────────────────────┐
    
        test "e2e: complete raw mode session: initialization to cleanup" {
            const allocator = testing.allocator;
            
            // Initialize raw mode manager
            var raw_mode = try RawMode.init();
            defer raw_mode.deinit();
            
            // Save initial state
            const initial_state = try raw_mode.saveState(allocator);
            defer allocator.free(initial_state);
            
            // Enter raw mode
            try raw_mode.enable();
            
            // Verify raw mode settings
            try testing.expect(raw_mode.isEnabled());
            
            // Perform operations in raw mode
            for (0..10) |_| {
                // Simulate reading input
                _ = raw_mode.readByte() catch {};
            }
            
            // Exit raw mode
            try raw_mode.disable();
            
            // Verify restoration
            const final_state = try raw_mode.saveState(allocator);
            defer allocator.free(final_state);
            
            // States should match
            try testing.expectEqualSlices(u8, initial_state, final_state);
        }
        
        test "e2e: raw mode with error recovery: handles failures gracefully" {
            var raw_mode = try RawMode.init();
            defer raw_mode.deinit();
            
            // Set up cleanup handler
            var cleanup_called = false;
            const cleanup = struct {
                fn handle(data: *anyopaque) void {
                    const called = @as(*bool, @ptrCast(@alignCast(data)));
                    called.* = true;
                }
            }.handle;
            
            try raw_mode.setCleanupHandler(cleanup, &cleanup_called);
            
            // Enter raw mode
            try raw_mode.enable();
            
            // Simulate error condition
            raw_mode.forceError() catch {
                // Error should trigger cleanup
                try testing.expect(cleanup_called);
            };
            
            // Should be able to recover
            if (raw_mode.isEnabled()) {
                try raw_mode.disable();
            }
            
            // Should be back to normal
            try testing.expect(!raw_mode.isEnabled());
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: RawMode.enable/disable: switches modes quickly" {
            var raw_mode = try RawMode.init();
            defer raw_mode.deinit();
            
            const iterations = 100;
            const start = std.time.milliTimestamp();
            
            for (0..iterations) |i| {
                if (i % 2 == 0) {
                    try raw_mode.enable();
                } else {
                    try raw_mode.disable();
                }
            }
            
            // Ensure we end in disabled state
            if (raw_mode.isEnabled()) {
                try raw_mode.disable();
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should handle 100 switches quickly
            try testing.expect(elapsed < 100);
        }
        
        test "performance: RawMode state save/restore: handles many operations" {
            const allocator = testing.allocator;
            var raw_mode = try RawMode.init();
            defer raw_mode.deinit();
            
            var states = std.ArrayList([]u8).init(allocator);
            defer {
                for (states.items) |state| {
                    allocator.free(state);
                }
                states.deinit();
            }
            
            const iterations = 1000;
            const start = std.time.milliTimestamp();
            
            for (0..iterations) |_| {
                const state = try raw_mode.saveState(allocator);
                try states.append(state);
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should save 1000 states quickly
            try testing.expect(elapsed < 100);
            try testing.expectEqual(@as(usize, iterations), states.items.len);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Stress Tests ────────────────────────────┐
    
        test "stress: RawMode: survives rapid state changes" {
            var raw_mode = try RawMode.init();
            defer raw_mode.deinit();
            
            var prng = std.rand.DefaultPrng.init(33333);
            const random = prng.random();
            
            // Rapid random state changes
            for (0..1000) |_| {
                const action = random.intRangeLessThan(u8, 0, 3);
                
                switch (action) {
                    0 => raw_mode.enable() catch {},
                    1 => raw_mode.disable() catch {},
                    2 => _ = raw_mode.isEnabled(),
                    else => unreachable,
                }
            }
            
            // Should end in a stable state
            if (raw_mode.isEnabled()) {
                try raw_mode.disable();
            }
            
            try testing.expect(!raw_mode.isEnabled());
        }
        
        test "stress: RawMode: handles concurrent operations safely" {
            const allocator = testing.allocator;
            
            // Create multiple raw mode instances (simulating threads)
            var instances: [10]*RawMode = undefined;
            
            for (0..10) |i| {
                instances[i] = try allocator.create(RawMode);
                instances[i].* = try RawMode.init();
            }
            
            defer {
                for (0..10) |i| {
                    instances[i].deinit();
                    allocator.destroy(instances[i]);
                }
            }
            
            // Simulate concurrent operations
            for (0..100) |iteration| {
                for (instances) |instance| {
                    if (iteration % 2 == 0) {
                        instance.enable() catch {};
                    } else {
                        instance.disable() catch {};
                    }
                }
            }
            
            // All should be stable
            for (instances) |instance| {
                if (instance.isEnabled()) {
                    try instance.disable();
                }
                try testing.expect(!instance.isEnabled());
            }
        }
    
    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝