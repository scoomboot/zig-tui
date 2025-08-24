// keyboard.test.zig — Comprehensive tests for keyboard input handling
//
// repo   : https://github.com/fisty/zig-tui
// author : https://github.com/fisty
//
// Tests for keyboard event processing, key mapping, and modifiers.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Keyboard = @import("keyboard.zig");
    const KeyEvent = Keyboard.KeyEvent;
    const Key = Keyboard.Key;
    const Modifiers = Keyboard.Modifiers;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test constants
    const ESC_SEQUENCE_TIMEOUT_MS = 50;
    const MAX_KEY_SEQUENCE_LENGTH = 10;
    
    // Common key sequences
    const KeySequences = struct {
        const ARROW_UP = "\x1b[A";
        const ARROW_DOWN = "\x1b[B";
        const ARROW_RIGHT = "\x1b[C";
        const ARROW_LEFT = "\x1b[D";
        
        const F1 = "\x1bOP";
        const F2 = "\x1bOQ";
        const F3 = "\x1bOR";
        const F4 = "\x1bOS";
        
        const HOME = "\x1b[H";
        const END = "\x1b[F";
        const PAGE_UP = "\x1b[5~";
        const PAGE_DOWN = "\x1b[6~";
        const INSERT = "\x1b[2~";
        const DELETE = "\x1b[3~";
        
        const CTRL_C = "\x03";
        const CTRL_D = "\x04";
        const CTRL_Z = "\x1a";
        
        const ALT_A = "\x1ba";
        const ALT_ARROW_UP = "\x1b\x1b[A";
    };
    
    // Test helpers
    fn createKeyEvent(key: Key, modifiers: Modifiers) KeyEvent {
        return KeyEvent{
            .key = key,
            .modifiers = modifiers,
            .timestamp = std.time.milliTimestamp(),
        };
    }
    
    fn parseKeySequence(sequence: []const u8) !KeyEvent {
        var parser = Keyboard.Parser.init();
        return try parser.parse(sequence);
    }
    
    fn isModifierKey(key: Key) bool {
        return switch (key) {
            .shift, .ctrl, .alt, .super => true,
            else => false,
        };
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐
    
        test "unit: KeyEvent: creates with correct values" {
            const event = createKeyEvent(.{ .char = 'A' }, .{ .ctrl = true, .shift = false, .alt = false });
            
            try testing.expectEqual(Key{ .char = 'A' }, event.key);
            try testing.expect(event.modifiers.ctrl);
            try testing.expect(!event.modifiers.shift);
            try testing.expect(!event.modifiers.alt);
        }
        
        test "unit: Key: handles ASCII characters" {
            const keys = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
            
            for (keys) |char| {
                const key = Key{ .char = char };
                try testing.expectEqual(char, key.char);
                try testing.expect(key.isChar());
                try testing.expect(!key.isSpecial());
            }
        }
        
        test "unit: Key: handles special keys" {
            const special_keys = [_]Key{
                .enter,
                .tab,
                .backspace,
                .escape,
                .space,
                .arrow_up,
                .arrow_down,
                .arrow_left,
                .arrow_right,
                .f1,
                .f12,
            };
            
            for (special_keys) |key| {
                try testing.expect(key.isSpecial());
                try testing.expect(!key.isChar());
            }
        }
        
        test "unit: Modifiers: combines correctly" {
            var mods = Modifiers{
                .ctrl = false,
                .shift = false,
                .alt = false,
            };
            
            mods.ctrl = true;
            try testing.expect(mods.ctrl);
            
            mods.shift = true;
            try testing.expect(mods.ctrl and mods.shift);
            
            mods.alt = true;
            try testing.expect(mods.ctrl and mods.shift and mods.alt);
            
            // Check hasAny
            try testing.expect(mods.hasAny());
            
            // Clear all
            mods = .{};
            try testing.expect(!mods.hasAny());
        }
        
        test "unit: Parser: parses single characters" {
            var parser = Keyboard.Parser.init();
            
            const event_a = try parser.parse("a");
            try testing.expectEqual(Key{ .char = 'a' }, event_a.key);
            try testing.expect(!event_a.modifiers.hasAny());
            
            const event_Z = try parser.parse("Z");
            try testing.expectEqual(Key{ .char = 'Z' }, event_Z.key);
            
            const event_1 = try parser.parse("1");
            try testing.expectEqual(Key{ .char = '1' }, event_1.key);
        }
        
        test "unit: Parser: parses control characters" {
            var parser = Keyboard.Parser.init();
            
            // Ctrl+C
            const ctrl_c = try parser.parse(KeySequences.CTRL_C);
            try testing.expectEqual(Key{ .char = 'C' }, ctrl_c.key);
            try testing.expect(ctrl_c.modifiers.ctrl);
            
            // Ctrl+D
            const ctrl_d = try parser.parse(KeySequences.CTRL_D);
            try testing.expectEqual(Key{ .char = 'D' }, ctrl_d.key);
            try testing.expect(ctrl_d.modifiers.ctrl);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: Parser with escape sequences: arrow keys" {
            var parser = Keyboard.Parser.init();
            
            const up = try parser.parse(KeySequences.ARROW_UP);
            try testing.expectEqual(Key.arrow_up, up.key);
            
            const down = try parser.parse(KeySequences.ARROW_DOWN);
            try testing.expectEqual(Key.arrow_down, down.key);
            
            const left = try parser.parse(KeySequences.ARROW_LEFT);
            try testing.expectEqual(Key.arrow_left, left.key);
            
            const right = try parser.parse(KeySequences.ARROW_RIGHT);
            try testing.expectEqual(Key.arrow_right, right.key);
        }
        
        test "integration: Parser with function keys: F1-F4" {
            var parser = Keyboard.Parser.init();
            
            const f1 = try parser.parse(KeySequences.F1);
            try testing.expectEqual(Key.f1, f1.key);
            
            const f2 = try parser.parse(KeySequences.F2);
            try testing.expectEqual(Key.f2, f2.key);
            
            const f3 = try parser.parse(KeySequences.F3);
            try testing.expectEqual(Key.f3, f3.key);
            
            const f4 = try parser.parse(KeySequences.F4);
            try testing.expectEqual(Key.f4, f4.key);
        }
        
        test "integration: Parser with Alt modifier: Alt+key combinations" {
            var parser = Keyboard.Parser.init();
            
            const alt_a = try parser.parse(KeySequences.ALT_A);
            try testing.expectEqual(Key{ .char = 'a' }, alt_a.key);
            try testing.expect(alt_a.modifiers.alt);
            
            const alt_arrow = try parser.parse(KeySequences.ALT_ARROW_UP);
            try testing.expectEqual(Key.arrow_up, alt_arrow.key);
            try testing.expect(alt_arrow.modifiers.alt);
        }
        
        test "integration: Key mapping: translates keycodes" {
            const allocator = testing.allocator;
            var mapper = try Keyboard.KeyMapper.init(allocator);
            defer mapper.deinit();
            
            // Map custom sequences
            try mapper.addMapping("\x1b[15~", Key.f5);
            try mapper.addMapping("\x1b[17~", Key.f6);
            
            const f5 = try mapper.translate("\x1b[15~");
            try testing.expectEqual(Key.f5, f5);
            
            const f6 = try mapper.translate("\x1b[17~");
            try testing.expectEqual(Key.f6, f6);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── E2E Tests ────────────────────────────┐
    
        test "e2e: complete input sequence: user typing" {
            const allocator = testing.allocator;
            var parser = Keyboard.Parser.init();
            
            // Simulate user typing "Hello" with Enter
            const input_sequence = "Hello\r";
            var events = std.ArrayList(KeyEvent).init(allocator);
            defer events.deinit();
            
            for (input_sequence) |char| {
                const seq = [_]u8{char};
                const event = try parser.parse(&seq);
                try events.append(event);
            }
            
            // Verify sequence
            try testing.expectEqual(@as(usize, 6), events.items.len);
            try testing.expectEqual(Key{ .char = 'H' }, events.items[0].key);
            try testing.expectEqual(Key{ .char = 'e' }, events.items[1].key);
            try testing.expectEqual(Key{ .char = 'l' }, events.items[2].key);
            try testing.expectEqual(Key{ .char = 'l' }, events.items[3].key);
            try testing.expectEqual(Key{ .char = 'o' }, events.items[4].key);
            try testing.expectEqual(Key.enter, events.items[5].key);
        }
        
        test "e2e: navigation sequence: cursor movement" {
            const allocator = testing.allocator;
            var parser = Keyboard.Parser.init();
            
            // Simulate navigation: Home, Right, Right, End
            const sequences = [_][]const u8{
                KeySequences.HOME,
                KeySequences.ARROW_RIGHT,
                KeySequences.ARROW_RIGHT,
                KeySequences.END,
            };
            
            var events = std.ArrayList(KeyEvent).init(allocator);
            defer events.deinit();
            
            for (sequences) |seq| {
                const event = try parser.parse(seq);
                try events.append(event);
            }
            
            // Verify navigation
            try testing.expectEqual(Key.home, events.items[0].key);
            try testing.expectEqual(Key.arrow_right, events.items[1].key);
            try testing.expectEqual(Key.arrow_right, events.items[2].key);
            try testing.expectEqual(Key.end, events.items[3].key);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: Parser: processes many keys quickly" {
            var parser = Keyboard.Parser.init();
            
            const iterations = 100000;
            const start = std.time.milliTimestamp();
            
            for (0..iterations) |i| {
                const char = @as(u8, @intCast((i % 94) + 33)); // Printable ASCII
                const seq = [_]u8{char};
                _ = try parser.parse(&seq);
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should parse 100k keys quickly
            try testing.expect(elapsed < 100);
        }
        
        test "performance: Escape sequence parsing: handles complex sequences" {
            var parser = Keyboard.Parser.init();
            
            const sequences = [_][]const u8{
                KeySequences.ARROW_UP,
                KeySequences.ARROW_DOWN,
                KeySequences.F1,
                KeySequences.PAGE_UP,
                KeySequences.ALT_ARROW_UP,
            };
            
            const iterations = 10000;
            const start = std.time.milliTimestamp();
            
            for (0..iterations) |i| {
                const seq = sequences[i % sequences.len];
                _ = try parser.parse(seq);
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should parse 10k escape sequences quickly
            try testing.expect(elapsed < 100);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Stress Tests ────────────────────────────┐
    
        test "stress: Parser: handles all ASCII characters" {
            var parser = Keyboard.Parser.init();
            
            // Test all ASCII characters
            for (0..128) |i| {
                const char = @as(u8, @intCast(i));
                const seq = [_]u8{char};
                
                const result = parser.parse(&seq);
                if (result) |event| {
                    // Printable characters should parse
                    if (char >= 32 and char <= 126) {
                        try testing.expectEqual(Key{ .char = char }, event.key);
                    }
                } else |_| {
                    // Control characters might fail
                    try testing.expect(char < 32 or char == 127);
                }
            }
        }
        
        test "stress: Parser: handles malformed sequences" {
            var parser = Keyboard.Parser.init();
            
            // Test various malformed sequences
            const malformed = [_][]const u8{
                "\x1b[",      // Incomplete escape
                "\x1b[999",   // Invalid number
                "\x1b]",      // Wrong bracket
                "\x1b\x1b\x1b", // Multiple escapes
                "\x1b[A[B",   // Mixed sequences
            };
            
            for (malformed) |seq| {
                // Should either parse partially or return error
                _ = parser.parse(seq) catch |err| {
                    try testing.expect(err == Keyboard.Error.InvalidSequence or
                                     err == Keyboard.Error.IncompleteSequence);
                };
            }
        }
        
        test "stress: KeyMapper: handles many mappings" {
            const allocator = testing.allocator;
            var mapper = try Keyboard.KeyMapper.init(allocator);
            defer mapper.deinit();
            
            // Add many custom mappings
            for (0..1000) |i| {
                var seq_buf: [10]u8 = undefined;
                const seq = try std.fmt.bufPrint(&seq_buf, "\x1b[{d}~", .{i});
                const key = Key{ .custom = @intCast(i) };
                try mapper.addMapping(seq, key);
            }
            
            // Verify mappings work
            for (0..1000) |i| {
                var seq_buf: [10]u8 = undefined;
                const seq = try std.fmt.bufPrint(&seq_buf, "\x1b[{d}~", .{i});
                const key = try mapper.translate(seq);
                try testing.expectEqual(@as(u32, @intCast(i)), key.custom);
            }
        }
    
    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝