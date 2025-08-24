// callback_registry.test.zig — Comprehensive tests for the callback registry module
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Random = std.Random;
    const registry_module = @import("callback_registry.zig");
    const CallbackRegistry = registry_module.CallbackRegistry;
    const Entry = registry_module.Entry;
    const RegistryError = registry_module.RegistryError;
    
    // Mock types and enums for testing without circular dependencies
    const ResizeMode = enum {
        preserve_content,
        clear_content,
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    /// Mock Terminal for testing
    const MockTerminal = struct {
        allocator: std.mem.Allocator,
        id: u32,
        size: struct { cols: u16, rows: u16 },
        
        pub fn init(allocator: std.mem.Allocator) !MockTerminal {
            return MockTerminal{
                .allocator = allocator,
                .id = 1,
                .size = .{ .cols = 80, .rows = 24 },
            };
        }
        
        pub fn deinit(self: *MockTerminal) void {
            _ = self;
        }
    };
    
    /// Mock screen for testing callback behavior
    const MockScreen = struct {
        allocator: std.mem.Allocator,
        width: u16,
        height: u16,
        resize_count: u32,
        last_resize_cols: u16,
        last_resize_rows: u16,
        fail_on_resize: bool,
        resize_delay_ns: u64,
        
        pub fn init(allocator: std.mem.Allocator) !MockScreen {
            return MockScreen{
                .allocator = allocator,
                .width = 80,
                .height = 24,
                .resize_count = 0,
                .last_resize_cols = 0,
                .last_resize_rows = 0,
                .fail_on_resize = false,
                .resize_delay_ns = 0,
            };
        }
        
        pub fn deinit(self: *MockScreen) void {
            _ = self;
        }
        
        pub fn handleResize(self: *MockScreen, new_cols: u16, new_rows: u16, mode: ResizeMode) !void {
            _ = mode;
            
            // Simulate delay if configured
            if (self.resize_delay_ns > 0) {
                std.time.sleep(self.resize_delay_ns);
            }
            
            // Simulate failure if configured
            if (self.fail_on_resize) {
                return error.ResizeFailed;
            }
            
            self.width = new_cols;
            self.height = new_rows;
            self.resize_count += 1;
            self.last_resize_cols = new_cols;
            self.last_resize_rows = new_rows;
        }
    };
    
    /// Helper to create a test terminal with default settings
    fn createTestTerminal(allocator: std.mem.Allocator) !*MockTerminal {
        const terminal = try allocator.create(MockTerminal);
        terminal.* = try MockTerminal.init(allocator);
        return terminal;
    }
    
    /// Helper to destroy a test terminal
    fn destroyTestTerminal(allocator: std.mem.Allocator, terminal: *MockTerminal) void {
        terminal.deinit();
        allocator.destroy(terminal);
    }
    
    /// Helper to create a test screen with default settings
    fn createTestScreen(allocator: std.mem.Allocator) !*MockScreen {
        const screen = try allocator.create(MockScreen);
        screen.* = try MockScreen.init(allocator);
        return screen;
    }
    
    /// Helper to destroy a test screen
    fn destroyTestScreen(allocator: std.mem.Allocator, screen: *MockScreen) void {
        screen.deinit();
        allocator.destroy(screen);
    }
    
    /// Thread context for concurrent testing
    const ThreadContext = struct {
        registry: *CallbackRegistry,
        terminal: *anyopaque,
        screen: *anyopaque,
        operations: u32,
        thread_id: u32,
        success_count: u32,
        error_count: u32,
    };
    
    /// Worker function for thread tests
    fn threadWorker(context: *ThreadContext) void {
        var prng = std.Random.DefaultPrng.init(@as(u64, context.thread_id) * 12345);
        const random = prng.random();
        
        for (0..context.operations) |_| {
            const op = random.intRangeAtMost(u8, 0, 2);
            
            switch (op) {
                0 => {
                    // Register
                    _ = context.registry.register(context.terminal, context.screen) catch {
                        context.error_count += 1;
                        continue;
                    };
                    context.success_count += 1;
                },
                1 => {
                    // Unregister random ID
                    const id = random.intRangeAtMost(u64, 1, 100);
                    context.registry.unregister(id) catch {
                        context.error_count += 1;
                        continue;
                    };
                    context.success_count += 1;
                },
                2 => {
                    // Handle resize
                    const cols = random.intRangeAtMost(u16, 40, 200);
                    const rows = random.intRangeAtMost(u16, 20, 100);
                    context.registry.handleResizeTyped(context.terminal, cols, rows, MockScreen);
                    context.success_count += 1;
                },
                else => unreachable,
            }
        }
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ UNIT TESTS ════════════════════════════════════╗

    test "unit: CallbackRegistry: initialization and deinitialization" {
        const allocator = testing.allocator;
        
        // Test initialization
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        // Verify initial state
        try testing.expectEqual(@as(u64, 1), registry.next_id);
        try testing.expectEqual(@as(usize, 0), registry.entries.items.len);
        try testing.expectEqual(@as(u64, 0), registry.stats.total_registered);
        try testing.expectEqual(@as(u64, 0), registry.stats.current_entries);
    }
    
    test "unit: CallbackRegistry: register single entry" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        // Create mock terminal and screen
        const terminal = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal);
        
        const screen = try createTestScreen(allocator);
        defer destroyTestScreen(allocator, screen);
        
        // Register the association
        const id = try registry.register(terminal, screen);
        
        // Verify registration
        try testing.expectEqual(@as(u64, 1), id);
        try testing.expectEqual(@as(usize, 1), registry.entries.items.len);
        try testing.expectEqual(@as(u64, 1), registry.stats.total_registered);
        try testing.expectEqual(@as(u64, 1), registry.stats.current_entries);
        
        // Verify entry details
        const entry = registry.entries.items[0];
        try testing.expectEqual(@as(*anyopaque, @ptrCast(terminal)), entry.terminal);
        try testing.expectEqual(@as(*anyopaque, @ptrCast(screen)), entry.screen);
        try testing.expectEqual(id, entry.id);
    }
    
    test "unit: CallbackRegistry: prevent duplicate registration" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        const terminal = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal);
        
        const screen = try createTestScreen(allocator);
        defer destroyTestScreen(allocator, screen);
        
        // First registration should succeed
        _ = try registry.register(terminal, screen);
        
        // Duplicate registration should fail
        const result = registry.register(terminal, screen);
        try testing.expectError(RegistryError.DuplicateEntry, result);
        
        // Verify only one entry exists
        try testing.expectEqual(@as(usize, 1), registry.entries.items.len);
    }
    
    test "unit: CallbackRegistry: unregister by ID" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        const terminal = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal);
        
        const screen = try createTestScreen(allocator);
        defer destroyTestScreen(allocator, screen);
        
        // Register and then unregister
        const id = try registry.register(terminal, screen);
        try testing.expectEqual(@as(usize, 1), registry.entries.items.len);
        
        try registry.unregister(id);
        
        // Verify unregistration
        try testing.expectEqual(@as(usize, 0), registry.entries.items.len);
        try testing.expectEqual(@as(u64, 1), registry.stats.total_unregistered);
        try testing.expectEqual(@as(u64, 0), registry.stats.current_entries);
    }
    
    test "unit: CallbackRegistry: unregister non-existent ID" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        // Try to unregister non-existent ID
        const result = registry.unregister(999);
        try testing.expectError(RegistryError.EntryNotFound, result);
    }
    
    test "unit: Entry: matching functions" {
        const allocator = testing.allocator;
        
        const terminal = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal);
        
        const screen = try createTestScreen(allocator);
        defer destroyTestScreen(allocator, screen);
        
        const entry = Entry{
            .id = 42,
            .terminal = terminal,
            .screen = screen,
            .registered_at = std.time.timestamp(),
        };
        
        // Test matching functions
        try testing.expect(entry.matchesId(42));
        try testing.expect(!entry.matchesId(43));
        
        try testing.expect(entry.matchesTerminal(terminal));
        try testing.expect(!entry.matchesTerminal(screen));
        
        try testing.expect(entry.matchesScreen(screen));
        try testing.expect(!entry.matchesScreen(terminal));
    }
    
    test "unit: CallbackRegistry: clear maintains capacity" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        const terminal = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal);
        
        // Register multiple entries
        var screens: [10]MockScreen = undefined;
        for (&screens) |*screen| {
            screen.* = try MockScreen.init(allocator);
            _ = try registry.register(terminal, screen);
        }
        defer for (&screens) |*screen| {
            screen.deinit();
        };
        
        const capacity_before = registry.entries.capacity;
        
        // Clear entries
        registry.clear();
        
        // Verify capacity retained but items cleared
        try testing.expectEqual(@as(usize, 0), registry.entries.items.len);
        try testing.expectEqual(capacity_before, registry.entries.capacity);
        try testing.expectEqual(@as(u64, 0), registry.stats.current_entries);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INTEGRATION TESTS ═════════════════════════════╗

    test "integration: Terminal-Screen: resize event flow" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        // Create terminal and screen
        const terminal = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal);
        
        const screen = try createTestScreen(allocator);
        defer destroyTestScreen(allocator, screen);
        
        // Register screen with terminal
        const id = try registry.register(terminal, screen);
        defer registry.unregister(id) catch {};
        
        // Verify initial screen dimensions
        try testing.expectEqual(@as(u16, 80), screen.width);
        try testing.expectEqual(@as(u16, 24), screen.height);
        
        // Trigger resize through registry
        registry.handleResizeTyped(terminal, 100, 30, MockScreen);
        
        // Verify screen was resized
        try testing.expectEqual(@as(u16, 100), screen.width);
        try testing.expectEqual(@as(u16, 30), screen.height);
        
        // Verify statistics
        try testing.expectEqual(@as(u64, 1), registry.stats.resize_events_handled);
    }
    
    test "integration: Terminal-Screen: multiple screens per terminal" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        const terminal = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal);
        
        // Create and register multiple screens
        var screens: [3]MockScreen = undefined;
        var ids: [3]u64 = undefined;
        
        for (&screens, 0..) |*screen, i| {
            screen.* = try MockScreen.init(allocator);
            ids[i] = try registry.register(terminal, screen);
        }
        defer for (&screens) |*screen| {
            screen.deinit();
        };
        
        // Resize through registry
        registry.handleResizeTyped(terminal, 120, 40, MockScreen);
        
        // Verify all screens were resized
        for (&screens) |*screen| {
            try testing.expectEqual(@as(u16, 120), screen.width);
            try testing.expectEqual(@as(u16, 40), screen.height);
            try testing.expectEqual(@as(u32, 1), screen.resize_count);
        }
        
        // Verify resize event count
        try testing.expectEqual(@as(u64, 1), registry.stats.resize_events_handled);
    }
    
    test "integration: Terminal-Screen: selective resize dispatch" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        // Create two terminals with screens
        const terminal1 = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal1);
        
        const terminal2 = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal2);
        
        var screen1 = try MockScreen.init(allocator);
        defer screen1.deinit();
        
        var screen2 = try MockScreen.init(allocator);
        defer screen2.deinit();
        
        // Register associations
        _ = try registry.register(terminal1, &screen1);
        _ = try registry.register(terminal2, &screen2);
        
        // Resize only terminal1
        registry.handleResizeTyped(terminal1, 100, 30, MockScreen);
        
        // Verify only screen1 was resized
        try testing.expectEqual(@as(u16, 100), screen1.width);
        try testing.expectEqual(@as(u16, 30), screen1.height);
        try testing.expectEqual(@as(u32, 1), screen1.resize_count);
        
        // screen2 should remain unchanged
        try testing.expectEqual(@as(u16, 80), screen2.width);
        try testing.expectEqual(@as(u16, 24), screen2.height);
        try testing.expectEqual(@as(u32, 0), screen2.resize_count);
    }
    
    test "integration: Terminal-Screen: graceful error handling" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        const terminal = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal);
        
        // Create screens with different failure modes
        var screen1 = try MockScreen.init(allocator);
        defer screen1.deinit();
        screen1.fail_on_resize = true; // Will fail
        
        var screen2 = try MockScreen.init(allocator);
        defer screen2.deinit();
        screen2.fail_on_resize = false; // Will succeed
        
        // Register both screens
        _ = try registry.register(terminal, &screen1);
        _ = try registry.register(terminal, &screen2);
        
        // Handle resize - should continue despite screen1 failure
        registry.handleResizeTyped(terminal, 100, 30, MockScreen);
        
        // Verify screen1 failed (dimensions unchanged)
        try testing.expectEqual(@as(u16, 80), screen1.width);
        try testing.expectEqual(@as(u16, 24), screen1.height);
        
        // Verify screen2 succeeded
        try testing.expectEqual(@as(u16, 100), screen2.width);
        try testing.expectEqual(@as(u16, 30), screen2.height);
        
        // Resize event was still handled
        try testing.expectEqual(@as(u64, 1), registry.stats.resize_events_handled);
    }
    
    test "integration: Terminal-Screen: findEntriesByTerminal" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        const terminal1 = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal1);
        
        const terminal2 = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal2);
        
        // Register multiple screens for terminal1
        var screens1: [3]MockScreen = undefined;
        for (&screens1) |*screen| {
            screen.* = try MockScreen.init(allocator);
            _ = try registry.register(terminal1, screen);
        }
        defer for (&screens1) |*screen| {
            screen.deinit();
        };
        
        // Register screens for terminal2
        var screens2: [2]MockScreen = undefined;
        for (&screens2) |*screen| {
            screen.* = try MockScreen.init(allocator);
            _ = try registry.register(terminal2, screen);
        }
        defer for (&screens2) |*screen| {
            screen.deinit();
        };
        
        // Find entries for terminal1
        const entries1 = registry.findEntriesByTerminal(terminal1);
        defer allocator.free(entries1);
        try testing.expectEqual(@as(usize, 3), entries1.len);
        
        // Find entries for terminal2
        const entries2 = registry.findEntriesByTerminal(terminal2);
        defer allocator.free(entries2);
        try testing.expectEqual(@as(usize, 2), entries2.len);
        
        // Find entries for non-existent terminal
        const terminal3 = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal3);
        const entries3 = registry.findEntriesByTerminal(terminal3);
        defer if (entries3.len > 0) allocator.free(entries3);
        try testing.expectEqual(@as(usize, 0), entries3.len);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ SCENARIO TESTS ════════════════════════════════╗

    test "scenario: CallbackRegistry: complete lifecycle with real components" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        // Simulate a complete application lifecycle
        const terminal = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal);
        
        // Phase 1: Application startup - create and register screen
        const screen = try createTestScreen(allocator);
        defer destroyTestScreen(allocator, screen);
        
        const screen_id = try registry.register(terminal, screen);
        
        // Phase 2: User resizes terminal multiple times
        const resize_events = [_][2]u16{
            .{ 100, 30 },
            .{ 120, 40 },
            .{ 80, 24 },
            .{ 200, 50 },
        };
        
        for (resize_events) |dims| {
            registry.handleResizeTyped(terminal, dims[0], dims[1], MockScreen);
            
            // Verify screen dimensions match
            try testing.expectEqual(dims[0], screen.width);
            try testing.expectEqual(dims[1], screen.height);
        }
        
        // Phase 3: Application shutdown - unregister
        try registry.unregister(screen_id);
        
        // Verify final statistics
        const stats = registry.getStats();
        try testing.expectEqual(@as(u64, 1), stats.total_registered);
        try testing.expectEqual(@as(u64, 1), stats.total_unregistered);
        try testing.expectEqual(@as(u64, 0), stats.current_entries);
        try testing.expectEqual(@as(u64, resize_events.len), stats.resize_events_handled);
    }
    
    test "scenario: CallbackRegistry: global singleton usage pattern" {
        const allocator = testing.allocator;
        defer registry_module.deinitGlobalRegistry();
        
        // Get global registry from multiple places
        const registry1 = registry_module.getGlobalRegistry(allocator);
        const registry2 = registry_module.getGlobalRegistry(allocator);
        
        // Verify singleton pattern
        try testing.expectEqual(registry1, registry2);
        
        // Use the global registry for real operations
        const terminal = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal);
        
        const screen = try createTestScreen(allocator);
        defer destroyTestScreen(allocator, screen);
        
        // Register through first reference
        const id = try registry1.register(terminal, screen);
        
        // Verify through second reference
        try testing.expectEqual(@as(usize, 1), registry2.entries.items.len);
        
        // Handle resize through second reference
        registry2.handleResizeTyped(terminal, 100, 30, MockScreen);
        
        // Verify through first reference
        const stats = registry1.getStats();
        try testing.expectEqual(@as(u64, 1), stats.resize_events_handled);
        
        // Clean up through either reference
        try registry1.unregister(id);
    }
    
    test "scenario: CallbackRegistry: dynamic screen management" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        const terminal = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal);
        
        // Scenario: Application dynamically creates/destroys screens
        var screen_ids = std.ArrayList(u64).init(allocator);
        defer screen_ids.deinit();
        
        // Create initial set of screens
        var screens = std.ArrayList(*MockScreen).init(allocator);
        defer {
            for (screens.items) |screen| {
                screen.deinit();
                allocator.destroy(screen);
            }
            screens.deinit();
        }
        
        // Phase 1: Create 5 screens
        for (0..5) |_| {
            const screen = try allocator.create(MockScreen);
            screen.* = try MockScreen.init(allocator);
            try screens.append(screen);
            
            const id = try registry.register(terminal, screen);
            try screen_ids.append(id);
        }
        
        // Resize all screens
        registry.handleResizeTyped(terminal, 100, 30, MockScreen);
        
        // Verify all screens resized
        for (screens.items) |screen| {
            try testing.expectEqual(@as(u16, 100), screen.width);
            try testing.expectEqual(@as(u16, 30), screen.height);
        }
        
        // Phase 2: Remove some screens
        try registry.unregister(screen_ids.items[1]);
        try registry.unregister(screen_ids.items[3]);
        
        // Resize again
        registry.handleResizeTyped(terminal, 120, 40, MockScreen);
        
        // Verify only remaining screens get second resize
        try testing.expectEqual(@as(u32, 2), screens.items[0].resize_count);
        try testing.expectEqual(@as(u32, 1), screens.items[1].resize_count); // Was unregistered
        try testing.expectEqual(@as(u32, 2), screens.items[2].resize_count);
        try testing.expectEqual(@as(u32, 1), screens.items[3].resize_count); // Was unregistered
        try testing.expectEqual(@as(u32, 2), screens.items[4].resize_count);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ PERFORMANCE TESTS ═════════════════════════════╗

    test "performance: CallbackRegistry: callback overhead under 1ms" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        const terminal = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal);
        
        // Create multiple screens to test dispatch overhead
        var screens: [10]MockScreen = undefined;
        for (&screens) |*screen| {
            screen.* = try MockScreen.init(allocator);
            _ = try registry.register(terminal, screen);
        }
        defer for (&screens) |*screen| {
            screen.deinit();
        };
        
        // Warm up
        for (0..10) |_| {
            registry.handleResizeTyped(terminal, 100, 30, MockScreen);
        }
        
        // Measure callback overhead
        const iterations = 1000;
        const start = std.time.nanoTimestamp();
        
        for (0..iterations) |_| {
            registry.handleResizeTyped(terminal, 100, 30, MockScreen);
        }
        
        const elapsed = std.time.nanoTimestamp() - start;
        const avg_ns = @divFloor(elapsed, iterations);
        const avg_ms = @as(f64, @floatFromInt(avg_ns)) / 1_000_000.0;
        
        // Verify performance requirement: < 1ms per callback
        try testing.expect(avg_ms < 1.0);
        
        // Optional debug output
        if (@import("builtin").mode == .Debug) {
            std.debug.print("\nAverage callback overhead: {d:.3}ms\n", .{avg_ms});
        }
    }
    
    test "performance: CallbackRegistry: registration/unregistration speed" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        const terminal = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal);
        
        const iterations = 10000;
        const screens = try allocator.alloc(MockScreen, iterations);
        defer allocator.free(screens);
        
        for (screens) |*screen| {
            screen.* = try MockScreen.init(allocator);
        }
        defer for (screens) |*screen| {
            screen.deinit();
        };
        
        // Measure registration speed
        const reg_start = std.time.nanoTimestamp();
        var ids = try allocator.alloc(u64, iterations);
        defer allocator.free(ids);
        
        for (screens, 0..) |*screen, i| {
            ids[i] = try registry.register(terminal, screen);
        }
        
        const reg_elapsed = std.time.nanoTimestamp() - reg_start;
        const avg_reg_ns = @divFloor(reg_elapsed, iterations);
        
        // Measure unregistration speed
        const unreg_start = std.time.nanoTimestamp();
        
        for (ids) |id| {
            try registry.unregister(id);
        }
        
        const unreg_elapsed = std.time.nanoTimestamp() - unreg_start;
        const avg_unreg_ns = @divFloor(unreg_elapsed, iterations);
        
        // Performance expectations: reasonable for 10000 operations
        // In debug mode, these operations may take longer
        const mode = @import("builtin").mode;
        const max_ns: u64 = if (mode == .Debug) 100000 else 10000;
        
        // Always print performance metrics for visibility
        std.debug.print("\nAverage registration time: {d}ns\n", .{avg_reg_ns});
        std.debug.print("Average unregistration time: {d}ns\n", .{avg_unreg_ns});
        
        try testing.expect(avg_reg_ns < max_ns);
        try testing.expect(avg_unreg_ns < max_ns);
    }
    
    test "performance: CallbackRegistry: findEntriesByTerminal scaling" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        // Create multiple terminals with varying screen counts
        const num_terminals = 20;
        const screens_per_terminal = 5;
        
        const terminals = try allocator.alloc(*MockTerminal, num_terminals);
        defer allocator.free(terminals);
        
        for (terminals) |*terminal| {
            terminal.* = try createTestTerminal(allocator);
        }
        defer for (terminals) |terminal| {
            destroyTestTerminal(allocator, terminal);
        };
        
        const screens = try allocator.alloc(MockScreen, num_terminals * screens_per_terminal);
        defer allocator.free(screens);
        
        // Register all associations
        var idx: usize = 0;
        for (terminals) |terminal| {
            for (0..screens_per_terminal) |_| {
                screens[idx] = try MockScreen.init(allocator);
                _ = try registry.register(terminal, &screens[idx]);
                idx += 1;
            }
        }
        defer for (screens) |*screen| {
            screen.deinit();
        };
        
        // Measure lookup performance
        const iterations = 1000;
        const start = std.time.nanoTimestamp();
        
        for (0..iterations) |_| {
            for (terminals) |terminal| {
                const entries = registry.findEntriesByTerminal(terminal);
                defer allocator.free(entries);
                
                // Verify correct count
                try testing.expectEqual(@as(usize, screens_per_terminal), entries.len);
            }
        }
        
        const elapsed = std.time.nanoTimestamp() - start;
        const avg_ns = @divFloor(elapsed, iterations * num_terminals);
        
        // Performance expectation: reasonable for lookups
        // Note: findEntriesByTerminal allocates memory for results which adds overhead
        const mode = @import("builtin").mode;
        const max_ns: u64 = if (mode == .Debug) 200000 else 50000;
        
        std.debug.print("\nAverage lookup time: {d}ns\n", .{avg_ns});
        
        try testing.expect(avg_ns < max_ns);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ STRESS TESTS ══════════════════════════════════╗

    test "stress: CallbackRegistry: concurrent operations thread safety" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        // Create shared resources
        const terminal = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal);
        
        const num_threads = 4;
        const ops_per_thread = 1000;
        
        // Create thread contexts
        var contexts: [num_threads]ThreadContext = undefined;
        var screens: [num_threads]MockScreen = undefined;
        
        for (&contexts, &screens, 0..) |*context, *screen, i| {
            screen.* = try MockScreen.init(allocator);
            context.* = ThreadContext{
                .registry = &registry,
                .terminal = terminal,
                .screen = screen,
                .operations = ops_per_thread,
                .thread_id = @intCast(i),
                .success_count = 0,
                .error_count = 0,
            };
        }
        defer for (&screens) |*screen| {
            screen.deinit();
        };
        
        // Launch threads
        var threads: [num_threads]std.Thread = undefined;
        for (&threads, &contexts) |*thread, *context| {
            thread.* = try std.Thread.spawn(.{}, threadWorker, .{context});
        }
        
        // Wait for completion
        for (threads) |thread| {
            thread.join();
        }
        
        // Verify no crashes and operations completed
        var total_success: u32 = 0;
        var total_errors: u32 = 0;
        
        for (contexts) |context| {
            total_success += context.success_count;
            total_errors += context.error_count;
        }
        
        // We expect some operations to succeed
        try testing.expect(total_success > 0);
        
        // The registry should still be in a valid state
        const stats = registry.getStats();
        try testing.expect(stats.current_entries <= stats.total_registered);
    }
    
    test "stress: CallbackRegistry: rapid resize events" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        const terminal = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal);
        
        // Create multiple screens
        var screens: [10]MockScreen = undefined;
        for (&screens) |*screen| {
            screen.* = try MockScreen.init(allocator);
            _ = try registry.register(terminal, screen);
        }
        defer for (&screens) |*screen| {
            screen.deinit();
        };
        
        // Rapid-fire resize events
        var prng = std.Random.DefaultPrng.init(12345);
        const random = prng.random();
        
        const iterations = 10000;
        for (0..iterations) |_| {
            const cols = random.intRangeAtMost(u16, 40, 200);
            const rows = random.intRangeAtMost(u16, 20, 100);
            
            registry.handleResizeTyped(terminal, cols, rows, MockScreen);
        }
        
        // Verify all screens received resize events
        for (screens) |screen| {
            try testing.expect(screen.resize_count > 0);
        }
        
        // Verify statistics
        try testing.expectEqual(@as(u64, iterations), registry.stats.resize_events_handled);
    }
    
    test "stress: CallbackRegistry: maximum capacity handling" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        // Try to register a very large number of entries
        const max_entries = 10000;
        
        const terminals = try allocator.alloc(*MockTerminal, max_entries);
        defer allocator.free(terminals);
        
        const screens = try allocator.alloc(MockScreen, max_entries);
        defer allocator.free(screens);
        
        var registered_count: usize = 0;
        
        // Register as many as possible
        for (0..max_entries) |i| {
            terminals[i] = createTestTerminal(allocator) catch break;
            screens[i] = MockScreen.init(allocator) catch {
                destroyTestTerminal(allocator, terminals[i]);
                break;
            };
            
            _ = registry.register(terminals[i], &screens[i]) catch {
                destroyTestTerminal(allocator, terminals[i]);
                screens[i].deinit();
                break;
            };
            
            registered_count = i + 1;
        }
        
        // Clean up
        defer {
            for (0..registered_count) |i| {
                destroyTestTerminal(allocator, terminals[i]);
                screens[i].deinit();
            }
        }
        
        // Verify we could register a reasonable number
        try testing.expect(registered_count > 100);
        
        // Verify registry is still functional
        if (registered_count > 0) {
            registry.handleResizeTyped(terminals[0], 100, 30, MockScreen);
            try testing.expectEqual(@as(u16, 100), screens[0].width);
        }
        
        // Clear and verify cleanup
        registry.clear();
        try testing.expectEqual(@as(u64, 0), registry.stats.current_entries);
    }
    
    test "stress: CallbackRegistry: memory leak detection" {
        const allocator = testing.allocator;
        
        // Run multiple cycles of create/destroy to detect leaks
        for (0..100) |_| {
            var registry = CallbackRegistry.init(allocator);
            
            const terminal = try createTestTerminal(allocator);
            const screen = try createTestScreen(allocator);
            
            // Register and use
            const id = try registry.register(terminal, screen);
            registry.handleResizeTyped(terminal, 100, 30, MockScreen);
            
            // Unregister and cleanup
            try registry.unregister(id);
            
            destroyTestScreen(allocator, screen);
            destroyTestTerminal(allocator, terminal);
            registry.deinit();
        }
        
        // testing.allocator will detect any leaks
    }
    
    test "stress: CallbackRegistry: resize with slow callbacks" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        const terminal = try createTestTerminal(allocator);
        defer destroyTestTerminal(allocator, terminal);
        
        // Create screens with varying response times
        var screens: [5]MockScreen = undefined;
        const delays = [_]u64{ 0, 100, 500, 1000, 2000 }; // nanoseconds
        
        for (&screens, delays) |*screen, delay| {
            screen.* = try MockScreen.init(allocator);
            screen.resize_delay_ns = delay;
            _ = try registry.register(terminal, screen);
        }
        defer for (&screens) |*screen| {
            screen.deinit();
        };
        
        // Time the resize with slow callbacks
        const start = std.time.nanoTimestamp();
        registry.handleResizeTyped(terminal, 100, 30, MockScreen);
        const elapsed = std.time.nanoTimestamp() - start;
        
        // Verify all screens were resized despite delays
        for (screens) |screen| {
            try testing.expectEqual(@as(u16, 100), screen.width);
            try testing.expectEqual(@as(u16, 30), screen.height);
        }
        
        // Total time should be at least the sum of delays
        const total_delay = delays[0] + delays[1] + delays[2] + delays[3] + delays[4];
        try testing.expect(elapsed >= total_delay);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝