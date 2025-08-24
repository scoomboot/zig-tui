// windows_console.test.zig — Tests for Windows Console API bindings
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://fisty.github.io/zig-tui/terminal/windows_console
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔════════════════════════════════════ PACK ════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const builtin = @import("builtin");
    const windows_console = @import("windows_console.zig");
    const ConsoleMode = windows_console.ConsoleMode;
    const EventType = windows_console.EventType;
    const COORD = windows_console.COORD;
    const INPUT_RECORD = windows_console.INPUT_RECORD;
    const WINDOW_BUFFER_SIZE_RECORD = windows_console.WINDOW_BUFFER_SIZE_RECORD;

// ╚════════════════════════════════════════════════════════════════════════════════╝

// ╔════════════════════════════════════ TEST ════════════════════════════════════╗

    // ┌────────────────────────── Unit Tests ──────────────────────────┐
    
        test "unit: COORD: initialization and accessors" {
            const coord = COORD.init(80, 24);
            
            try testing.expectEqual(@as(i16, 80), coord.X);
            try testing.expectEqual(@as(i16, 24), coord.Y);
        }
        
        test "unit: WINDOW_BUFFER_SIZE_RECORD: dimension getters" {
            const record = WINDOW_BUFFER_SIZE_RECORD{
                .dwSize = COORD.init(132, 50),
            };
            
            try testing.expectEqual(@as(u16, 132), record.getWidth());
            try testing.expectEqual(@as(u16, 50), record.getHeight());
        }
        
        test "unit: INPUT_RECORD: resize event detection" {
            // Create a resize event
            var resize_event = INPUT_RECORD{
                .EventType = @intFromEnum(EventType.WINDOW_BUFFER_SIZE_EVENT),
                .Event = .{
                    .WindowBufferSizeEvent = WINDOW_BUFFER_SIZE_RECORD{
                        .dwSize = COORD.init(100, 40),
                    },
                },
            };
            
            try testing.expect(resize_event.isResizeEvent());
            
            const size = resize_event.getResizeSize();
            try testing.expect(size != null);
            try testing.expectEqual(@as(i16, 100), size.?.X);
            try testing.expectEqual(@as(i16, 40), size.?.Y);
            
            // Create a non-resize event
            var key_event = INPUT_RECORD{
                .EventType = @intFromEnum(EventType.KEY_EVENT),
                .Event = .{
                    .KeyEvent = undefined,
                },
            };
            
            try testing.expect(!key_event.isResizeEvent());
            try testing.expect(key_event.getResizeSize() == null);
        }
        
        test "unit: ConsoleMode: flag values" {
            // Verify console mode flags have expected values
            try testing.expectEqual(@as(u32, 0x0008), ConsoleMode.ENABLE_WINDOW_INPUT);
            try testing.expectEqual(@as(u32, 0x0010), ConsoleMode.ENABLE_MOUSE_INPUT);
            try testing.expectEqual(@as(u32, 0x0001), ConsoleMode.ENABLE_PROCESSED_INPUT);
            try testing.expectEqual(@as(u32, 0x0002), ConsoleMode.ENABLE_LINE_INPUT);
            try testing.expectEqual(@as(u32, 0x0004), ConsoleMode.ENABLE_ECHO_INPUT);
            try testing.expectEqual(@as(u32, 0x0080), ConsoleMode.ENABLE_EXTENDED_FLAGS);
            try testing.expectEqual(@as(u32, 0x0040), ConsoleMode.ENABLE_QUICK_EDIT_MODE);
        }
        
        test "unit: EventType: enum values" {
            // Verify event type enum values
            try testing.expectEqual(@as(u16, 0x0001), @intFromEnum(EventType.KEY_EVENT));
            try testing.expectEqual(@as(u16, 0x0002), @intFromEnum(EventType.MOUSE_EVENT));
            try testing.expectEqual(@as(u16, 0x0004), @intFromEnum(EventType.WINDOW_BUFFER_SIZE_EVENT));
            try testing.expectEqual(@as(u16, 0x0008), @intFromEnum(EventType.MENU_EVENT));
            try testing.expectEqual(@as(u16, 0x0010), @intFromEnum(EventType.FOCUS_EVENT));
        }
    
    // └───────────────────────────────────────────────────────────────────┘
    
    // ┌────────────────────────── Integration Tests ──────────────────────────┐
    
        test "integration: Console mode flag combinations" {
            // Test combining console mode flags
            const combined = ConsoleMode.ENABLE_WINDOW_INPUT | 
                           ConsoleMode.ENABLE_MOUSE_INPUT |
                           ConsoleMode.ENABLE_PROCESSED_INPUT;
            
            try testing.expectEqual(@as(u32, 0x0019), combined);
            
            // Test that flags don't overlap
            const all_flags = ConsoleMode.ENABLE_WINDOW_INPUT |
                            ConsoleMode.ENABLE_MOUSE_INPUT |
                            ConsoleMode.ENABLE_PROCESSED_INPUT |
                            ConsoleMode.ENABLE_LINE_INPUT |
                            ConsoleMode.ENABLE_ECHO_INPUT |
                            ConsoleMode.ENABLE_EXTENDED_FLAGS |
                            ConsoleMode.ENABLE_QUICK_EDIT_MODE;
            
            // Each flag should be distinct
            try testing.expect((ConsoleMode.ENABLE_WINDOW_INPUT & ConsoleMode.ENABLE_MOUSE_INPUT) == 0);
            try testing.expect((ConsoleMode.ENABLE_PROCESSED_INPUT & ConsoleMode.ENABLE_LINE_INPUT) == 0);
            
            _ = all_flags;
        }
    
    // └───────────────────────────────────────────────────────────────────┘
    
    // ┌────────────────────────── Platform-Specific Tests ──────────────────────────┐
    
        test "scenario: Windows console API availability" {
            // Skip on non-Windows platforms
            if (builtin.os.tag != .windows) {
                return error.SkipZigTest;
            }
            
            // These tests would only run on Windows
            // They verify that the extern functions are properly linked
            // Note: We can't actually call these without a valid console handle
            
            // Verify function pointers are non-null
            try testing.expect(@intFromPtr(&windows_console.Console.ReadConsoleInputW) != 0);
            try testing.expect(@intFromPtr(&windows_console.Console.PeekConsoleInputW) != 0);
            try testing.expect(@intFromPtr(&windows_console.Console.GetNumberOfConsoleInputEvents) != 0);
            try testing.expect(@intFromPtr(&windows_console.Console.FlushConsoleInputBuffer) != 0);
        }
    
    // └───────────────────────────────────────────────────────────────────┘

// ╚════════════════════════════════════════════════════════════════════════════════╝