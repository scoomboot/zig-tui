# Issue #014: Implement event loop

## Summary
Create the main event loop architecture that coordinates input reading, event processing, and rendering.

## Description
Implement a flexible event loop that manages the application lifecycle, processes events from multiple sources, handles timers, and coordinates rendering. The event loop should support both blocking and non-blocking modes, custom event handlers, and graceful shutdown.

## Acceptance Criteria
- [ ] Create main event loop structure
- [ ] Integrate keyboard input reader
- [ ] Support event handler registration
- [ ] Implement timer/scheduled events
- [ ] Add frame rate limiting
- [ ] Support custom event sources
- [ ] Handle shutdown signals gracefully
- [ ] Implement event dispatching
- [ ] Add loop lifecycle hooks
- [ ] Create comprehensive tests
- [ ] Follow MCS style guidelines

## Dependencies
- Issue #013 (Implement event queue)

## Implementation Notes
```zig
// event.zig — Main event system and loop
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const KeyboardReader = @import("utils/keyboard/keyboard.zig").KeyboardReader;
    const MouseReader = @import("utils/mouse/mouse.zig").MouseReader;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    pub const EventHandler = *const fn (event: Event, context: *anyopaque) void;
    
    pub const Timer = struct {
        id: u32,
        interval_ms: u64,
        repeat: bool,
        callback: *const fn (timer_id: u32, context: *anyopaque) void,
        context: *anyopaque,
        next_fire: i64,
        active: bool,
    };

    pub const LoopMode = enum {
        blocking,      // Wait for events
        polling,       // Check for events, don't wait
        frame_limited, // Run at specific FPS
    };

    pub const LoopConfig = struct {
        mode: LoopMode = .blocking,
        target_fps: u16 = 60,
        event_timeout_ms: u64 = 100,
        max_events_per_frame: u32 = 100,
    };

    pub const LoopState = enum {
        stopped,
        running,
        paused,
        stopping,
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    pub const EventLoop = struct {
        allocator: std.mem.Allocator,
        queue: EventQueue,
        keyboard: KeyboardReader,
        mouse: ?MouseReader,
        handlers: std.ArrayList(HandlerEntry),
        timers: std.ArrayList(Timer),
        config: LoopConfig,
        state: LoopState,
        stats: LoopStats,
        shutdown_requested: std.atomic.Atomic(bool),
        next_timer_id: u32,
        
        const HandlerEntry = struct {
            filter: EventFilter,
            handler: EventHandler,
            context: *anyopaque,
            priority: u8,
        };
        
        pub const LoopStats = struct {
            frames: u64 = 0,
            events_processed: u64 = 0,
            average_fps: f32 = 0,
            last_frame_time: i64 = 0,
            frame_time_ms: u64 = 0,
        };

        // ┌──────────────────────────── Initialization ────────────────────────────┐

            pub fn init(allocator: std.mem.Allocator, config: LoopConfig) !EventLoop {
                var loop = EventLoop{
                    .allocator = allocator,
                    .queue = try EventQueue.init(allocator, 256),
                    .keyboard = KeyboardReader.init(),
                    .mouse = null, // Optional mouse support
                    .handlers = std.ArrayList(HandlerEntry).init(allocator),
                    .timers = std.ArrayList(Timer).init(allocator),
                    .config = config,
                    .state = .stopped,
                    .stats = .{},
                    .shutdown_requested = std.atomic.Atomic(bool).init(false),
                    .next_timer_id = 1,
                };
                
                // Set up signal handlers
                try loop.setupSignalHandlers();
                
                return loop;
            }

            pub fn deinit(self: *EventLoop) void {
                self.queue.deinit();
                self.handlers.deinit();
                self.timers.deinit();
            }

            fn setupSignalHandlers(self: *EventLoop) !void {
                // Install handlers for SIGINT, SIGTERM
                _ = self;
                // Implementation depends on platform
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Main Loop ────────────────────────────┐

            /// Start the event loop
            pub fn run(self: *EventLoop) !void {
                self.state = .running;
                self.stats.last_frame_time = std.time.milliTimestamp();
                
                defer self.state = .stopped;
                
                while (self.state == .running and !self.shutdown_requested.load(.Acquire)) {
                    const frame_start = std.time.milliTimestamp();
                    
                    // Process one frame
                    try self.processFrame();
                    
                    // Update stats
                    self.stats.frames += 1;
                    self.stats.frame_time_ms = @intCast(u64, std.time.milliTimestamp() - frame_start);
                    
                    // Frame rate limiting
                    if (self.config.mode == .frame_limited) {
                        const target_frame_time = 1000 / self.config.target_fps;
                        const elapsed = @intCast(u64, std.time.milliTimestamp() - frame_start);
                        
                        if (elapsed < target_frame_time) {
                            std.time.sleep((target_frame_time - elapsed) * std.time.ns_per_ms);
                        }
                    }
                    
                    self.stats.last_frame_time = frame_start;
                }
            }

            /// Process a single frame
            fn processFrame(self: *EventLoop) !void {
                // Collect input events
                try self.collectInputEvents();
                
                // Process timers
                try self.processTimers();
                
                // Process events
                var events_processed: u32 = 0;
                while (events_processed < self.config.max_events_per_frame) {
                    const event = switch (self.config.mode) {
                        .blocking => self.queue.popTimeout(self.config.event_timeout_ms),
                        .polling, .frame_limited => self.queue.tryPop(),
                    };
                    
                    if (event == null) break;
                    
                    try self.dispatchEvent(event.?);
                    events_processed += 1;
                    self.stats.events_processed += 1;
                }
            }

            /// Stop the event loop
            pub fn stop(self: *EventLoop) void {
                self.state = .stopping;
                self.shutdown_requested.store(true, .Release);
                
                // Wake up blocked threads
                self.queue.push(.{
                    .custom = .{
                        .id = 0xDEADBEEF, // Shutdown marker
                        .data = null,
                        .timestamp = std.time.milliTimestamp(),
                    },
                }) catch {};
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Event Collection ────────────────────────────┐

            fn collectInputEvents(self: *EventLoop) !void {
                // Read keyboard events
                var key_events: [32]KeyEvent = undefined;
                const key_count = try self.keyboard.readKeys(&key_events);
                
                for (key_events[0..key_count]) |key_event| {
                    try self.queue.push(.{ .key = key_event });
                }
                
                // Read mouse events if available
                if (self.mouse) |*mouse| {
                    var mouse_events: [32]MouseEvent = undefined;
                    const mouse_count = try mouse.readEvents(&mouse_events);
                    
                    for (mouse_events[0..mouse_count]) |mouse_event| {
                        try self.queue.push(.{ .mouse = mouse_event });
                    }
                }
                
                // Check for resize events
                // Platform-specific implementation
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Event Dispatch ────────────────────────────┐

            fn dispatchEvent(self: *EventLoop, event: Event) !void {
                // Sort handlers by priority if needed
                std.sort.sort(HandlerEntry, self.handlers.items, {}, struct {
                    fn compare(_: void, a: HandlerEntry, b: HandlerEntry) bool {
                        return a.priority > b.priority;
                    }
                }.compare);
                
                // Dispatch to matching handlers
                for (self.handlers.items) |handler| {
                    if (handler.filter.accepts(event)) {
                        handler.handler(event, handler.context);
                    }
                }
            }

            /// Register an event handler
            pub fn addHandler(
                self: *EventLoop,
                filter: EventFilter,
                handler: EventHandler,
                context: *anyopaque,
            ) !void {
                try self.handlers.append(.{
                    .filter = filter,
                    .handler = handler,
                    .context = context,
                    .priority = 0,
                });
            }

            /// Register a prioritized event handler
            pub fn addPrioritizedHandler(
                self: *EventLoop,
                filter: EventFilter,
                handler: EventHandler,
                context: *anyopaque,
                priority: u8,
            ) !void {
                try self.handlers.append(.{
                    .filter = filter,
                    .handler = handler,
                    .context = context,
                    .priority = priority,
                });
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Timer Management ────────────────────────────┐

            /// Add a timer
            pub fn addTimer(
                self: *EventLoop,
                interval_ms: u64,
                repeat: bool,
                callback: *const fn (u32, *anyopaque) void,
                context: *anyopaque,
            ) !u32 {
                const timer_id = self.next_timer_id;
                self.next_timer_id += 1;
                
                try self.timers.append(.{
                    .id = timer_id,
                    .interval_ms = interval_ms,
                    .repeat = repeat,
                    .callback = callback,
                    .context = context,
                    .next_fire = std.time.milliTimestamp() + @intCast(i64, interval_ms),
                    .active = true,
                });
                
                return timer_id;
            }

            /// Remove a timer
            pub fn removeTimer(self: *EventLoop, timer_id: u32) void {
                for (self.timers.items) |*timer| {
                    if (timer.id == timer_id) {
                        timer.active = false;
                        break;
                    }
                }
            }

            fn processTimers(self: *EventLoop) !void {
                const now = std.time.milliTimestamp();
                var i: usize = 0;
                
                while (i < self.timers.items.len) {
                    var timer = &self.timers.items[i];
                    
                    if (!timer.active) {
                        _ = self.timers.swapRemove(i);
                        continue;
                    }
                    
                    if (now >= timer.next_fire) {
                        // Fire timer
                        timer.callback(timer.id, timer.context);
                        
                        if (timer.repeat) {
                            timer.next_fire = now + @intCast(i64, timer.interval_ms);
                            i += 1;
                        } else {
                            _ = self.timers.swapRemove(i);
                        }
                    } else {
                        i += 1;
                    }
                }
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Utility Methods ────────────────────────────┐

            /// Pause the event loop
            pub fn pause(self: *EventLoop) void {
                self.state = .paused;
            }

            /// Resume the event loop
            pub fn resume(self: *EventLoop) void {
                if (self.state == .paused) {
                    self.state = .running;
                }
            }

            /// Get loop statistics
            pub fn getStats(self: *EventLoop) LoopStats {
                return self.stats;
            }

            /// Process a single event (for testing)
            pub fn step(self: *EventLoop) !bool {
                try self.collectInputEvents();
                
                if (self.queue.tryPop()) |event| {
                    try self.dispatchEvent(event);
                    return true;
                }
                
                return false;
            }

        // └──────────────────────────────────────────────────────────────────┘

    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Test event loop lifecycle
- Test event handler registration
- Test timer functionality
- Test frame rate limiting
- Test different loop modes
- Test shutdown handling
- Test event dispatching order
- Performance: < 1ms overhead per frame

## Estimated Time
3 hours

## Priority
🟡 High - Core application structure

## Category
Event System