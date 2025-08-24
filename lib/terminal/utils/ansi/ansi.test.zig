// ansi.test.zig — Tests for ANSI escape sequence utilities
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const ansi = @import("ansi.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test allocator
    const test_allocator = testing.allocator;
    
    // ┌──────────────────────────── Test Helpers ────────────────────────────┐
    
        /// Helper to create a test builder with pre-allocated buffer
        fn createTestBuilder() !ansi.Ansi {
            return ansi.Ansi.init(test_allocator);
        }
        
        /// Helper to verify sequence matches expected bytes
        fn expectSequenceEquals(expected: []const u8, actual: []const u8) !void {
            if (!std.mem.eql(u8, expected, actual)) {
                std.debug.print("\nExpected: {s}\nActual:   {s}\n", .{ 
                    std.fmt.fmtSliceEscapeLower(expected),
                    std.fmt.fmtSliceEscapeLower(actual)
                });
                return error.TestUnexpectedResult;
            }
        }
        
        /// Helper to measure operation timing
        fn measureNanoseconds(comptime iterations: usize, op: anytype) !u64 {
            var timer = try std.time.Timer.start();
            
            var i: usize = 0;
            while (i < iterations) : (i += 1) {
                try op();
            }
            
            return timer.read() / iterations;
        }
        
        /// Test data for scenario testing
        const TestScenarios = struct {
            pub const prompt_styling = struct {
                pub const user = "user@host";
                pub const path = "/home/user";
                pub const prompt = "$ ";
            };
            
            pub const progress_bar = struct {
                pub const width = 50;
                pub const filled_char = '█';
                pub const empty_char = '░';
            };
            
            pub const text_editor = struct {
                pub const lines = 100;
                pub const columns = 80;
                pub const status_line = 24;
            };
        };
    
    // └──────────────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐
    
        // ── Constants Validation ──
        
        test "unit: Constants: escape sequences are correct" {
            try testing.expectEqualStrings("\x1b", ansi.ESC);
            try testing.expectEqualStrings("\x1b[", ansi.CSI);
            try testing.expectEqualStrings("\x1b]", ansi.OSC);
            try testing.expectEqualStrings("\x1bP", ansi.DCS);
        }

        test "unit: Constants: common sequences are correct" {
            try testing.expectEqualStrings("\x1b[0m", ansi.RESET);
            try testing.expectEqualStrings("\x1b[2J", ansi.CLEAR_SCREEN);
            try testing.expectEqualStrings("\x1b[2K", ansi.CLEAR_LINE);
            try testing.expectEqualStrings("\x1b[?25l", ansi.HIDE_CURSOR);
            try testing.expectEqualStrings("\x1b[?25h", ansi.SHOW_CURSOR);
            try testing.expectEqualStrings("\x1b[?1049h", ansi.ALT_SCREEN);
            try testing.expectEqualStrings("\x1b[?1049l", ansi.MAIN_SCREEN);
        }

        // ── Color System Tests ──

        test "unit: Color: basic color to foreground sequence" {
            var buf: [32]u8 = undefined;
            
            const red = ansi.Color{ .basic = 1 };
            const seq = try red.toFgSequence(&buf);
            try testing.expectEqualStrings("\x1b[31m", seq);
            
            const blue = ansi.Color{ .basic = 4 };
            const seq2 = try blue.toFgSequence(&buf);
            try testing.expectEqualStrings("\x1b[34m", seq2);
        }

        test "unit: Color: basic color to background sequence" {
            var buf: [32]u8 = undefined;
            
            const green = ansi.Color{ .basic = 2 };
            const seq = try green.toBgSequence(&buf);
            try testing.expectEqualStrings("\x1b[42m", seq);
            
            const yellow = ansi.Color{ .basic = 3 };
            const seq2 = try yellow.toBgSequence(&buf);
            try testing.expectEqualStrings("\x1b[43m", seq2);
        }

        test "unit: Color: extended color sequences" {
            var buf: [32]u8 = undefined;
            
            // Standard color (0-7)
            const cyan = ansi.Color{ .extended = 6 };
            const seq1 = try cyan.toFgSequence(&buf);
            try testing.expectEqualStrings("\x1b[36m", seq1);
            
            // Bright color (8-15)
            const bright_red = ansi.Color{ .extended = 9 };
            const seq2 = try bright_red.toFgSequence(&buf);
            try testing.expectEqualStrings("\x1b[91m", seq2);
            
            const bright_green = ansi.Color{ .extended = 10 };
            const seq3 = try bright_green.toBgSequence(&buf);
            try testing.expectEqualStrings("\x1b[102m", seq3);
        }

        test "unit: Color: indexed color sequences" {
            var buf: [32]u8 = undefined;
            
            const orange = ansi.Color{ .indexed = 208 };
            const seq = try orange.toFgSequence(&buf);
            try testing.expectEqualStrings("\x1b[38;5;208m", seq);
            
            const purple = ansi.Color{ .indexed = 93 };
            const seq2 = try purple.toBgSequence(&buf);
            try testing.expectEqualStrings("\x1b[48;5;93m", seq2);
        }

        test "unit: Color: RGB color sequences" {
            var buf: [64]u8 = undefined;
            
            const coral = ansi.Color{ .rgb = .{ .r = 255, .g = 127, .b = 80 } };
            const seq = try coral.toFgSequence(&buf);
            try testing.expectEqualStrings("\x1b[38;2;255;127;80m", seq);
            
            const teal = ansi.Color{ .rgb = .{ .r = 0, .g = 128, .b = 128 } };
            const seq2 = try teal.toBgSequence(&buf);
            try testing.expectEqualStrings("\x1b[48;2;0;128;128m", seq2);
        }
        
        test "unit: Color: edge case with color value 0" {
            var buf: [32]u8 = undefined;
            
            const black = ansi.Color{ .basic = 0 };
            const seq = try black.toFgSequence(&buf);
            try testing.expectEqualStrings("\x1b[30m", seq);
            
            const seq_bg = try black.toBgSequence(&buf);
            try testing.expectEqualStrings("\x1b[40m", seq_bg);
        }
        
        test "unit: Color: edge case with maximum RGB values" {
            var buf: [64]u8 = undefined;
            
            const white = ansi.Color{ .rgb = .{ .r = 255, .g = 255, .b = 255 } };
            const seq = try white.toFgSequence(&buf);
            try testing.expectEqualStrings("\x1b[38;2;255;255;255m", seq);
        }
        
        test "unit: Color: edge case with indexed color boundaries" {
            var buf: [32]u8 = undefined;
            
            // Test minimum indexed color
            const min_color = ansi.Color{ .indexed = 0 };
            const seq_min = try min_color.toFgSequence(&buf);
            try testing.expectEqualStrings("\x1b[38;5;0m", seq_min);
            
            // Test maximum indexed color
            const max_color = ansi.Color{ .indexed = 255 };
            const seq_max = try max_color.toFgSequence(&buf);
            try testing.expectEqualStrings("\x1b[38;5;255m", seq_max);
        }
        
        // ── Style Attributes Tests ──

        test "unit: Style: single style attributes" {
            var buf: [256]u8 = undefined;
            
            const bold = ansi.Style{ .bold = true };
            const seq = try bold.toSequence(&buf);
            try testing.expectEqualStrings("\x1b[1m", seq);
            
            const italic = ansi.Style{ .italic = true };
            const seq2 = try italic.toSequence(&buf);
            try testing.expectEqualStrings("\x1b[3m", seq2);
            
            const underline = ansi.Style{ .underline = true };
            const seq3 = try underline.toSequence(&buf);
            try testing.expectEqualStrings("\x1b[4m", seq3);
        }

        test "unit: Style: multiple style attributes" {
            var buf: [256]u8 = undefined;
            
            const styled = ansi.Style{
                .bold = true,
                .italic = true,
                .underline = true,
            };
            const seq = try styled.toSequence(&buf);
            try testing.expectEqualStrings("\x1b[1m\x1b[3m\x1b[4m", seq);
        }

        test "unit: Style: all style attributes" {
            var buf: [256]u8 = undefined;
            
            const styled = ansi.Style{
                .bold = true,
                .dim = true,
                .italic = true,
                .underline = true,
                .blink = true,
                .reverse = true,
                .hidden = true,
                .strikethrough = true,
            };
            const seq = try styled.toSequence(&buf);
            const expected = "\x1b[1m\x1b[2m\x1b[3m\x1b[4m\x1b[5m\x1b[7m\x1b[8m\x1b[9m";
            try testing.expectEqualStrings(expected, seq);
        }
        
        test "unit: Style: empty style produces no output" {
            var buf: [256]u8 = undefined;
            
            const empty = ansi.Style{};
            const seq = try empty.toSequence(&buf);
            try testing.expectEqual(@as(usize, 0), seq.len);
        }
        
        test "unit: Style: each attribute generates correct code" {
            var buf: [256]u8 = undefined;
            
            // Test each attribute individually
            const test_cases = .{
                .{ .style = ansi.Style{ .bold = true }, .expected = "\x1b[1m" },
                .{ .style = ansi.Style{ .dim = true }, .expected = "\x1b[2m" },
                .{ .style = ansi.Style{ .italic = true }, .expected = "\x1b[3m" },
                .{ .style = ansi.Style{ .underline = true }, .expected = "\x1b[4m" },
                .{ .style = ansi.Style{ .blink = true }, .expected = "\x1b[5m" },
                .{ .style = ansi.Style{ .reverse = true }, .expected = "\x1b[7m" },
                .{ .style = ansi.Style{ .hidden = true }, .expected = "\x1b[8m" },
                .{ .style = ansi.Style{ .strikethrough = true }, .expected = "\x1b[9m" },
            };
            
            inline for (test_cases) |tc| {
                const seq = try tc.style.toSequence(&buf);
                try testing.expectEqualStrings(tc.expected, seq);
            }
        }
        
        // ── Builder Pattern Tests ──

        test "unit: Ansi: initialization and cleanup" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            try testing.expect(builder.buffer.items.len == 0);
        }
        
        test "unit: Ansi: zero movement operations are no-ops" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            // Zero movements should not generate sequences
            try builder.moveUp(0);
            try testing.expectEqual(@as(usize, 0), builder.getSequence().len);
            
            try builder.moveDown(0);
            try testing.expectEqual(@as(usize, 0), builder.getSequence().len);
            
            try builder.moveRight(0);
            try testing.expectEqual(@as(usize, 0), builder.getSequence().len);
            
            try builder.moveLeft(0);
            try testing.expectEqual(@as(usize, 0), builder.getSequence().len);
            
            try builder.scrollUp(0);
            try testing.expectEqual(@as(usize, 0), builder.getSequence().len);
            
            try builder.scrollDown(0);
            try testing.expectEqual(@as(usize, 0), builder.getSequence().len);
        }
        
        test "unit: Ansi: cursor movement" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            try builder.moveTo(10, 20);
            try testing.expectEqualStrings("\x1b[10;20H", builder.getSequence());
            
            builder.clear();
            try builder.moveUp(5);
            try testing.expectEqualStrings("\x1b[5A", builder.getSequence());
            
            builder.clear();
            try builder.moveDown(3);
            try testing.expectEqualStrings("\x1b[3B", builder.getSequence());
            
            builder.clear();
            try builder.moveRight(7);
            try testing.expectEqualStrings("\x1b[7C", builder.getSequence());
            
            builder.clear();
            try builder.moveLeft(2);
            try testing.expectEqualStrings("\x1b[2D", builder.getSequence());
        }

        test "unit: Ansi: color setting" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            // Basic color
            try builder.setFg(ansi.Color{ .basic = 1 });
            try testing.expectEqualStrings("\x1b[31m", builder.getSequence());
            
            builder.clear();
            try builder.setBg(ansi.Color{ .basic = 4 });
            try testing.expectEqualStrings("\x1b[44m", builder.getSequence());
            
            // Extended color
            builder.clear();
            try builder.setFg(ansi.Color{ .extended = 9 });
            try testing.expectEqualStrings("\x1b[91m", builder.getSequence());
            
            // Indexed color
            builder.clear();
            try builder.setFg(ansi.Color{ .indexed = 208 });
            try testing.expectEqualStrings("\x1b[38;5;208m", builder.getSequence());
            
            // RGB color
            builder.clear();
            try builder.setFg(ansi.Color{ .rgb = .{ .r = 255, .g = 0, .b = 128 } });
            try testing.expectEqualStrings("\x1b[38;2;255;0;128m", builder.getSequence());
        }

        test "unit: Ansi: style setting" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            const style = ansi.Style{
                .bold = true,
                .underline = true,
            };
            try builder.setStyle(style);
            try testing.expectEqualStrings("\x1b[1m\x1b[4m", builder.getSequence());
        }

        test "unit: Ansi: screen control" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            try builder.clearScreen();
            try testing.expectEqualStrings("\x1b[2J\x1b[1;1H", builder.getSequence());
            
            builder.clear();
            try builder.clearLine();
            try testing.expectEqualStrings("\x1b[2K", builder.getSequence());
            
            builder.clear();
            try builder.hideCursor();
            try testing.expectEqualStrings("\x1b[?25l", builder.getSequence());
            
            builder.clear();
            try builder.showCursor();
            try testing.expectEqualStrings("\x1b[?25h", builder.getSequence());
        }

        test "unit: Ansi: alternate screen" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            try builder.enterAltScreen();
            try testing.expectEqualStrings("\x1b[?1049h", builder.getSequence());
            
            builder.clear();
            try builder.exitAltScreen();
            try testing.expectEqualStrings("\x1b[?1049l", builder.getSequence());
        }
        
        test "unit: Ansi: cursor save and restore" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            try builder.saveCursor();
            try testing.expectEqualStrings(ansi.SAVE_CURSOR, builder.getSequence());
            
            builder.clear();
            try builder.restoreCursor();
            try testing.expectEqualStrings(ansi.RESTORE_CURSOR, builder.getSequence());
        }
        
        test "unit: Ansi: clear operations" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            try builder.clearToEol();
            try testing.expectEqualStrings(ansi.CLEAR_TO_EOL, builder.getSequence());
            
            builder.clear();
            try builder.clearLine();
            try testing.expectEqualStrings(ansi.CLEAR_LINE, builder.getSequence());
        }
        
        test "unit: Ansi: scrolling" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            try builder.scrollUp(3);
            try testing.expectEqualStrings("\x1b[3S", builder.getSequence());
            
            builder.clear();
            try builder.scrollDown(5);
            try testing.expectEqualStrings("\x1b[5T", builder.getSequence());
            
            builder.clear();
            try builder.setScrollRegion(5, 20);
            try testing.expectEqualStrings("\x1b[5;20r", builder.getSequence());
        }
        
        test "unit: Ansi: builder clear and reuse" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            // Build first sequence
            try builder.setFg(ansi.Color{ .basic = 1 });
            try testing.expectEqualStrings("\x1b[31m", builder.getSequence());
            
            // Clear and reuse
            builder.clear();
            try testing.expectEqual(@as(usize, 0), builder.getSequence().len);
            
            // Build new sequence
            try builder.setBg(ansi.Color{ .basic = 4 });
            try testing.expectEqualStrings("\x1b[44m", builder.getSequence());
        }
        
        test "unit: Ansi: reset operation" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            try builder.reset();
            try testing.expectEqualStrings(ansi.RESET, builder.getSequence());
        }
        
        // ── Static Helper Tests ──
        
        test "unit: Static: cursor position" {
            var buf: [32]u8 = undefined;
            
            const seq = try ansi.cursorPosition(1, 1, &buf);
            try testing.expectEqualStrings("\x1b[1;1H", seq);
            
            const seq2 = try ansi.cursorPosition(24, 80, &buf);
            try testing.expectEqualStrings("\x1b[24;80H", seq2);
            
            // Test large coordinates
            const seq3 = try ansi.cursorPosition(999, 999, &buf);
            try testing.expectEqualStrings("\x1b[999;999H", seq3);
        }
        
        test "unit: Static: color sequence with null values" {
            var buf: [128]u8 = undefined;
            
            // Only foreground
            const fg = ansi.Color{ .basic = 2 };
            const seq1 = try ansi.colorSequence(fg, null, &buf);
            try testing.expectEqualStrings("\x1b[32m", seq1);
            
            // Only background
            const bg = ansi.Color{ .basic = 3 };
            const seq2 = try ansi.colorSequence(null, bg, &buf);
            try testing.expectEqualStrings("\x1b[43m", seq2);
            
            // Neither (should return empty)
            const seq3 = try ansi.colorSequence(null, null, &buf);
            try testing.expectEqual(@as(usize, 0), seq3.len);
        }
        
        test "unit: Static: color sequence" {
            var buf: [128]u8 = undefined;
            
            const fg = ansi.Color{ .basic = 1 };
            const bg = ansi.Color{ .basic = 4 };
            
            const seq = try ansi.colorSequence(fg, bg, &buf);
            try testing.expectEqualStrings("\x1b[31m\x1b[44m", seq);
            
            const fg2 = ansi.Color{ .rgb = .{ .r = 255, .g = 0, .b = 0 } };
            const seq2 = try ansi.colorSequence(fg2, null, &buf);
            try testing.expectEqualStrings("\x1b[38;2;255;0;0m", seq2);
        }
        
        test "unit: Static: style sequence" {
            var buf: [256]u8 = undefined;
            
            const style = ansi.Style{
                .bold = true,
                .underline = true,
                .italic = true,
            };
            
            const seq = try ansi.styleSequence(style, &buf);
            try testing.expectEqualStrings("\x1b[1m\x1b[3m\x1b[4m", seq);
        }
        
        test "unit: Static: movement sequence" {
            var buf: [32]u8 = undefined;
            
            const seq = try ansi.movementSequence('A', 5, &buf);
            try testing.expectEqualStrings("\x1b[5A", seq);
            
            const seq2 = try ansi.movementSequence('B', 3, &buf);
            try testing.expectEqualStrings("\x1b[3B", seq2);
            
            const seq3 = try ansi.movementSequence('C', 10, &buf);
            try testing.expectEqualStrings("\x1b[10C", seq3);
            
            const seq4 = try ansi.movementSequence('D', 2, &buf);
            try testing.expectEqualStrings("\x1b[2D", seq4);
            
            // Zero movement returns empty
            const seq5 = try ansi.movementSequence('A', 0, &buf);
            try testing.expectEqual(@as(usize, 0), seq5.len);
        }
        
        test "unit: Static: clear sequence" {
            var buf: [32]u8 = undefined;
            
            // Clear to end
            const seq = try ansi.clearSequence(0, 'J', &buf);
            try testing.expectEqualStrings("\x1b[J", seq);
            
            // Clear to beginning
            const seq2 = try ansi.clearSequence(1, 'J', &buf);
            try testing.expectEqualStrings("\x1b[1J", seq2);
            
            // Clear entire
            const seq3 = try ansi.clearSequence(2, 'J', &buf);
            try testing.expectEqualStrings("\x1b[2J", seq3);
            
            // Clear line variants
            const seq4 = try ansi.clearSequence(0, 'K', &buf);
            try testing.expectEqualStrings("\x1b[K", seq4);
            
            const seq5 = try ansi.clearSequence(2, 'K', &buf);
            try testing.expectEqualStrings("\x1b[2K", seq5);
        }
    
    // └──────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
        
        test "integration: Ansi: complex sequence building" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            // Build a complex sequence
            try builder.reset();
            try builder.moveTo(10, 20);
            try builder.setFg(ansi.Color{ .rgb = .{ .r = 255, .g = 100, .b = 50 } });
            try builder.setBg(ansi.Color{ .indexed = 240 });
            try builder.setStyle(ansi.Style{ .bold = true, .italic = true });
            
            const expected = "\x1b[0m\x1b[10;20H\x1b[38;2;255;100;50m\x1b[48;5;240m\x1b[1m\x1b[3m";
            try testing.expectEqualStrings(expected, builder.getSequence());
        }
        
        test "integration: Ansi: cursor movement with colors and styles" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            // Complex operation sequence
            try builder.hideCursor();
            try builder.clearScreen();
            try builder.setFg(ansi.Color{ .extended = 14 }); // Bright cyan
            try builder.setBg(ansi.Color{ .basic = 0 }); // Black
            try builder.setStyle(ansi.Style{ .bold = true, .underline = true });
            try builder.moveTo(5, 10);
            
            const expected = ansi.HIDE_CURSOR ++ ansi.CLEAR_SCREEN ++ "\x1b[1;1H" ++
                "\x1b[96m" ++ "\x1b[40m" ++ "\x1b[1m\x1b[4m" ++ "\x1b[5;10H";
            try testing.expectEqualStrings(expected, builder.getSequence());
        }
        
        test "integration: Ansi: alternate screen with content" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            // Enter alternate screen, setup content, exit
            try builder.enterAltScreen();
            try builder.clearScreen();
            try builder.moveTo(12, 40);
            try builder.setFg(ansi.Color{ .indexed = 208 });
            try builder.exitAltScreen();
            
            const expected = ansi.ALT_SCREEN ++ ansi.CLEAR_SCREEN ++ "\x1b[1;1H" ++
                "\x1b[12;40H" ++ "\x1b[38;5;208m" ++ ansi.MAIN_SCREEN;
            try testing.expectEqualStrings(expected, builder.getSequence());
        }
        
        test "integration: Ansi: scrolling with regions" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            // Set scroll region and perform scrolling
            try builder.setScrollRegion(5, 20);
            try builder.moveTo(10, 1);
            try builder.scrollUp(3);
            try builder.scrollDown(2);
            
            const expected = "\x1b[5;20r" ++ "\x1b[10;1H" ++ "\x1b[3S" ++ "\x1b[2T";
            try testing.expectEqualStrings(expected, builder.getSequence());
        }
        
        test "integration: Color and Style: combined foreground and background" {
            var buf: [256]u8 = undefined;
            
            // Test combining different color modes
            const fg = ansi.Color{ .rgb = .{ .r = 255, .g = 128, .b = 0 } };
            const bg = ansi.Color{ .indexed = 232 };
            const style = ansi.Style{ .bold = true, .italic = true };
            
            const color_seq = try ansi.colorSequence(fg, bg, &buf);
            const expected_color = "\x1b[38;2;255;128;0m\x1b[48;5;232m";
            try testing.expectEqualStrings(expected_color, color_seq);
            
            const style_seq = try ansi.styleSequence(style, &buf);
            const expected_style = "\x1b[1m\x1b[3m";
            try testing.expectEqualStrings(expected_style, style_seq);
        }
        
        test "integration: Builder: multiple clear and reuse cycles" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            // First cycle
            try builder.setFg(ansi.Color{ .basic = 1 });
            const seq1 = try test_allocator.dupe(u8, builder.getSequence());
            defer test_allocator.free(seq1);
            try testing.expectEqualStrings("\x1b[31m", seq1);
            
            // Second cycle
            builder.clear();
            try builder.setBg(ansi.Color{ .basic = 4 });
            const seq2 = try test_allocator.dupe(u8, builder.getSequence());
            defer test_allocator.free(seq2);
            try testing.expectEqualStrings("\x1b[44m", seq2);
            
            // Third cycle with complex sequence
            builder.clear();
            try builder.moveTo(10, 20);
            try builder.setStyle(ansi.Style{ .underline = true });
            const seq3 = builder.getSequence();
            try testing.expectEqualStrings("\x1b[10;20H\x1b[4m", seq3);
        }
    
    // └──────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Scenario Tests ────────────────────────────┐
        
        test "scenario: Terminal Prompt: colored user@host with path" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            // Build a colored prompt: [green]user@host[reset]:[blue]/path[reset]$ 
            try builder.setFg(ansi.Color{ .basic = 2 }); // Green for user@host
            try builder.setStyle(ansi.Style{ .bold = true });
            // ... append text "user@host" ...
            try builder.reset();
            // ... append ":" ...
            try builder.setFg(ansi.Color{ .basic = 4 }); // Blue for path
            // ... append "/home/user" ...
            try builder.reset();
            // ... append "$ " ...
            
            // Verify sequence structure
            const seq = builder.getSequence();
            try testing.expect(std.mem.indexOf(u8, seq, "\x1b[32m") != null);
            try testing.expect(std.mem.indexOf(u8, seq, "\x1b[1m") != null);
            try testing.expect(std.mem.indexOf(u8, seq, "\x1b[0m") != null);
            try testing.expect(std.mem.indexOf(u8, seq, "\x1b[34m") != null);
        }
        
        test "scenario: Progress Bar: gradient colors with percentage" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            // Simulate progress bar at 60%
            const progress = 60;
            
            // Move to start position
            try builder.moveTo(10, 5);
            
            // Draw filled portion with gradient (green to yellow)
            if (progress < 50) {
                try builder.setFg(ansi.Color{ .basic = 1 }); // Red
            } else if (progress < 80) {
                try builder.setFg(ansi.Color{ .basic = 3 }); // Yellow
            } else {
                try builder.setFg(ansi.Color{ .basic = 2 }); // Green
            }
            
            // Draw background
            try builder.setBg(ansi.Color{ .basic = 0 });
            
            const seq = builder.getSequence();
            try testing.expect(seq.len > 0);
            try testing.expect(std.mem.indexOf(u8, seq, "\x1b[10;5H") != null);
            try testing.expect(std.mem.indexOf(u8, seq, "\x1b[33m") != null); // Yellow
        }
        
        test "scenario: Text Editor: cursor movement and highlighting" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            // Simulate text editor operations
            const cursor_line = 15;
            const cursor_col = 42;
            
            // Save current position
            try builder.saveCursor();
            
            // Move to status line
            try builder.moveTo(TestScenarios.text_editor.status_line, 1);
            
            // Clear status line and set colors
            try builder.clearLine();
            try builder.setFg(ansi.Color{ .basic = 7 }); // White
            try builder.setBg(ansi.Color{ .basic = 4 }); // Blue background
            try builder.setStyle(ansi.Style{ .reverse = true });
            
            // Return to saved position
            try builder.restoreCursor();
            
            // Move to cursor position
            try builder.moveTo(cursor_line, cursor_col);
            try builder.showCursor();
            
            const seq = builder.getSequence();
            try testing.expect(std.mem.indexOf(u8, seq, ansi.SAVE_CURSOR) != null);
            try testing.expect(std.mem.indexOf(u8, seq, ansi.RESTORE_CURSOR) != null);
            try testing.expect(std.mem.indexOf(u8, seq, "\x1b[24;1H") != null);
            try testing.expect(std.mem.indexOf(u8, seq, ansi.CLEAR_LINE) != null);
        }
        
        test "scenario: Color Gradient: smooth RGB transitions" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            // Create gradient from red to blue
            const steps = 10;
            var i: usize = 0;
            while (i < steps) : (i += 1) {
                const r = @as(u8, @intCast(255 - (i * 255 / steps)));
                const b = @as(u8, @intCast(i * 255 / steps));
                const color = ansi.Color{ .rgb = .{ .r = r, .g = 0, .b = b } };
                
                try builder.setFg(color);
                try builder.moveRight(1);
            }
            
            const seq = builder.getSequence();
            // Should contain multiple RGB sequences
            try testing.expect(std.mem.indexOf(u8, seq, "\x1b[38;2;") != null);
            // Should contain movement sequences
            try testing.expect(std.mem.indexOf(u8, seq, "\x1b[1C") != null);
        }
        
        test "scenario: Terminal UI: box drawing with styles" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            // Draw a styled box
            const box_top = 5;
            const box_left = 10;
            const box_width = 40;
            const box_height = 10;
            
            // Set box style
            try builder.setFg(ansi.Color{ .extended = 14 }); // Bright cyan
            try builder.setStyle(ansi.Style{ .bold = true });
            
            // Draw top border
            try builder.moveTo(box_top, box_left);
            // ... draw horizontal line ...
            
            // Draw sides
            var row: u16 = box_top + 1;
            while (row < box_top + box_height) : (row += 1) {
                try builder.moveTo(row, box_left);
                // ... draw left border ...
                try builder.moveTo(row, box_left + box_width);
                // ... draw right border ...
            }
            
            // Draw bottom border
            try builder.moveTo(box_top + box_height, box_left);
            
            const seq = builder.getSequence();
            try testing.expect(seq.len > 0);
            // Should contain positioning for corners
            try testing.expect(std.mem.indexOf(u8, seq, "\x1b[5;10H") != null);
        }
    
    // └──────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
        
        test "performance: Color: RGB to sequence conversion speed" {
            var buf: [64]u8 = undefined;
            const iterations = 10000;
            
            const color = ansi.Color{ .rgb = .{ .r = 128, .g = 64, .b = 192 } };
            
            var timer = try std.time.Timer.start();
            var i: usize = 0;
            while (i < iterations) : (i += 1) {
                _ = try color.toFgSequence(&buf);
            }
            
            const elapsed_ns = timer.read();
            const avg_ns = elapsed_ns / iterations;
            
            // Target: < 50ns per conversion
            const is_debug = @import("builtin").mode == .Debug;
            const threshold: usize = if (is_debug) 5000 else 500;
            try testing.expect(avg_ns < threshold);
        }
        
        test "performance: Style: multiple attributes to sequence" {
            var buf: [256]u8 = undefined;
            const iterations = 10000;
            
            const style = ansi.Style{
                .bold = true,
                .italic = true,
                .underline = true,
                .strikethrough = true,
            };
            
            var timer = try std.time.Timer.start();
            var i: usize = 0;
            while (i < iterations) : (i += 1) {
                _ = try style.toSequence(&buf);
            }
            
            const elapsed_ns = timer.read();
            const avg_ns = elapsed_ns / iterations;
            
            // Target: < 100ns per style sequence
            const is_debug = @import("builtin").mode == .Debug;
            const threshold: usize = if (is_debug) 10000 else 1000;
            try testing.expect(avg_ns < threshold);
        }
        
        test "performance: Ansi: sequence generation speed" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            const iterations = 10000;
            var timer = try std.time.Timer.start();
            
            var i: usize = 0;
            while (i < iterations) : (i += 1) {
                builder.clear();
                try builder.moveTo(10, 20);
                try builder.setFg(ansi.Color{ .indexed = 200 });
                try builder.setStyle(ansi.Style{ .bold = true });
            }
            
            const elapsed_ns = timer.read();
            const avg_ns = elapsed_ns / iterations;
            
            // Target: < 100ns per sequence generation (release mode)
            // In debug mode, we relax this significantly
            const is_debug = @import("builtin").mode == .Debug;
            const threshold: usize = if (is_debug) 10000 else 1000;
            try testing.expect(avg_ns < threshold);
        }
        
        test "performance: Ansi: buffer growth pattern" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            const iterations = 1000;
            var timer = try std.time.Timer.start();
            
            var i: usize = 0;
            while (i < iterations) : (i += 1) {
                try builder.setFg(ansi.Color{ .indexed = @as(u8, @intCast(i % 256)) });
            }
            
            const elapsed_ns = timer.read();
            const avg_ns = elapsed_ns / iterations;
            
            // Should handle growth efficiently
            const is_debug = @import("builtin").mode == .Debug;
            const threshold: usize = if (is_debug) 20000 else 2000;
            try testing.expect(avg_ns < threshold);
            
            // Buffer should have grown to accommodate all sequences
            try testing.expect(builder.buffer.capacity >= builder.buffer.items.len);
        }
        
        test "performance: Static helpers: direct sequence generation" {
            var buf: [128]u8 = undefined;
            const iterations = 10000;
            
            var timer = try std.time.Timer.start();
            var i: usize = 0;
            while (i < iterations) : (i += 1) {
                _ = try ansi.cursorPosition(@as(u16, @intCast((i % 100) + 1)), @as(u16, @intCast((i % 80) + 1)), &buf);
                _ = try ansi.movementSequence('A', @as(u16, @intCast(i % 10)), &buf);
                _ = try ansi.clearSequence(@as(u8, @intCast(i % 3)), 'J', &buf);
            }
            
            const elapsed_ns = timer.read();
            const total_ops = iterations * 3;
            const avg_ns = elapsed_ns / total_ops;
            
            // Target: < 30ns per static helper call
            const is_debug = @import("builtin").mode == .Debug;
            const threshold: usize = if (is_debug) 3000 else 300;
            try testing.expect(avg_ns < threshold);
        }
    
    // └──────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Stress Tests ────────────────────────────┐
        
        test "stress: Ansi: rapid sequence generation without leaks" {
            const iterations = 100000;
            var i: usize = 0;
            
            while (i < iterations) : (i += 1) {
                var builder = ansi.Ansi.init(test_allocator);
                
                // Generate complex sequence
                try builder.moveTo(@as(u16, @intCast((i % 100) + 1)), @as(u16, @intCast((i % 100) + 1)));
                try builder.setFg(ansi.Color{ .indexed = @as(u8, @intCast(i % 256)) });
                try builder.setStyle(ansi.Style{ .bold = (i % 2 == 0) });
                
                // Ensure sequence is valid
                const seq = builder.getSequence();
                try testing.expect(seq.len > 0);
                
                builder.deinit();
            }
        }
        
        test "stress: Ansi: maximum buffer size handling" {
            var builder = ansi.Ansi.init(test_allocator);
            defer builder.deinit();
            
            // Generate very large sequence
            const operations = 10000;
            var i: usize = 0;
            while (i < operations) : (i += 1) {
                // Each RGB color generates a long sequence
                const color = ansi.Color{ 
                    .rgb = .{ 
                        .r = @as(u8, @intCast(i % 256)),
                        .g = @as(u8, @intCast((i * 2) % 256)),
                        .b = @as(u8, @intCast((i * 3) % 256))
                    }
                };
                try builder.setFg(color);
                try builder.setBg(color);
            }
            
            const seq = builder.getSequence();
            try testing.expect(seq.len > operations * 20); // Each op generates ~20+ bytes
            
            // Clear and verify reuse
            builder.clear();
            try testing.expectEqual(@as(usize, 0), builder.getSequence().len);
            
            // Should still work after clear
            try builder.reset();
            try testing.expectEqualStrings(ansi.RESET, builder.getSequence());
        }
        
        test "stress: Color: all possible indexed colors" {
            var buf: [64]u8 = undefined;
            
            // Test all 256 indexed colors
            var i: u16 = 0;
            while (i <= 255) : (i += 1) {
                const color = ansi.Color{ .indexed = @as(u8, @intCast(i)) };
                
                const fg_seq = try color.toFgSequence(&buf);
                try testing.expect(fg_seq.len > 0);
                try testing.expect(std.mem.indexOf(u8, fg_seq, "\x1b[38;5;") != null);
                
                const bg_seq = try color.toBgSequence(&buf);
                try testing.expect(bg_seq.len > 0);
                try testing.expect(std.mem.indexOf(u8, bg_seq, "\x1b[48;5;") != null);
            }
        }
        
        test "stress: Builder: concurrent-like usage pattern" {
            // Simulate multiple "concurrent" builders
            const num_builders = 100;
            var builders: [num_builders]ansi.Ansi = undefined;
            
            // Initialize all builders
            for (&builders) |*b| {
                b.* = ansi.Ansi.init(test_allocator);
            }
            defer {
                for (&builders) |*b| {
                    b.deinit();
                }
            }
            
            // Perform operations on all builders
            const operations = 100;
            var op: usize = 0;
            while (op < operations) : (op += 1) {
                for (&builders, 0..) |*b, idx| {
                    try b.moveTo(@as(u16, @intCast(idx + 1)), @as(u16, @intCast(op + 1)));
                    try b.setFg(ansi.Color{ .basic = @as(u8, @intCast(idx % 8)) });
                    
                    if (op % 10 == 0) {
                        b.clear();
                    }
                }
            }
            
            // Verify all builders are still functional
            for (&builders) |*b| {
                try b.reset();
                const seq = b.getSequence();
                try testing.expect(seq.len > 0);
            }
        }
        
        test "stress: Static helpers: buffer boundary conditions" {
            // Test with minimal buffer sizes
            var tiny_buf: [1]u8 = undefined;
            var small_buf: [10]u8 = undefined;
            
            // These should fail with buffer too small
            try testing.expectError(error.NoSpaceLeft, ansi.cursorPosition(999, 999, &tiny_buf));
            try testing.expectError(error.NoSpaceLeft, ansi.colorSequence(
                ansi.Color{ .rgb = .{ .r = 255, .g = 255, .b = 255 } },
                ansi.Color{ .rgb = .{ .r = 0, .g = 0, .b = 0 } },
                &small_buf
            ));
            
            // Test exact buffer sizes
            var exact_buf: [8]u8 = undefined; // "\x1b[1;1H" is 7 bytes
            const seq = try ansi.cursorPosition(1, 1, &exact_buf);
            try testing.expectEqualStrings("\x1b[1;1H", seq);
        }
    
    // └──────────────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝