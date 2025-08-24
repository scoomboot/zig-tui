# Issue #013: Implement event queue

## Summary
Create a thread-safe event queue system for managing and distributing input events.

## Description
Implement an event queue that collects keyboard (and future mouse) events, provides thread-safe access, and supports event filtering and prioritization. The queue should handle overflow gracefully and provide both blocking and non-blocking event retrieval.

## Acceptance Criteria
- [ ] Create event queue structure
- [ ] Implement thread-safe push/pop operations
- [ ] Add event filtering capabilities
- [ ] Support event priorities
- [ ] Handle queue overflow strategies
- [ ] Implement blocking wait for events
- [ ] Add non-blocking event polling
- [ ] Support event peeking without removal
- [ ] Add event coalescing for similar events
- [ ] Create comprehensive tests
- [ ] Follow MCS style guidelines

## Dependencies
- Issue #012 (Implement keyboard input)

## Implementation Notes
```zig
// Part of event.zig — Event queue management
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const KeyEvent = @import("utils/keyboard/keyboard.zig").KeyEvent;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    pub const EventType = enum {
        key,
        mouse,
        resize,
        focus,
        paste,
        custom,
    };

    pub const Event = union(EventType) {
        key: KeyEvent,
        mouse: MouseEvent,
        resize: ResizeEvent,
        focus: FocusEvent,
        paste: PasteEvent,
        custom: CustomEvent,
        
        pub fn timestamp(self: Event) i64 {
            return switch (self) {
                .key => |e| e.timestamp,
                .mouse => |e| e.timestamp,
                .resize => |e| e.timestamp,
                .focus => |e| e.timestamp,
                .paste => |e| e.timestamp,
                .custom => |e| e.timestamp,
            };
        }
    };

    pub const MouseEvent = struct {
        x: u16,
        y: u16,
        button: MouseButton,
        action: MouseAction,
        modifiers: KeyModifiers,
        timestamp: i64,
    };

    pub const ResizeEvent = struct {
        width: u16,
        height: u16,
        timestamp: i64,
    };

    pub const FocusEvent = struct {
        gained: bool,
        timestamp: i64,
    };

    pub const PasteEvent = struct {
        data: []const u8,
        timestamp: i64,
    };

    pub const CustomEvent = struct {
        id: u32,
        data: ?*anyopaque,
        timestamp: i64,
    };

    pub const EventPriority = enum(u8) {
        low = 0,
        normal = 1,
        high = 2,
        critical = 3,
    };

    pub const EventFilter = struct {
        type_mask: EventTypeMask = EventTypeMask.all(),
        callback: ?*const fn (Event) bool = null,
        
        pub const EventTypeMask = packed struct {
            key: bool = true,
            mouse: bool = true,
            resize: bool = true,
            focus: bool = true,
            paste: bool = true,
            custom: bool = true,
            
            pub fn all() EventTypeMask {
                return .{};
            }
            
            pub fn none() EventTypeMask {
                return .{
                    .key = false,
                    .mouse = false,
                    .resize = false,
                    .focus = false,
                    .paste = false,
                    .custom = false,
                };
            }
        };
        
        pub fn accepts(self: EventFilter, event: Event) bool {
            // Check type mask
            const type_accepted = switch (event) {
                .key => self.type_mask.key,
                .mouse => self.type_mask.mouse,
                .resize => self.type_mask.resize,
                .focus => self.type_mask.focus,
                .paste => self.type_mask.paste,
                .custom => self.type_mask.custom,
            };
            
            if (!type_accepted) return false;
            
            // Apply callback filter if present
            if (self.callback) |cb| {
                return cb(event);
            }
            
            return true;
        }
    };

    pub const QueueOverflowStrategy = enum {
        drop_oldest,    // Remove oldest events
        drop_newest,    // Reject new events
        block,          // Block until space available
        expand,         // Dynamically grow queue
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    pub const EventQueue = struct {
        allocator: std.mem.Allocator,
        events: std.ArrayList(PrioritizedEvent),
        mutex: std.Thread.Mutex,
        not_empty: std.Thread.Condition,
        capacity: usize,
        overflow_strategy: QueueOverflowStrategy,
        stats: QueueStats,
        
        const PrioritizedEvent = struct {
            event: Event,
            priority: EventPriority,
            
            fn compare(_: void, a: PrioritizedEvent, b: PrioritizedEvent) std.math.Order {
                // Higher priority first
                if (a.priority != b.priority) {
                    return std.math.order(@enumToInt(b.priority), @enumToInt(a.priority));
                }
                // Earlier timestamp first for same priority
                return std.math.order(a.event.timestamp(), b.event.timestamp());
            }
        };
        
        pub const QueueStats = struct {
            events_pushed: u64 = 0,
            events_popped: u64 = 0,
            events_dropped: u64 = 0,
            events_coalesced: u64 = 0,
            peak_size: usize = 0,
        };

        // ┌──────────────────────────── Initialization ────────────────────────────┐

            pub fn init(allocator: std.mem.Allocator, capacity: usize) !EventQueue {
                return EventQueue{
                    .allocator = allocator,
                    .events = std.ArrayList(PrioritizedEvent).init(allocator),
                    .mutex = .{},
                    .not_empty = .{},
                    .capacity = capacity,
                    .overflow_strategy = .drop_oldest,
                    .stats = .{},
                };
            }

            pub fn deinit(self: *EventQueue) void {
                self.events.deinit();
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Push Operations ────────────────────────────┐

            /// Push an event with normal priority
            pub fn push(self: *EventQueue, event: Event) !void {
                try self.pushWithPriority(event, .normal);
            }

            /// Push an event with specified priority
            pub fn pushWithPriority(self: *EventQueue, event: Event, priority: EventPriority) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                // Handle overflow
                if (self.events.items.len >= self.capacity) {
                    switch (self.overflow_strategy) {
                        .drop_oldest => {
                            _ = self.events.orderedRemove(0);
                            self.stats.events_dropped += 1;
                        },
                        .drop_newest => {
                            self.stats.events_dropped += 1;
                            return;
                        },
                        .block => {
                            // Would need to implement blocking logic
                            return error.QueueFull;
                        },
                        .expand => {
                            // Allow ArrayList to grow
                        },
                    }
                }
                
                // Check for coalescing opportunities
                if (self.tryCoalesce(event)) {
                    self.stats.events_coalesced += 1;
                    return;
                }
                
                // Add event
                try self.events.append(PrioritizedEvent{
                    .event = event,
                    .priority = priority,
                });
                
                // Sort by priority (could use a heap for better performance)
                std.sort.sort(PrioritizedEvent, self.events.items, {}, PrioritizedEvent.compare);
                
                // Update stats
                self.stats.events_pushed += 1;
                if (self.events.items.len > self.stats.peak_size) {
                    self.stats.peak_size = self.events.items.len;
                }
                
                // Signal waiting threads
                self.not_empty.signal();
            }

            /// Try to coalesce similar events
            fn tryCoalesce(self: *EventQueue, event: Event) bool {
                // Coalesce resize events
                if (event == .resize) {
                    for (self.events.items) |*existing| {
                        if (existing.event == .resize) {
                            existing.event.resize = event.resize;
                            return true;
                        }
                    }
                }
                
                // Could add more coalescing strategies
                return false;
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Pop Operations ────────────────────────────┐

            /// Pop next event (blocking)
            pub fn pop(self: *EventQueue) Event {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                while (self.events.items.len == 0) {
                    self.not_empty.wait(&self.mutex);
                }
                
                const event = self.events.orderedRemove(0).event;
                self.stats.events_popped += 1;
                return event;
            }

            /// Pop next event (non-blocking)
            pub fn tryPop(self: *EventQueue) ?Event {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                if (self.events.items.len == 0) {
                    return null;
                }
                
                const event = self.events.orderedRemove(0).event;
                self.stats.events_popped += 1;
                return event;
            }

            /// Pop next event with timeout
            pub fn popTimeout(self: *EventQueue, timeout_ms: u64) ?Event {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                const deadline = std.time.milliTimestamp() + @intCast(i64, timeout_ms);
                
                while (self.events.items.len == 0) {
                    const now = std.time.milliTimestamp();
                    if (now >= deadline) {
                        return null;
                    }
                    
                    const remaining = @intCast(u64, deadline - now);
                    if (!self.not_empty.timedWait(&self.mutex, remaining * std.time.ns_per_ms)) {
                        return null;
                    }
                }
                
                const event = self.events.orderedRemove(0).event;
                self.stats.events_popped += 1;
                return event;
            }

            /// Pop events matching filter
            pub fn popFiltered(self: *EventQueue, filter: EventFilter) ?Event {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                var i: usize = 0;
                while (i < self.events.items.len) : (i += 1) {
                    if (filter.accepts(self.events.items[i].event)) {
                        const event = self.events.orderedRemove(i).event;
                        self.stats.events_popped += 1;
                        return event;
                    }
                }
                
                return null;
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Utility Methods ────────────────────────────┐

            /// Peek at next event without removing
            pub fn peek(self: *EventQueue) ?Event {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                if (self.events.items.len == 0) {
                    return null;
                }
                
                return self.events.items[0].event;
            }

            /// Check if queue is empty
            pub fn isEmpty(self: *EventQueue) bool {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                return self.events.items.len == 0;
            }

            /// Get current queue size
            pub fn size(self: *EventQueue) usize {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                return self.events.items.len;
            }

            /// Clear all events
            pub fn clear(self: *EventQueue) void {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                self.events.clearRetainingCapacity();
            }

            /// Get queue statistics
            pub fn getStats(self: *EventQueue) QueueStats {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                return self.stats;
            }

        // └──────────────────────────────────────────────────────────────────┘

    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Test thread-safe operations
- Test priority ordering
- Test overflow strategies
- Test event filtering
- Test blocking/non-blocking operations
- Test event coalescing
- Test timeout operations
- Performance: < 1μs for push/pop operations

## Estimated Time
2 hours

## Priority
🟡 High - Core event infrastructure

## Category
Event System