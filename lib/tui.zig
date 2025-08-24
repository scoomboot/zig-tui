// tui.zig — Main entry point for the Zig TUI library
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══ PACK ══╗

    const std = @import("std");
    
    // Core modules
    pub const terminal = @import("terminal/terminal.zig");
    pub const screen = @import("screen/screen.zig");
    pub const event = @import("event/event.zig");
    
    // Future modules (placeholders)
    pub const widget = @import("widget/widget.zig");
    pub const layout = @import("layout/layout.zig");

// ╚══════════╝

// ╔══ CORE ══╗

    /// TUI main context structure
    pub const TUI = struct {
        allocator: std.mem.Allocator,
        terminal: terminal.Terminal,
        screen: screen.Screen,
        event_handler: event.EventHandler,
        
        /// Initialize the TUI system
        pub fn init(allocator: std.mem.Allocator) !TUI {
            return TUI{
                .allocator = allocator,
                .terminal = try terminal.Terminal.init(allocator),
                .screen = try screen.Screen.init(allocator),
                .event_handler = try event.EventHandler.init(allocator),
            };
        }
        
        /// Deinitialize the TUI system
        pub fn deinit(self: *TUI) void {
            self.terminal.deinit();
            self.screen.deinit();
            self.event_handler.deinit();
        }
        
        /// Run the main TUI loop
        pub fn run(self: *TUI) !void {
            // Placeholder implementation
            _ = self;
        }
    };

// ╚══════════╝