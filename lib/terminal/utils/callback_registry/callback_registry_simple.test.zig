// callback_registry_simple.test.zig — Simple standalone tests for callback registry
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const registry_module = @import("callback_registry.zig");
    const CallbackRegistry = registry_module.CallbackRegistry;
    const Entry = registry_module.Entry;
    const RegistryError = registry_module.RegistryError;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ MOCK TYPES ════════════════════════════════════╗

    // Mock types for testing without circular dependencies
    const MockTerminal = struct {
        id: u32,
    };
    
    const MockScreen = struct {
        width: u16,
        height: u16,
        resize_count: u32 = 0,
        
        pub fn handleResize(self: *MockScreen, new_width: u16, new_height: u16, mode: anytype) !void {
            _ = mode;
            self.width = new_width;
            self.height = new_height;
            self.resize_count += 1;
        }
    };

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
        var terminal = MockTerminal{ .id = 1 };
        var screen = MockScreen{ .width = 80, .height = 24 };
        
        // Register the association
        const id = try registry.register(&terminal, &screen);
        
        // Verify registration
        try testing.expectEqual(@as(u64, 1), id);
        try testing.expectEqual(@as(usize, 1), registry.entries.items.len);
        try testing.expectEqual(@as(u64, 1), registry.stats.total_registered);
        try testing.expectEqual(@as(u64, 1), registry.stats.current_entries);
        
        // Verify entry details
        const entry = registry.entries.items[0];
        try testing.expectEqual(@as(*anyopaque, &terminal), entry.terminal);
        try testing.expectEqual(@as(*anyopaque, &screen), entry.screen);
        try testing.expectEqual(id, entry.id);
    }
    
    test "unit: CallbackRegistry: prevent duplicate registration" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        var terminal = MockTerminal{ .id = 1 };
        var screen = MockScreen{ .width = 80, .height = 24 };
        
        // First registration should succeed
        _ = try registry.register(&terminal, &screen);
        
        // Duplicate registration should fail
        const result = registry.register(&terminal, &screen);
        try testing.expectError(RegistryError.DuplicateEntry, result);
        
        // Verify only one entry exists
        try testing.expectEqual(@as(usize, 1), registry.entries.items.len);
    }
    
    test "unit: CallbackRegistry: unregister by ID" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        var terminal = MockTerminal{ .id = 1 };
        var screen = MockScreen{ .width = 80, .height = 24 };
        
        // Register and then unregister
        const id = try registry.register(&terminal, &screen);
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
        var terminal = MockTerminal{ .id = 1 };
        var screen = MockScreen{ .width = 80, .height = 24 };
        
        const entry = Entry{
            .id = 42,
            .terminal = &terminal,
            .screen = &screen,
            .registered_at = std.time.timestamp(),
        };
        
        // Test matching functions
        try testing.expect(entry.matchesId(42));
        try testing.expect(!entry.matchesId(43));
        
        try testing.expect(entry.matchesTerminal(&terminal));
        
        try testing.expect(entry.matchesScreen(&screen));
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INTEGRATION TESTS ═════════════════════════════╗

    test "integration: CallbackRegistry: multiple screens per terminal" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        var terminal = MockTerminal{ .id = 1 };
        var screen1 = MockScreen{ .width = 80, .height = 24 };
        var screen2 = MockScreen{ .width = 80, .height = 24 };
        var screen3 = MockScreen{ .width = 80, .height = 24 };
        
        // Register multiple screens for the same terminal
        const id1 = try registry.register(&terminal, &screen1);
        const id2 = try registry.register(&terminal, &screen2);
        const id3 = try registry.register(&terminal, &screen3);
        
        // Verify all registrations succeeded with unique IDs
        try testing.expect(id1 != id2);
        try testing.expect(id2 != id3);
        try testing.expect(id1 != id3);
        
        try testing.expectEqual(@as(usize, 3), registry.entries.items.len);
        try testing.expectEqual(@as(u64, 3), registry.stats.current_entries);
        
        // Find all entries for the terminal
        const entries = registry.findEntriesByTerminal(&terminal);
        defer allocator.free(entries);
        
        try testing.expectEqual(@as(usize, 3), entries.len);
    }
    
    test "integration: CallbackRegistry: handleResize dispatches to correct screens" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        // Create two terminals with screens
        var terminal1 = MockTerminal{ .id = 1 };
        var terminal2 = MockTerminal{ .id = 2 };
        
        var screen1 = MockScreen{ .width = 80, .height = 24 };
        var screen2 = MockScreen{ .width = 80, .height = 24 };
        
        // Register associations
        _ = try registry.register(&terminal1, &screen1);
        _ = try registry.register(&terminal2, &screen2);
        
        // Handle resize for terminal1
        registry.handleResize(&terminal1, 100, 30, MockScreen);
        
        // Verify that only screen1 was resized
        try testing.expectEqual(@as(u16, 100), screen1.width);
        try testing.expectEqual(@as(u16, 30), screen1.height);
        try testing.expectEqual(@as(u32, 1), screen1.resize_count);
        
        // screen2 should remain unchanged
        try testing.expectEqual(@as(u16, 80), screen2.width);
        try testing.expectEqual(@as(u16, 24), screen2.height);
        try testing.expectEqual(@as(u32, 0), screen2.resize_count);
        
        // Check statistics
        try testing.expectEqual(@as(u64, 1), registry.stats.resize_events_handled);
    }
    
    test "integration: CallbackRegistry: clear all entries" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        var terminal = MockTerminal{ .id = 1 };
        
        // Register multiple screens
        var screens: [5]MockScreen = undefined;
        for (&screens, 0..) |*screen, i| {
            screen.* = MockScreen{ 
                .width = 80, 
                .height = @as(u16, @intCast(24 + i))
            };
            _ = try registry.register(&terminal, screen);
        }
        
        // Verify entries exist
        try testing.expectEqual(@as(usize, 5), registry.entries.items.len);
        
        // Clear all entries
        registry.clear();
        
        // Verify all entries removed
        try testing.expectEqual(@as(usize, 0), registry.entries.items.len);
        try testing.expectEqual(@as(u64, 0), registry.stats.current_entries);
        
        // Stats for total registered should remain
        try testing.expectEqual(@as(u64, 5), registry.stats.total_registered);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ SCENARIO TESTS ════════════════════════════════╗

    test "scenario: CallbackRegistry: lifecycle with multiple operations" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        var terminal = MockTerminal{ .id = 1 };
        
        // Scenario: Register, resize, unregister, re-register
        var screen1 = MockScreen{ .width = 80, .height = 24 };
        
        // Step 1: Register first screen
        const id1 = try registry.register(&terminal, &screen1);
        
        // Step 2: Handle resize
        registry.handleResize(&terminal, 120, 40, MockScreen);
        try testing.expectEqual(@as(u16, 120), screen1.width);
        try testing.expectEqual(@as(u16, 40), screen1.height);
        
        // Step 3: Unregister first screen
        try registry.unregister(id1);
        
        // Step 4: Register a new screen
        var screen2 = MockScreen{ .width = 80, .height = 24 };
        const id2 = try registry.register(&terminal, &screen2);
        
        // Verify final state
        try testing.expectEqual(@as(usize, 1), registry.entries.items.len);
        try testing.expectEqual(@as(u64, 2), registry.stats.total_registered);
        try testing.expectEqual(@as(u64, 1), registry.stats.total_unregistered);
        try testing.expectEqual(@as(u64, 1), registry.stats.current_entries);
        try testing.expect(id2 > id1); // IDs should be monotonically increasing
    }
    
    test "scenario: CallbackRegistry: global singleton usage" {
        const allocator = testing.allocator;
        defer registry_module.deinitGlobalRegistry();
        
        // Get global registry multiple times - should return same instance
        const registry1 = registry_module.getGlobalRegistry(allocator);
        const registry2 = registry_module.getGlobalRegistry(allocator);
        
        try testing.expectEqual(registry1, registry2);
        
        // Use the global registry
        var terminal = MockTerminal{ .id = 1 };
        var screen = MockScreen{ .width = 80, .height = 24 };
        
        const id = try registry1.register(&terminal, &screen);
        
        // Verify registration through second reference
        try testing.expectEqual(@as(usize, 1), registry2.entries.items.len);
        
        // Clean up
        try registry1.unregister(id);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ PERFORMANCE TESTS ═════════════════════════════╗

    test "performance: CallbackRegistry: stress test with many entries" {
        const allocator = testing.allocator;
        
        var registry = CallbackRegistry.init(allocator);
        defer registry.deinit();
        
        const num_terminals = 10;
        const screens_per_terminal = 5;
        
        // Create terminals and screens
        var terminals: [num_terminals]MockTerminal = undefined;
        for (&terminals, 0..) |*terminal, i| {
            terminal.* = MockTerminal{ .id = @as(u32, @intCast(i)) };
        }
        
        var screens: [num_terminals * screens_per_terminal]MockScreen = undefined;
        for (&screens, 0..) |*screen, i| {
            screen.* = MockScreen{ 
                .width = 80, 
                .height = @as(u16, @intCast(24 + (i % 10)))
            };
        }
        
        // Register all associations
        var ids: [num_terminals * screens_per_terminal]u64 = undefined;
        var idx: usize = 0;
        for (&terminals) |*terminal| {
            for (0..screens_per_terminal) |_| {
                ids[idx] = try registry.register(terminal, &screens[idx]);
                idx += 1;
            }
        }
        
        // Verify total registrations
        const total_entries = num_terminals * screens_per_terminal;
        try testing.expectEqual(@as(usize, total_entries), registry.entries.items.len);
        
        // Test finding entries for a specific terminal
        const entries = registry.findEntriesByTerminal(&terminals[0]);
        defer allocator.free(entries);
        try testing.expectEqual(@as(usize, screens_per_terminal), entries.len);
        
        // Simulate resize events for all terminals
        for (&terminals) |*terminal| {
            registry.handleResize(terminal, 150, 50, MockScreen);
        }
        
        try testing.expectEqual(@as(u64, num_terminals), registry.stats.resize_events_handled);
        
        // Unregister half of the entries
        for (ids[0..total_entries / 2]) |id| {
            try registry.unregister(id);
        }
        
        try testing.expectEqual(@as(usize, total_entries / 2), registry.entries.items.len);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝