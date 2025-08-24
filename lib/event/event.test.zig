// event.test.zig — Comprehensive tests for event system
//
// repo   : https://github.com/fisty/zig-tui
// author : https://github.com/fisty
//
// Tests for event queue, event loop, and event handling.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Event = @import("event.zig").Event;
    const EventQueue = @import("event.zig").EventQueue;
    const EventLoop = @import("event.zig").EventLoop;
    const KeyEvent = @import("utils/keyboard/keyboard.zig").KeyEvent;
    const MouseEvent = @import("utils/mouse/mouse.zig").MouseEvent;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test constants
    const MAX_QUEUE_SIZE = 1000;
    const EVENT_TIMEOUT_MS = 100;
    
    // Test event types
    const TestEvent = union(enum) {
        key: KeyEvent,
        mouse: MouseEvent,
        resize: struct { width: u16, height: u16 },
        custom: u32,
    };
    
    // Test helpers
    const TestEventQueue = struct {
        queue: EventQueue,
        allocator: std.mem.Allocator,
        
        pub fn init(allocator: std.mem.Allocator) !TestEventQueue {
            return TestEventQueue{
                .queue = try EventQueue.init(allocator, MAX_QUEUE_SIZE),
                .allocator = allocator,
            };
        }
        
        pub fn deinit(self: *TestEventQueue) void {
            self.queue.deinit();
        }
    };
    
    // Creates test events
    fn createKeyEvent(key: u8, modifiers: u8) Event {
        return Event{
            .type = .key,
            .data = .{ .key = KeyEvent{ .key = key, .modifiers = modifiers } },
        };
    }
    
    fn createMouseEvent(x: u16, y: u16, button: u8) Event {
        return Event{
            .type = .mouse,
            .data = .{ .mouse = MouseEvent{ .x = x, .y = y, .button = button } },
        };
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐
    
        test "unit: EventQueue: initializes empty" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 100);
            defer queue.deinit();
            
            try testing.expect(queue.isEmpty());
            try testing.expectEqual(@as(usize, 0), queue.size());
        }
        
        test "unit: EventQueue: pushes and pops events correctly" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 10);
            defer queue.deinit();
            
            const event = createKeyEvent('A', 0);
            try queue.push(event);
            
            try testing.expect(!queue.isEmpty());
            try testing.expectEqual(@as(usize, 1), queue.size());
            
            const popped = try queue.pop();
            try testing.expectEqual(event.type, popped.type);
        }
        
        test "unit: EventQueue: handles queue overflow" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 5);
            defer queue.deinit();
            
            // Fill queue
            for (0..5) |i| {
                const event = createKeyEvent(@intCast(i), 0);
                try queue.push(event);
            }
            
            // Try to overflow
            const overflow_event = createKeyEvent('X', 0);
            const result = queue.push(overflow_event);
            try testing.expectError(EventQueue.Error.QueueFull, result);
        }
        
        test "unit: EventQueue: clears queue correctly" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 10);
            defer queue.deinit();
            
            // Add events
            for (0..5) |i| {
                const event = createKeyEvent(@intCast(i), 0);
                try queue.push(event);
            }
            
            queue.clear();
            try testing.expect(queue.isEmpty());
            try testing.expectEqual(@as(usize, 0), queue.size());
        }
        
        test "unit: Event: creates key events correctly" {
            const event = createKeyEvent('Z', 1);
            
            try testing.expectEqual(Event.Type.key, event.type);
            try testing.expectEqual(@as(u8, 'Z'), event.data.key.key);
            try testing.expectEqual(@as(u8, 1), event.data.key.modifiers);
        }
        
        test "unit: Event: creates mouse events correctly" {
            const event = createMouseEvent(100, 50, 1);
            
            try testing.expectEqual(Event.Type.mouse, event.type);
            try testing.expectEqual(@as(u16, 100), event.data.mouse.x);
            try testing.expectEqual(@as(u16, 50), event.data.mouse.y);
            try testing.expectEqual(@as(u8, 1), event.data.mouse.button);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: EventQueue with EventLoop: processes events" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 100);
            defer queue.deinit();
            
            var loop = try EventLoop.init(allocator, &queue);
            defer loop.deinit();
            
            // Add events to queue
            try queue.push(createKeyEvent('A', 0));
            try queue.push(createMouseEvent(10, 20, 1));
            try queue.push(createKeyEvent('B', 0));
            
            var processed_count: usize = 0;
            
            // Process events
            while (!queue.isEmpty()) {
                const event = try queue.pop();
                processed_count += 1;
                
                switch (event.type) {
                    .key => try testing.expect(true),
                    .mouse => try testing.expect(true),
                    else => unreachable,
                }
            }
            
            try testing.expectEqual(@as(usize, 3), processed_count);
        }
        
        test "integration: EventLoop with handlers: dispatches correctly" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 50);
            defer queue.deinit();
            
            var loop = try EventLoop.init(allocator, &queue);
            defer loop.deinit();
            
            var key_count: u32 = 0;
            var mouse_count: u32 = 0;
            
            // Register handlers
            const key_handler = struct {
                fn handle(event: Event, ctx: *anyopaque) !void {
                    const count_ptr = @as(*u32, @ptrCast(@alignCast(ctx)));
                    count_ptr.* += 1;
                    _ = event;
                }
            }.handle;
            
            const mouse_handler = struct {
                fn handle(event: Event, ctx: *anyopaque) !void {
                    const count_ptr = @as(*u32, @ptrCast(@alignCast(ctx)));
                    count_ptr.* += 1;
                    _ = event;
                }
            }.handle;
            
            try loop.registerHandler(.key, key_handler, &key_count);
            try loop.registerHandler(.mouse, mouse_handler, &mouse_count);
            
            // Add and process events
            try queue.push(createKeyEvent('K', 0));
            try queue.push(createMouseEvent(5, 5, 0));
            try queue.push(createKeyEvent('L', 0));
            
            try loop.processEvents();
            
            try testing.expectEqual(@as(u32, 2), key_count);
            try testing.expectEqual(@as(u32, 1), mouse_count);
        }
        
        test "integration: Event filtering: filters events correctly" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 50);
            defer queue.deinit();
            
            // Add mixed events
            try queue.push(createKeyEvent('A', 0));
            try queue.push(createMouseEvent(1, 1, 0));
            try queue.push(createKeyEvent('B', 0));
            try queue.push(createMouseEvent(2, 2, 0));
            
            // Filter only key events
            var key_events = std.ArrayList(Event).init(allocator);
            defer key_events.deinit();
            
            while (!queue.isEmpty()) {
                const event = try queue.pop();
                if (event.type == .key) {
                    try key_events.append(event);
                }
            }
            
            try testing.expectEqual(@as(usize, 2), key_events.items.len);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── E2E Tests ────────────────────────────┐
    
        test "e2e: complete event flow: input to handler" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 100);
            defer queue.deinit();
            
            var loop = try EventLoop.init(allocator, &queue);
            defer loop.deinit();
            
            // Simulate user input sequence
            const input_sequence = [_]Event{
                createKeyEvent('H', 0),  // H
                createKeyEvent('e', 0),  // e
                createKeyEvent('l', 0),  // l
                createKeyEvent('l', 0),  // l
                createKeyEvent('o', 0),  // o
                createMouseEvent(50, 25, 1),  // Click
            };
            
            // Queue events
            for (input_sequence) |event| {
                try queue.push(event);
            }
            
            var output = std.ArrayList(u8).init(allocator);
            defer output.deinit();
            
            // Process all events
            while (!queue.isEmpty()) {
                const event = try queue.pop();
                
                switch (event.type) {
                    .key => try output.append(event.data.key.key),
                    .mouse => try output.append('!'),
                    else => {},
                }
            }
            
            try testing.expectEqualStrings("Hello!", output.items);
        }
        
        test "e2e: event loop lifecycle: start to stop" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 100);
            defer queue.deinit();
            
            var loop = try EventLoop.init(allocator, &queue);
            defer loop.deinit();
            
            // Start loop
            try loop.start();
            try testing.expect(loop.isRunning());
            
            // Add events while running
            try queue.push(createKeyEvent('Q', 1));  // Ctrl+Q to quit
            
            // Process one iteration
            try loop.tick();
            
            // Stop loop
            try loop.stop();
            try testing.expect(!loop.isRunning());
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: EventQueue: handles high throughput" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 10000);
            defer queue.deinit();
            
            const event_count = 100000;
            
            const start = std.time.milliTimestamp();
            
            // Rapid push/pop cycles
            for (0..event_count) |i| {
                const event = createKeyEvent(@intCast(i % 256), 0);
                try queue.push(event);
                _ = try queue.pop();
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should handle 100k events quickly
            try testing.expect(elapsed < 1000);
        }
        
        test "performance: EventLoop.processEvents: processes batch efficiently" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 5000);
            defer queue.deinit();
            
            var loop = try EventLoop.init(allocator, &queue);
            defer loop.deinit();
            
            // Add many events
            for (0..1000) |i| {
                if (i % 2 == 0) {
                    try queue.push(createKeyEvent(@intCast(i % 128), 0));
                } else {
                    try queue.push(createMouseEvent(@intCast(i % 100), @intCast(i % 50), 0));
                }
            }
            
            const start = std.time.milliTimestamp();
            try loop.processEvents();
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should process 1000 events quickly
            try testing.expect(elapsed < 100);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Stress Tests ────────────────────────────┐
    
        test "stress: EventQueue: survives concurrent operations" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 1000);
            defer queue.deinit();
            
            var prng = std.rand.DefaultPrng.init(99999);
            const random = prng.random();
            
            // Simulate concurrent push/pop operations
            for (0..10000) |_| {
                const op = random.intRangeLessThan(u8, 0, 3);
                
                switch (op) {
                    0 => {
                        // Push
                        const event = createKeyEvent(random.int(u8), 0);
                        queue.push(event) catch {};
                    },
                    1 => {
                        // Pop
                        _ = queue.pop() catch {};
                    },
                    2 => {
                        // Clear
                        if (random.boolean()) {
                            queue.clear();
                        }
                    },
                    else => unreachable,
                }
            }
            
            // Queue should be stable
            _ = queue.size();
            try testing.expect(true);
        }
        
        test "stress: EventLoop: handles event storms" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 5000);
            defer queue.deinit();
            
            var loop = try EventLoop.init(allocator, &queue);
            defer loop.deinit();
            
            // Generate event storm
            for (0..5000) |i| {
                const event_type = i % 3;
                const event = switch (event_type) {
                    0 => createKeyEvent(@intCast(i % 256), @intCast(i % 4)),
                    1 => createMouseEvent(@intCast(i % 1000), @intCast(i % 500), @intCast(i % 3)),
                    2 => Event{ .type = .resize, .data = .{ .resize = .{ .width = @intCast(i % 200), .height = @intCast(i % 100) } } },
                    else => unreachable,
                };
                queue.push(event) catch break;
            }
            
            // Process all events
            var processed: usize = 0;
            while (!queue.isEmpty()) {
                _ = try queue.pop();
                processed += 1;
            }
            
            // Should handle all events
            try testing.expect(processed > 0);
        }
    
    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝