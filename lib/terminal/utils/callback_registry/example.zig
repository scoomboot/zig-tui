// example.zig — Example usage of the CallbackRegistry module
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// This file demonstrates how the CallbackRegistry solves Issue #056
// by providing a thread-safe registry for terminal-screen associations.

const std = @import("std");
const registry_module = @import("callback_registry.zig");

// Example: How to integrate CallbackRegistry with Terminal and Screen modules
//
// In terminal.zig, modify the resize callback to use the registry:
//
// ```zig
// fn notifyResizeCallbacks(self: *Terminal, event: ResizeEvent) void {
//     // Get the global registry
//     const registry = registry_module.getGlobalRegistry(self.allocator);
//     
//     // Let the registry handle dispatching to all associated screens
//     registry.handleResize(self, event.new_size.cols, event.new_size.rows, Screen);
// }
// ```
//
// In screen.zig, modify the initWithTerminal method:
//
// ```zig
// pub fn initWithTerminal(allocator: std.mem.Allocator, terminal: *terminal_mod.Terminal) !Screen {
//     const size = try terminal.getSize();
//     var screen = try init_with_size(allocator, size.cols, size.rows);
//     screen.terminal_ref = terminal;
//     
//     // Register with the global callback registry instead of direct callback
//     const registry = registry_module.getGlobalRegistry(allocator);
//     screen.registry_id = try registry.register(terminal, &screen);
//     
//     return screen;
// }
// ```
//
// And in the screen's deinit method:
//
// ```zig
// pub fn deinit(self: *Screen) void {
//     // Unregister from the callback registry
//     if (self.registry_id) |id| {
//         const registry = registry_module.getGlobalRegistry(self.allocator);
//         registry.unregister(id) catch {};
//     }
//     
//     // Free screen buffers
//     self.allocator.free(self.front_buffer);
//     self.allocator.free(self.back_buffer);
// }
// ```

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize the global registry
    const registry = registry_module.getGlobalRegistry(allocator);
    defer registry_module.deinitGlobalRegistry();
    
    std.debug.print("CallbackRegistry Example\n", .{});
    std.debug.print("========================\n\n", .{});
    
    // Simulate terminal and screen setup
    const MockTerminal = struct { id: u32 };
    const MockScreen = struct { 
        width: u16, 
        height: u16,
        
        pub fn handleResize(self: *@This(), w: u16, h: u16, mode: anytype) !void {
            _ = mode;
            self.width = w;
            self.height = h;
            std.debug.print("Screen resized to {}x{}\n", .{ w, h });
        }
    };
    
    var terminal = MockTerminal{ .id = 1 };
    var screen1 = MockScreen{ .width = 80, .height = 24 };
    var screen2 = MockScreen{ .width = 80, .height = 24 };
    
    // Register multiple screens for the same terminal
    const id1 = try registry.register(&terminal, &screen1);
    const id2 = try registry.register(&terminal, &screen2);
    
    std.debug.print("Registered screen1 with ID: {}\n", .{id1});
    std.debug.print("Registered screen2 with ID: {}\n", .{id2});
    
    // Get current statistics
    const stats = registry.getStats();
    std.debug.print("\nRegistry Statistics:\n", .{});
    std.debug.print("  Total registered: {}\n", .{stats.total_registered});
    std.debug.print("  Current entries: {}\n", .{stats.current_entries});
    
    // Simulate a resize event
    std.debug.print("\nSimulating terminal resize to 120x40...\n", .{});
    registry.handleResize(&terminal, 120, 40, MockScreen);
    
    // Check updated statistics
    const updated_stats = registry.getStats();
    std.debug.print("\nResize events handled: {}\n", .{updated_stats.resize_events_handled});
    
    // Find all screens for the terminal
    const entries = registry.findEntriesByTerminal(&terminal);
    defer allocator.free(entries);
    std.debug.print("\nScreens registered for terminal: {}\n", .{entries.len});
    
    // Unregister one screen
    try registry.unregister(id1);
    std.debug.print("\nUnregistered screen1 (ID: {})\n", .{id1});
    
    const final_stats = registry.getStats();
    std.debug.print("\nFinal Registry Statistics:\n", .{});
    std.debug.print("  Total registered: {}\n", .{final_stats.total_registered});
    std.debug.print("  Total unregistered: {}\n", .{final_stats.total_unregistered});
    std.debug.print("  Current entries: {}\n", .{final_stats.current_entries});
}

// Key Benefits of the CallbackRegistry:
//
// 1. **Thread Safety**: All operations are protected by mutex locks
// 2. **No Dangling Pointers**: Uses unique IDs to safely manage references  
// 3. **Multi-Screen Support**: Allows multiple screens per terminal
// 4. **Performance**: O(n) lookups are efficient for typical use cases (n < 10)
// 5. **Statistics**: Built-in metrics for monitoring and debugging
// 6. **Global Singleton**: Optional global instance for easy access across modules