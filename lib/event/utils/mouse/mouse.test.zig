// mouse.test.zig — Comprehensive tests for mouse input handling
//
// repo   : https://github.com/fisty/zig-tui
// author : https://github.com/fisty
//
// Tests for mouse event processing, button detection, and movement tracking.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Mouse = @import("mouse.zig");
    const MouseEvent = Mouse.MouseEvent;
    const Button = Mouse.Button;
    const EventType = Mouse.EventType;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test constants
    const MAX_SCREEN_X = 1920;
    const MAX_SCREEN_Y = 1080;
    const DOUBLE_CLICK_TIMEOUT_MS = 500;
    const DRAG_THRESHOLD_PIXELS = 3;
    
    // Mouse protocol sequences
    const MouseProtocol = struct {
        // X10 protocol: \x1b[M<button><x+32><y+32>
        // SGR protocol: \x1b[<button>;<x>;<y>M (press) or m (release)
        
        const X10_PREFIX = "\x1b[M";
        const SGR_PREFIX = "\x1b[<";
        
        fn encodeX10(button: u8, x: u16, y: u16) [6]u8 {
            return [_]u8{
                0x1b, '[', 'M',
                button + 32,
                @intCast((x + 1) + 32),
                @intCast((y + 1) + 32),
            };
        }
        
        fn encodeSGR(button: u8, x: u16, y: u16, release: bool) []u8 {
            var buf: [32]u8 = undefined;
            const suffix = if (release) "m" else "M";
            const len = std.fmt.bufPrint(&buf, "\x1b[<{d};{d};{d}{s}", .{
                button,
                x + 1,
                y + 1,
                suffix,
            }) catch unreachable;
            return buf[0..len];
        }
    };
    
    // Test helpers
    fn createMouseEvent(x: u16, y: u16, button: Button, event_type: EventType) MouseEvent {
        return MouseEvent{
            .x = x,
            .y = y,
            .button = button,
            .event_type = event_type,
            .modifiers = .{},
            .timestamp = std.time.milliTimestamp(),
        };
    }
    
    fn createClickEvent(x: u16, y: u16, button: Button) MouseEvent {
        return createMouseEvent(x, y, button, .click);
    }
    
    fn createMoveEvent(x: u16, y: u16) MouseEvent {
        return createMouseEvent(x, y, .none, .move);
    }
    
    fn createDragEvent(x: u16, y: u16, button: Button) MouseEvent {
        return createMouseEvent(x, y, button, .drag);
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐
    
        test "unit: MouseEvent: creates with correct values" {
            const event = createClickEvent(100, 200, .left);
            
            try testing.expectEqual(@as(u16, 100), event.x);
            try testing.expectEqual(@as(u16, 200), event.y);
            try testing.expectEqual(Button.left, event.button);
            try testing.expectEqual(EventType.click, event.event_type);
        }
        
        test "unit: Button: identifies all button types" {
            const buttons = [_]Button{
                .none,
                .left,
                .middle,
                .right,
                .scroll_up,
                .scroll_down,
            };
            
            for (buttons, 0..) |button, i| {
                try testing.expectEqual(@as(usize, i), @intFromEnum(button));
            }
        }
        
        test "unit: EventType: identifies all event types" {
            const types = [_]EventType{
                .press,
                .release,
                .click,
                .double_click,
                .move,
                .drag,
                .scroll,
            };
            
            for (types) |event_type| {
                const event = MouseEvent{
                    .x = 0,
                    .y = 0,
                    .button = .none,
                    .event_type = event_type,
                    .modifiers = .{},
                    .timestamp = 0,
                };
                
                try testing.expectEqual(event_type, event.event_type);
            }
        }
        
        test "unit: Parser: parses X10 protocol" {
            var parser = Mouse.Parser.init();
            
            // Left button click at (10, 20)
            const seq = MouseProtocol.encodeX10(0, 10, 20);
            const event = try parser.parseX10(&seq);
            
            try testing.expectEqual(@as(u16, 10), event.x);
            try testing.expectEqual(@as(u16, 20), event.y);
            try testing.expectEqual(Button.left, event.button);
        }
        
        test "unit: Parser: parses SGR protocol" {
            const allocator = testing.allocator;
            var parser = Mouse.Parser.init();
            
            // Right button press at (100, 50)
            const press_seq = MouseProtocol.encodeSGR(2, 100, 50, false);
            const press_owned = try allocator.dupe(u8, press_seq);
            defer allocator.free(press_owned);
            
            const press_event = try parser.parseSGR(press_owned);
            
            try testing.expectEqual(@as(u16, 100), press_event.x);
            try testing.expectEqual(@as(u16, 50), press_event.y);
            try testing.expectEqual(Button.right, press_event.button);
            try testing.expectEqual(EventType.press, press_event.event_type);
        }
        
        test "unit: MouseEvent: detects position changes" {
            const event1 = createMoveEvent(100, 100);
            const event2 = createMoveEvent(150, 100);
            const event3 = createMoveEvent(100, 100);
            
            try testing.expect(event1.positionChanged(event2));
            try testing.expect(!event1.positionChanged(event3));
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: Double click detection: timing based" {
            const allocator = testing.allocator;
            var detector = try Mouse.DoubleClickDetector.init(allocator);
            defer detector.deinit();
            
            const now = std.time.milliTimestamp();
            
            // First click
            const click1 = MouseEvent{
                .x = 100,
                .y = 100,
                .button = .left,
                .event_type = .click,
                .modifiers = .{},
                .timestamp = now,
            };
            
            try testing.expect(!detector.isDoubleClick(click1));
            
            // Second click within timeout
            const click2 = MouseEvent{
                .x = 100,
                .y = 100,
                .button = .left,
                .event_type = .click,
                .modifiers = .{},
                .timestamp = now + 200, // 200ms later
            };
            
            try testing.expect(detector.isDoubleClick(click2));
            
            // Third click after timeout
            const click3 = MouseEvent{
                .x = 100,
                .y = 100,
                .button = .left,
                .event_type = .click,
                .modifiers = .{},
                .timestamp = now + 1000, // 1s later
            };
            
            try testing.expect(!detector.isDoubleClick(click3));
        }
        
        test "integration: Drag detection: movement with button" {
            var tracker = Mouse.DragTracker.init();
            
            // Press button
            const press = createMouseEvent(100, 100, .left, .press);
            tracker.handleEvent(press);
            try testing.expect(!tracker.isDragging());
            
            // Move without reaching threshold
            const small_move = createMouseEvent(101, 101, .left, .move);
            tracker.handleEvent(small_move);
            try testing.expect(!tracker.isDragging());
            
            // Move beyond threshold
            const drag_move = createMouseEvent(110, 110, .left, .move);
            tracker.handleEvent(drag_move);
            try testing.expect(tracker.isDragging());
            
            // Release button
            const release = createMouseEvent(110, 110, .left, .release);
            tracker.handleEvent(release);
            try testing.expect(!tracker.isDragging());
        }
        
        test "integration: Scroll handling: detects scroll events" {
            var parser = Mouse.Parser.init();
            
            // Scroll up
            const scroll_up = MouseProtocol.encodeX10(64, 50, 50); // Button 64 = scroll up
            const up_event = try parser.parseX10(&scroll_up);
            try testing.expectEqual(Button.scroll_up, up_event.button);
            try testing.expectEqual(EventType.scroll, up_event.event_type);
            
            // Scroll down
            const scroll_down = MouseProtocol.encodeX10(65, 50, 50); // Button 65 = scroll down
            const down_event = try parser.parseX10(&scroll_down);
            try testing.expectEqual(Button.scroll_down, down_event.button);
            try testing.expectEqual(EventType.scroll, down_event.event_type);
        }
        
        test "integration: Mouse with modifiers: Ctrl/Alt/Shift" {
            var parser = Mouse.Parser.init();
            
            // Ctrl + Left click (button code includes modifier)
            const ctrl_click = MouseProtocol.encodeX10(16, 100, 100); // 16 = Ctrl + Left
            const ctrl_event = try parser.parseX10(&ctrl_click);
            
            try testing.expectEqual(Button.left, ctrl_event.button);
            try testing.expect(ctrl_event.modifiers.ctrl);
            
            // Shift + Right click
            const shift_click = MouseProtocol.encodeX10(6, 100, 100); // 6 = Shift + Right
            const shift_event = try parser.parseX10(&shift_click);
            
            try testing.expectEqual(Button.right, shift_event.button);
            try testing.expect(shift_event.modifiers.shift);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── E2E Tests ────────────────────────────┐
    
        test "e2e: complete mouse interaction: click and drag" {
            const allocator = testing.allocator;
            var tracker = Mouse.InteractionTracker.init(allocator);
            defer tracker.deinit();
            
            // User clicks
            const click = createClickEvent(200, 150, .left);
            try tracker.handleEvent(click);
            
            // User presses for drag
            const press = createMouseEvent(300, 200, .left, .press);
            try tracker.handleEvent(press);
            
            // User drags
            const positions = [_][2]u16{
                .{ 310, 210 },
                .{ 320, 220 },
                .{ 350, 250 },
                .{ 400, 300 },
            };
            
            for (positions) |pos| {
                const drag = createDragEvent(pos[0], pos[1], .left);
                try tracker.handleEvent(drag);
            }
            
            // User releases
            const release = createMouseEvent(400, 300, .left, .release);
            try tracker.handleEvent(release);
            
            // Verify drag distance
            const drag_distance = tracker.getDragDistance();
            try testing.expect(drag_distance > 100);
            
            // Verify interaction count
            try testing.expectEqual(@as(u32, 7), tracker.getEventCount());
        }
        
        test "e2e: mouse selection: text selection simulation" {
            const allocator = testing.allocator;
            
            // Simulate text selection
            var selection = Mouse.SelectionTracker.init(allocator);
            defer selection.deinit();
            
            // Start selection at character position
            const start_pos = MouseEvent{
                .x = 100,
                .y = 50,
                .button = .left,
                .event_type = .press,
                .modifiers = .{},
                .timestamp = std.time.milliTimestamp(),
            };
            
            try selection.startSelection(start_pos);
            try testing.expect(selection.isSelecting());
            
            // Drag to select text
            const drag_positions = [_][2]u16{
                .{ 150, 50 },
                .{ 200, 50 },
                .{ 250, 50 },
                .{ 300, 50 },
            };
            
            for (drag_positions) |pos| {
                const drag = createDragEvent(pos[0], pos[1], .left);
                try selection.updateSelection(drag);
            }
            
            // End selection
            const end_pos = createMouseEvent(300, 50, .left, .release);
            try selection.endSelection(end_pos);
            
            // Verify selection bounds
            const bounds = selection.getSelectionBounds();
            try testing.expectEqual(@as(u16, 100), bounds.start_x);
            try testing.expectEqual(@as(u16, 300), bounds.end_x);
            try testing.expectEqual(@as(u16, 50), bounds.start_y);
            try testing.expectEqual(@as(u16, 50), bounds.end_y);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: Parser: processes many events quickly" {
            var parser = Mouse.Parser.init();
            
            const iterations = 100000;
            var prng = std.rand.DefaultPrng.init(77777);
            const random = prng.random();
            
            const start = std.time.milliTimestamp();
            
            for (0..iterations) |_| {
                const x = random.intRangeLessThan(u16, 0, 200);
                const y = random.intRangeLessThan(u16, 0, 100);
                const button = random.intRangeLessThan(u8, 0, 3);
                
                const seq = MouseProtocol.encodeX10(button, x, y);
                _ = try parser.parseX10(&seq);
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should parse 100k events quickly
            try testing.expect(elapsed < 100);
        }
        
        test "performance: Movement tracking: handles rapid updates" {
            var tracker = Mouse.MovementTracker.init();
            
            const iterations = 10000;
            var prng = std.rand.DefaultPrng.init(88888);
            const random = prng.random();
            
            const start = std.time.milliTimestamp();
            
            for (0..iterations) |_| {
                const x = random.intRangeLessThan(u16, 0, MAX_SCREEN_X);
                const y = random.intRangeLessThan(u16, 0, MAX_SCREEN_Y);
                
                const move_event = createMoveEvent(x, y);
                tracker.update(move_event);
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should track 10k movements quickly
            try testing.expect(elapsed < 50);
            
            // Verify tracking worked
            const total_distance = tracker.getTotalDistance();
            try testing.expect(total_distance > 0);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Stress Tests ────────────────────────────┐
    
        test "stress: Parser: handles all button combinations" {
            var parser = Mouse.Parser.init();
            
            // Test all button codes (0-127 typically)
            for (0..128) |button_code| {
                const seq = MouseProtocol.encodeX10(@intCast(button_code), 50, 50);
                
                const result = parser.parseX10(&seq);
                if (result) |event| {
                    // Should parse successfully
                    try testing.expect(event.x == 50);
                    try testing.expect(event.y == 50);
                } else |_| {
                    // Some codes might be invalid
                    try testing.expect(button_code > 127);
                }
            }
        }
        
        test "stress: Coordinates: handles extreme positions" {
            var parser = Mouse.Parser.init();
            
            // Test boundary coordinates
            const test_coords = [_][2]u16{
                .{ 0, 0 },       // Top-left
                .{ MAX_SCREEN_X - 1, 0 }, // Top-right
                .{ 0, MAX_SCREEN_Y - 1 }, // Bottom-left
                .{ MAX_SCREEN_X - 1, MAX_SCREEN_Y - 1 }, // Bottom-right
                .{ MAX_SCREEN_X / 2, MAX_SCREEN_Y / 2 }, // Center
            };
            
            for (test_coords) |coord| {
                const event = createMoveEvent(coord[0], coord[1]);
                
                try testing.expectEqual(coord[0], event.x);
                try testing.expectEqual(coord[1], event.y);
                
                // Verify within bounds
                try testing.expect(event.x < MAX_SCREEN_X);
                try testing.expect(event.y < MAX_SCREEN_Y);
            }
        }
        
        test "stress: Event storm: handles rapid mixed events" {
            const allocator = testing.allocator;
            var processor = Mouse.EventProcessor.init(allocator);
            defer processor.deinit();
            
            var prng = std.rand.DefaultPrng.init(99999);
            const random = prng.random();
            
            // Generate storm of events
            for (0..10000) |_| {
                const event_type = random.intRangeLessThan(u8, 0, 7);
                const x = random.intRangeLessThan(u16, 0, 1000);
                const y = random.intRangeLessThan(u16, 0, 1000);
                const button = random.intRangeLessThan(u8, 0, 6);
                
                const event = MouseEvent{
                    .x = x,
                    .y = y,
                    .button = @enumFromInt(button),
                    .event_type = @enumFromInt(event_type),
                    .modifiers = .{
                        .ctrl = random.boolean(),
                        .shift = random.boolean(),
                        .alt = random.boolean(),
                    },
                    .timestamp = std.time.milliTimestamp(),
                };
                
                try processor.processEvent(event);
            }
            
            // Processor should remain stable
            const stats = processor.getStatistics();
            try testing.expectEqual(@as(u32, 10000), stats.total_events);
        }
    
    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝