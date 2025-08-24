// event.zig — Event system for handling input and system events
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══ PACK ══╗

    const std = @import("std");
    const keyboard = @import("utils/keyboard/keyboard.zig");
    const mouse = @import("utils/mouse/mouse.zig");

// ╚══════════╝

// ╔══ CORE ══╗

    /// Event type enumeration
    pub const EventType = enum {
        key,
        mouse,
        resize,
        focus,
        paste,
    };
    
    /// Main event union
    pub const Event = union(EventType) {
        key: keyboard.KeyEvent,
        mouse: mouse.MouseEvent,
        resize: ResizeEvent,
        focus: FocusEvent,
        paste: PasteEvent,
    };
    
    /// Resize event
    pub const ResizeEvent = struct {
        width: u16,
        height: u16,
    };
    
    /// Focus event
    pub const FocusEvent = struct {
        gained: bool,
    };
    
    /// Paste event
    pub const PasteEvent = struct {
        data: []const u8,
    };
    
    /// Event handler structure
    pub const EventHandler = struct {
        allocator: std.mem.Allocator,
        event_queue: std.ArrayList(Event),
        stdin: std.fs.File,
        buffer: [1024]u8,
        buffer_pos: usize,
        
        /// Initialize event handler
        pub fn init(allocator: std.mem.Allocator) !EventHandler {
            return EventHandler{
                .allocator = allocator,
                .event_queue = std.ArrayList(Event).init(allocator),
                .stdin = std.io.getStdIn(),
                .buffer = undefined,
                .buffer_pos = 0,
            };
        }
        
        /// Deinitialize event handler
        pub fn deinit(self: *EventHandler) void {
            self.event_queue.deinit();
        }
        
        /// Poll for events (non-blocking)
        pub fn poll(self: *EventHandler) !?Event {
            // Try to read input
            try self.read_input();
            
            // Process buffer into events
            try self.process_buffer();
            
            // Return next event if available
            if (self.event_queue.items.len > 0) {
                return self.event_queue.orderedRemove(0);
            }
            
            return null;
        }
        
        /// Wait for next event (blocking)
        pub fn wait(self: *EventHandler) !Event {
            while (true) {
                if (try self.poll()) |event| {
                    return event;
                }
                
                // Small sleep to prevent busy waiting
                std.time.sleep(1_000_000); // 1ms
            }
        }
        
        /// Push event to queue
        pub fn push(self: *EventHandler, event: Event) !void {
            try self.event_queue.append(event);
        }
        
        /// Clear event queue
        pub fn clear(self: *EventHandler) void {
            self.event_queue.clearRetainingCapacity();
        }
        
        // Private functions
        
        /// Read input from stdin
        fn read_input(self: *EventHandler) !void {
            // Check if data is available (non-blocking)
            const available = self.buffer.len - self.buffer_pos;
            if (available == 0) {
                self.buffer_pos = 0;
            }
            
            // Try to read (this would need platform-specific non-blocking I/O)
            // For now, this is a placeholder
        }
        
        /// Process buffer into events
        fn process_buffer(self: *EventHandler) !void {
            // Parse buffer for escape sequences and convert to events
            // This is a placeholder implementation
            _ = self;
        }
    };
    
    /// Event listener callback
    pub const EventListener = fn (event: Event) void;
    
    /// Event dispatcher for managing listeners
    pub const EventDispatcher = struct {
        allocator: std.mem.Allocator,
        listeners: std.ArrayList(EventListener),
        
        /// Initialize dispatcher
        pub fn init(allocator: std.mem.Allocator) EventDispatcher {
            return EventDispatcher{
                .allocator = allocator,
                .listeners = std.ArrayList(EventListener).init(allocator),
            };
        }
        
        /// Deinitialize dispatcher
        pub fn deinit(self: *EventDispatcher) void {
            self.listeners.deinit();
        }
        
        /// Add listener
        pub fn add_listener(self: *EventDispatcher, listener: EventListener) !void {
            try self.listeners.append(listener);
        }
        
        /// Dispatch event to all listeners
        pub fn dispatch(self: *EventDispatcher, event: Event) void {
            for (self.listeners.items) |listener| {
                listener(event);
            }
        }
    };

// ╚══════════╝