# Issue #018: Create event tests

## Summary
Implement comprehensive unit tests for the event system including keyboard input, event queue, event loop, and key mapping.

## Description
Create a complete test suite for the event system that covers input parsing, event queue management, event loop lifecycle, and key mapping functionality. Tests should validate thread safety, performance, and correct behavior of all event handling components.

## Acceptance Criteria
- [ ] Create `lib/event/event.test.zig`
- [ ] Test keyboard input parsing
- [ ] Test event queue operations
- [ ] Test event loop lifecycle
- [ ] Test key mapping system
- [ ] Test escape sequence parsing
- [ ] Test Unicode input handling
- [ ] Test thread safety
- [ ] Test timer functionality
- [ ] Test event filtering
- [ ] Follow MCS test categorization
- [ ] Achieve >95% code coverage

## Dependencies
- Issue #012 (Implement keyboard input)
- Issue #013 (Implement event queue)
- Issue #014 (Implement event loop)
- Issue #015 (Implement key mapping)

## Implementation Notes
```zig
// event.test.zig — Tests for event system
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Event = @import("event.zig").Event;
    const EventLoop = @import("event.zig").EventLoop;
    const EventQueue = @import("event.zig").EventQueue;
    const KeyboardReader = @import("utils/keyboard/keyboard.zig").KeyboardReader;
    const KeyEvent = @import("utils/keyboard/keyboard.zig").KeyEvent;
    const KeyCode = @import("utils/keyboard/keyboard.zig").KeyCode;
    const KeyModifiers = @import("utils/keyboard/keyboard.zig").KeyModifiers;
    const KeyMapper = @import("utils/keyboard/key_mapping.zig").KeyMapper;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test helpers
    fn createTestEvent(ch: u21) Event {
        return .{
            .key = KeyEvent{
                .code = .{ .char = ch },
                .modifiers = KeyModifiers.none(),
                .timestamp = std.time.milliTimestamp(),
            },
        };
    }

    fn createSpecialKeyEvent(special: KeyCode.SpecialKey) Event {
        return .{
            .key = KeyEvent{
                .code = .{ .special = special },
                .modifiers = KeyModifiers.none(),
                .timestamp = std.time.milliTimestamp(),
            },
        };
    }

    const MockInput = struct {
        data: []const u8,
        pos: usize,
        
        pub fn init(data: []const u8) MockInput {
            return .{ .data = data, .pos = 0 };
        }
        
        pub fn read(self: *MockInput, buf: []u8) !usize {
            const remaining = self.data.len - self.pos;
            if (remaining == 0) return 0;
            
            const to_read = @min(buf.len, remaining);
            std.mem.copy(u8, buf, self.data[self.pos..self.pos + to_read]);
            self.pos += to_read;
            return to_read;
        }
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Keyboard Input Tests ────────────────────────────┐

        test "unit: KeyboardReader: parses ASCII keys" {
            var reader = KeyboardReader.init();
            
            // Simulate input
            reader.buffer = "Hello".*;
            reader.buffer_len = 5;
            reader.buffer_pos = 0;
            
            // Read keys
            const h = try reader.parseNext();
            try testing.expect(h != null);
            try testing.expect(h.?.isChar('H'));
            
            const e = try reader.parseNext();
            try testing.expect(e != null);
            try testing.expect(e.?.isChar('e'));
        }

        test "unit: KeyboardReader: parses control characters" {
            var reader = KeyboardReader.init();
            
            // Enter key
            reader.buffer[0] = 0x0D;
            reader.buffer_len = 1;
            reader.buffer_pos = 0;
            
            const enter = try reader.parseNext();
            try testing.expect(enter != null);
            try testing.expect(enter.?.code == .special);
            try testing.expect(enter.?.code.special == .enter);
            
            // Tab key
            reader.buffer[0] = 0x09;
            reader.buffer_pos = 0;
            
            const tab = try reader.parseNext();
            try testing.expect(tab != null);
            try testing.expect(tab.?.code.special == .tab);
            
            // Ctrl+C
            reader.buffer[0] = 0x03;
            reader.buffer_pos = 0;
            
            const ctrl_c = try reader.parseNext();
            try testing.expect(ctrl_c != null);
            try testing.expect(ctrl_c.?.modifiers.ctrl);
            try testing.expect(ctrl_c.?.isChar('c'));
        }

        test "unit: KeyboardReader: parses arrow keys" {
            var reader = KeyboardReader.init();
            
            // Up arrow: ESC[A
            reader.buffer = [_]u8{ 0x1B, '[', 'A', 0, 0 };
            reader.buffer_len = 3;
            reader.buffer_pos = 0;
            
            const up = try reader.parseNext();
            try testing.expect(up != null);
            try testing.expect(up.?.code.special == .arrow_up);
            
            // Down arrow: ESC[B
            reader.buffer = [_]u8{ 0x1B, '[', 'B', 0, 0 };
            reader.buffer_len = 3;
            reader.buffer_pos = 0;
            
            const down = try reader.parseNext();
            try testing.expect(down != null);
            try testing.expect(down.?.code.special == .arrow_down);
        }

        test "unit: KeyboardReader: parses function keys" {
            var reader = KeyboardReader.init();
            
            // F1: ESC[11~ or ESCOP
            reader.buffer = [_]u8{ 0x1B, 'O', 'P', 0, 0 };
            reader.buffer_len = 3;
            reader.buffer_pos = 0;
            
            const f1 = try reader.parseNext();
            try testing.expect(f1 != null);
            try testing.expect(f1.?.code == .function);
            try testing.expect(f1.?.code.function == 1);
        }

        test "unit: KeyboardReader: parses modified keys" {
            var reader = KeyboardReader.init();
            
            // Ctrl+Up: ESC[1;5A
            reader.buffer = [_]u8{ 0x1B, '[', '1', ';', '5', 'A' };
            reader.buffer_len = 6;
            reader.buffer_pos = 0;
            
            const ctrl_up = try reader.parseNext();
            try testing.expect(ctrl_up != null);
            try testing.expect(ctrl_up.?.code.special == .arrow_up);
            try testing.expect(ctrl_up.?.modifiers.ctrl);
        }

        test "unit: KeyboardReader: handles UTF-8" {
            var reader = KeyboardReader.init();
            
            // Euro sign: €
            reader.buffer = [_]u8{ 0xE2, 0x82, 0xAC, 0, 0 };
            reader.buffer_len = 3;
            reader.buffer_pos = 0;
            
            const euro = try reader.parseNext();
            try testing.expect(euro != null);
            try testing.expect(euro.?.code == .char);
            try testing.expect(euro.?.code.char == '€');
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Event Queue Tests ────────────────────────────┐

        test "unit: EventQueue: push and pop operations" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 10);
            defer queue.deinit();
            
            // Push events
            try queue.push(createTestEvent('A'));
            try queue.push(createTestEvent('B'));
            try queue.push(createTestEvent('C'));
            
            // Pop events
            const a = queue.tryPop();
            try testing.expect(a != null);
            try testing.expect(a.?.key.isChar('A'));
            
            const b = queue.tryPop();
            try testing.expect(b != null);
            try testing.expect(b.?.key.isChar('B'));
            
            const c = queue.tryPop();
            try testing.expect(c != null);
            try testing.expect(c.?.key.isChar('C'));
            
            // Queue should be empty
            try testing.expect(queue.isEmpty());
            try testing.expect(queue.tryPop() == null);
        }

        test "unit: EventQueue: priority ordering" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 10);
            defer queue.deinit();
            
            // Push events with different priorities
            try queue.pushWithPriority(createTestEvent('L'), .low);
            try queue.pushWithPriority(createTestEvent('H'), .high);
            try queue.pushWithPriority(createTestEvent('N'), .normal);
            try queue.pushWithPriority(createTestEvent('C'), .critical);
            
            // Should pop in priority order
            const first = queue.tryPop();
            try testing.expect(first.?.key.isChar('C')); // Critical
            
            const second = queue.tryPop();
            try testing.expect(second.?.key.isChar('H')); // High
            
            const third = queue.tryPop();
            try testing.expect(third.?.key.isChar('N')); // Normal
            
            const fourth = queue.tryPop();
            try testing.expect(fourth.?.key.isChar('L')); // Low
        }

        test "unit: EventQueue: overflow handling" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 3);
            defer queue.deinit();
            
            queue.overflow_strategy = .drop_oldest;
            
            // Fill queue
            try queue.push(createTestEvent('A'));
            try queue.push(createTestEvent('B'));
            try queue.push(createTestEvent('C'));
            
            // Overflow should drop oldest
            try queue.push(createTestEvent('D'));
            
            // Should have B, C, D
            try testing.expect(queue.tryPop().?.key.isChar('B'));
            try testing.expect(queue.tryPop().?.key.isChar('C'));
            try testing.expect(queue.tryPop().?.key.isChar('D'));
        }

        test "unit: EventQueue: event filtering" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 10);
            defer queue.deinit();
            
            // Push mixed events
            try queue.push(createTestEvent('A'));
            try queue.push(createSpecialKeyEvent(.enter));
            try queue.push(createTestEvent('B'));
            
            // Filter for special keys only
            const filter = EventQueue.EventFilter{
                .type_mask = .{
                    .key = true,
                    .mouse = false,
                    .resize = false,
                    .focus = false,
                    .paste = false,
                    .custom = false,
                },
                .callback = struct {
                    fn accept(event: Event) bool {
                        return switch (event) {
                            .key => |k| k.code == .special,
                            else => false,
                        };
                    }
                }.accept,
            };
            
            const special = queue.popFiltered(filter);
            try testing.expect(special != null);
            try testing.expect(special.?.key.code.special == .enter);
        }

        test "unit: EventQueue: thread safety" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 100);
            defer queue.deinit();
            
            // Spawn producer thread
            const producer = try std.Thread.spawn(.{}, struct {
                fn produce(q: *EventQueue) void {
                    var i: u8 = 0;
                    while (i < 50) : (i += 1) {
                        q.push(createTestEvent('A' + i)) catch break;
                        std.time.sleep(100);
                    }
                }
            }.produce, .{&queue});
            
            // Spawn consumer thread
            const consumer = try std.Thread.spawn(.{}, struct {
                fn consume(q: *EventQueue) void {
                    var count: u32 = 0;
                    while (count < 50) {
                        if (q.tryPop()) |_| {
                            count += 1;
                        }
                        std.time.sleep(100);
                    }
                }
            }.consume, .{&queue});
            
            producer.join();
            consumer.join();
            
            // Should complete without deadlock or crash
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Event Loop Tests ────────────────────────────┐

        test "unit: EventLoop: initialization" {
            const allocator = testing.allocator;
            var loop = try EventLoop.init(allocator, .{});
            defer loop.deinit();
            
            try testing.expectEqual(EventLoop.LoopState.stopped, loop.state);
            try testing.expect(loop.handlers.items.len == 0);
            try testing.expect(loop.timers.items.len == 0);
        }

        test "unit: EventLoop: handler registration" {
            const allocator = testing.allocator;
            var loop = try EventLoop.init(allocator, .{});
            defer loop.deinit();
            
            var handler_called = false;
            
            try loop.addHandler(
                .{ .type_mask = EventQueue.EventFilter.EventTypeMask.all() },
                struct {
                    fn handle(event: Event, context: *anyopaque) void {
                        _ = event;
                        const called = @ptrCast(*bool, @alignCast(@alignOf(bool), context));
                        called.* = true;
                    }
                }.handle,
                &handler_called,
            );
            
            try testing.expect(loop.handlers.items.len == 1);
        }

        test "unit: EventLoop: timer management" {
            const allocator = testing.allocator;
            var loop = try EventLoop.init(allocator, .{});
            defer loop.deinit();
            
            var timer_fired = false;
            
            const timer_id = try loop.addTimer(
                100, // 100ms
                false, // Don't repeat
                struct {
                    fn fire(id: u32, context: *anyopaque) void {
                        _ = id;
                        const fired = @ptrCast(*bool, @alignCast(@alignOf(bool), context));
                        fired.* = true;
                    }
                }.fire,
                &timer_fired,
            );
            
            try testing.expect(loop.timers.items.len == 1);
            
            // Remove timer
            loop.removeTimer(timer_id);
            
            // Timer should be marked inactive
            try testing.expect(!loop.timers.items[0].active);
        }

        test "unit: EventLoop: step processing" {
            const allocator = testing.allocator;
            var loop = try EventLoop.init(allocator, .{});
            defer loop.deinit();
            
            var event_handled = false;
            
            try loop.addHandler(
                .{ .type_mask = EventQueue.EventFilter.EventTypeMask.all() },
                struct {
                    fn handle(event: Event, context: *anyopaque) void {
                        _ = event;
                        const handled = @ptrCast(*bool, @alignCast(@alignOf(bool), context));
                        handled.* = true;
                    }
                }.handle,
                &event_handled,
            );
            
            // Push event manually
            try loop.queue.push(createTestEvent('X'));
            
            // Process one step
            const processed = try loop.step();
            try testing.expect(processed);
            try testing.expect(event_handled);
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Key Mapping Tests ────────────────────────────┐

        test "unit: KeyMapper: single key mapping" {
            const allocator = testing.allocator;
            var mapper = try KeyMapper.init(allocator);
            defer mapper.deinit();
            
            // Map a key
            try mapper.map("j", .{
                .id = "move_down",
                .description = "Move down",
                .category = "navigation",
                .callback = null,
            }, .normal);
            
            // Process key
            const key = KeyEvent{
                .code = .{ .char = 'j' },
                .modifiers = KeyModifiers.none(),
                .timestamp = std.time.milliTimestamp(),
            };
            
            const action = try mapper.processKey(key);
            try testing.expect(action != null);
            try testing.expectEqualStrings("move_down", action.?.id);
        }

        test "unit: KeyMapper: key sequence mapping" {
            const allocator = testing.allocator;
            var mapper = try KeyMapper.init(allocator);
            defer mapper.deinit();
            
            // Map a sequence
            try mapper.map("g g", .{
                .id = "go_to_top",
                .description = "Go to top",
                .category = "navigation",
                .callback = null,
            }, .normal);
            
            // Process first key
            const g1 = KeyEvent{
                .code = .{ .char = 'g' },
                .modifiers = KeyModifiers.none(),
                .timestamp = std.time.milliTimestamp(),
            };
            
            var action = try mapper.processKey(g1);
            try testing.expect(action == null); // Partial match
            
            // Process second key
            const g2 = KeyEvent{
                .code = .{ .char = 'g' },
                .modifiers = KeyModifiers.none(),
                .timestamp = std.time.milliTimestamp() + 100,
            };
            
            action = try mapper.processKey(g2);
            try testing.expect(action != null);
            try testing.expectEqualStrings("go_to_top", action.?.id);
        }

        test "unit: KeyMapper: modifier keys" {
            const allocator = testing.allocator;
            var mapper = try KeyMapper.init(allocator);
            defer mapper.deinit();
            
            // Map Ctrl+S
            try mapper.map("Ctrl+S", .{
                .id = "save",
                .description = "Save file",
                .category = "file",
                .callback = null,
            }, .custom);
            
            // Process Ctrl+S
            const ctrl_s = KeyEvent{
                .code = .{ .char = 's' },
                .modifiers = .{ .ctrl = true },
                .timestamp = std.time.milliTimestamp(),
            };
            
            mapper.mode = .custom;
            const action = try mapper.processKey(ctrl_s);
            try testing.expect(action != null);
            try testing.expectEqualStrings("save", action.?.id);
        }

        test "unit: KeyMapper: conflict detection" {
            const allocator = testing.allocator;
            var mapper = try KeyMapper.init(allocator);
            defer mapper.deinit();
            
            // Map a key
            try mapper.map("a", .{
                .id = "action1",
                .description = "Action 1",
                .category = "test",
                .callback = null,
            }, .normal);
            
            // Try to map same key - should conflict
            try testing.expectError(
                error.MappingConflict,
                mapper.map("a", .{
                    .id = "action2",
                    .description = "Action 2",
                    .category = "test",
                    .callback = null,
                }, .normal)
            );
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Integration Tests ────────────────────────────┐

        test "integration: Event: complete input pipeline" {
            const allocator = testing.allocator;
            
            // Create components
            var queue = try EventQueue.init(allocator, 10);
            defer queue.deinit();
            
            var reader = KeyboardReader.init();
            var mapper = try KeyMapper.init(allocator);
            defer mapper.deinit();
            
            // Map some keys
            try mapper.map("q", .{
                .id = "quit",
                .description = "Quit",
                .category = "app",
                .callback = null,
            }, .normal);
            
            // Simulate input
            reader.buffer = "q".*;
            reader.buffer_len = 1;
            reader.buffer_pos = 0;
            
            // Parse key
            const key_event = try reader.parseNext();
            try testing.expect(key_event != null);
            
            // Process through mapper
            const action = try mapper.processKey(key_event.?);
            try testing.expect(action != null);
            try testing.expectEqualStrings("quit", action.?.id);
            
            // Push to queue
            try queue.push(.{ .key = key_event.? });
            
            // Pop from queue
            const event = queue.tryPop();
            try testing.expect(event != null);
            try testing.expect(event.?.key.isChar('q'));
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Performance Tests ────────────────────────────┐

        test "performance: Event: key parsing speed" {
            var reader = KeyboardReader.init();
            
            const iterations = 10000;
            const start = std.time.nanoTimestamp();
            
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                reader.buffer[0] = @intCast(u8, 'A' + (i % 26));
                reader.buffer_len = 1;
                reader.buffer_pos = 0;
                
                _ = try reader.parseNext();
            }
            
            const elapsed = std.time.nanoTimestamp() - start;
            const avg_ns = @divFloor(elapsed, iterations);
            
            // Should parse keys in less than 100ns
            try testing.expect(avg_ns < 100);
        }

        test "performance: Event: queue operations" {
            const allocator = testing.allocator;
            var queue = try EventQueue.init(allocator, 1000);
            defer queue.deinit();
            
            const iterations = 10000;
            const start = std.time.nanoTimestamp();
            
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                try queue.push(createTestEvent(@intCast(u21, 'A' + (i % 26))));
                _ = queue.tryPop();
            }
            
            const elapsed = std.time.nanoTimestamp() - start;
            const avg_ns = @divFloor(elapsed, iterations * 2); // Push + pop
            
            // Should handle queue operations in less than 1μs
            try testing.expect(avg_ns < 1000);
        }

    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Test all input parsing scenarios
- Test queue thread safety
- Test event loop lifecycle
- Test key mapping conflicts
- Test performance targets
- Mock input sources
- Test timeout behavior

## Estimated Time
3 hours

## Priority
🟡 High - Quality assurance

## Category
Testing