// callback_integration.test.zig — Tests for Terminal-CallbackRegistry integration
//
// repo   : https://github.com/fisty/zig-tui
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const terminal_mod = @import("terminal.zig");
    const Terminal = terminal_mod.Terminal;
    const ResizeEvent = terminal_mod.ResizeEvent;
    const CallbackRegistry = @import("utils/callback_registry/callback_registry.zig").CallbackRegistry;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TESTS ═════════════════════════════════════╗

    test "Terminal: includes CallbackRegistry field" {
        const allocator = testing.allocator;
        
        var terminal = try Terminal.init(allocator);
        defer terminal.deinit();
        
        // Verify the callback_registry field exists and is properly initialized
        const registry = terminal.getCallbackRegistry();
        // Registry is always valid (not nullable), so just verify we can access it
        const stats = registry.getStats();
        try testing.expectEqual(@as(u64, 0), stats.current_entries);
    }

    test "Terminal: CallbackRegistry is accessible via getter" {
        const allocator = testing.allocator;
        
        var terminal = try Terminal.init(allocator);
        defer terminal.deinit();
        
        // Get the registry and verify it's the same instance
        const registry1 = terminal.getCallbackRegistry();
        const registry2 = terminal.getCallbackRegistry();
        
        try testing.expectEqual(registry1, registry2);
    }

    test "Terminal: CallbackRegistry can register entries" {
        const allocator = testing.allocator;
        
        var terminal = try Terminal.init(allocator);
        defer terminal.deinit();
        
        // Mock screen object
        var mock_screen = struct {
            value: u32 = 42,
        }{};
        
        // Register the terminal-screen association
        const registry = terminal.getCallbackRegistry();
        const id = try registry.register(
            @as(*anyopaque, @ptrCast(&terminal)),
            @as(*anyopaque, @ptrCast(&mock_screen))
        );
        
        try testing.expect(id > 0);
        
        // Verify the entry was registered
        const stats = registry.getStats();
        try testing.expectEqual(@as(u64, 1), stats.current_entries);
        try testing.expectEqual(@as(u64, 1), stats.total_registered);
    }

    test "Terminal: CallbackRegistry cleanup in deinit" {
        const allocator = testing.allocator;
        
        // Create and destroy terminal multiple times to ensure proper cleanup
        for (0..3) |_| {
            var terminal = try Terminal.init(allocator);
            
            // Register some entries
            var mock_screen = struct { id: u32 = 1 }{};
            const registry = terminal.getCallbackRegistry();
            _ = try registry.register(
                @as(*anyopaque, @ptrCast(&terminal)),
                @as(*anyopaque, @ptrCast(&mock_screen))
            );
            
            // Deinit should clean up the registry
            terminal.deinit();
        }
        
        // If we get here without crashes, cleanup is working
        try testing.expect(true);
    }

    test "Terminal: backward compatibility with ResizeCallback" {
        const allocator = testing.allocator;
        
        var terminal = try Terminal.init(allocator);
        defer terminal.deinit();
        
        // Use a global variable for the callback test
        const CallbackState = struct {
            var count: u32 = 0;
            
            fn reset() void {
                count = 0;
            }
            
            fn callback(event: ResizeEvent) void {
                _ = event;
                count += 1;
            }
        };
        
        // Reset state
        CallbackState.reset();
        
        // Register traditional callback
        try terminal.onResize(CallbackState.callback);
        
        // Simulate resize
        terminal.handleResize(.{ .rows = 30, .cols = 100 });
        
        // Verify callback was invoked
        try testing.expectEqual(@as(u32, 1), CallbackState.count);
    }

    test "Terminal: registry integration with multiple screens" {
        const allocator = testing.allocator;
        
        var terminal = try Terminal.init(allocator);
        defer terminal.deinit();
        
        // Mock multiple screens
        var screen1 = struct { id: u32 = 1 }{};
        var screen2 = struct { id: u32 = 2 }{};
        var screen3 = struct { id: u32 = 3 }{};
        
        const registry = terminal.getCallbackRegistry();
        
        // Register multiple screens
        const id1 = try registry.register(
            @as(*anyopaque, @ptrCast(&terminal)),
            @as(*anyopaque, @ptrCast(&screen1))
        );
        const id2 = try registry.register(
            @as(*anyopaque, @ptrCast(&terminal)),
            @as(*anyopaque, @ptrCast(&screen2))
        );
        const id3 = try registry.register(
            @as(*anyopaque, @ptrCast(&terminal)),
            @as(*anyopaque, @ptrCast(&screen3))
        );
        
        // Verify all were registered
        const stats = registry.getStats();
        try testing.expectEqual(@as(u64, 3), stats.current_entries);
        
        // Unregister one
        try registry.unregister(id2);
        
        // Verify count updated
        const stats2 = registry.getStats();
        try testing.expectEqual(@as(u64, 2), stats2.current_entries);
        
        // Clean up remaining
        try registry.unregister(id1);
        try registry.unregister(id3);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝