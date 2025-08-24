// ansi.test.zig — Comprehensive tests for ANSI escape sequences
//
// repo   : https://github.com/fisty/zig-tui
// author : https://github.com/fisty
//
// Tests for ANSI sequence generation, parsing, and validation.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const testing = std.testing;
    const Ansi = @import("ansi.zig");

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test constants
    const ESC = "\x1b";
    const CSI = ESC ++ "[";
    
    // Color codes
    const Color = enum(u8) {
        black = 30,
        red = 31,
        green = 32,
        yellow = 33,
        blue = 34,
        magenta = 35,
        cyan = 36,
        white = 37,
        default = 39,
        
        bright_black = 90,
        bright_red = 91,
        bright_green = 92,
        bright_yellow = 93,
        bright_blue = 94,
        bright_magenta = 95,
        bright_cyan = 96,
        bright_white = 97,
    };
    
    // Test helpers
    fn validateAnsiSequence(sequence: []const u8) bool {
        if (sequence.len < 3) return false;
        if (!std.mem.startsWith(u8, sequence, ESC)) return false;
        if (sequence[1] != '[') return false;
        return true;
    }
    
    fn extractAnsiParams(sequence: []const u8) ![]u8 {
        if (!validateAnsiSequence(sequence)) {
            return error.InvalidSequence;
        }
        
        const start = 2; // After ESC[
        var end = start;
        while (end < sequence.len and sequence[end] != 'm' and 
               sequence[end] != 'H' and sequence[end] != 'J' and 
               sequence[end] != 'K' and sequence[end] != 'A' and 
               sequence[end] != 'B' and sequence[end] != 'C' and 
               sequence[end] != 'D') : (end += 1) {}
        
        return sequence[start..end];
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐
    
        test "unit: Ansi: generates cursor movement sequences" {
            const allocator = testing.allocator;
            
            // Move cursor up
            const up = try Ansi.cursorUp(allocator, 5);
            defer allocator.free(up);
            try testing.expectEqualStrings(CSI ++ "5A", up);
            
            // Move cursor down
            const down = try Ansi.cursorDown(allocator, 3);
            defer allocator.free(down);
            try testing.expectEqualStrings(CSI ++ "3B", down);
            
            // Move cursor forward
            const forward = try Ansi.cursorForward(allocator, 10);
            defer allocator.free(forward);
            try testing.expectEqualStrings(CSI ++ "10C", forward);
            
            // Move cursor backward
            const backward = try Ansi.cursorBackward(allocator, 2);
            defer allocator.free(backward);
            try testing.expectEqualStrings(CSI ++ "2D", backward);
        }
        
        test "unit: Ansi: generates cursor position sequence" {
            const allocator = testing.allocator;
            
            const pos = try Ansi.setCursorPosition(allocator, 10, 20);
            defer allocator.free(pos);
            
            try testing.expectEqualStrings(CSI ++ "20;10H", pos);
            try testing.expect(validateAnsiSequence(pos));
        }
        
        test "unit: Ansi: generates clear sequences" {
            const allocator = testing.allocator;
            
            // Clear screen
            const clear_screen = try Ansi.clearScreen(allocator);
            defer allocator.free(clear_screen);
            try testing.expectEqualStrings(CSI ++ "2J", clear_screen);
            
            // Clear line
            const clear_line = try Ansi.clearLine(allocator);
            defer allocator.free(clear_line);
            try testing.expectEqualStrings(CSI ++ "2K", clear_line);
            
            // Clear to end of line
            const clear_eol = try Ansi.clearToEndOfLine(allocator);
            defer allocator.free(clear_eol);
            try testing.expectEqualStrings(CSI ++ "0K", clear_eol);
        }
        
        test "unit: Ansi: generates color sequences" {
            const allocator = testing.allocator;
            
            // Foreground color
            const fg_red = try Ansi.setForegroundColor(allocator, @intFromEnum(Color.red));
            defer allocator.free(fg_red);
            try testing.expectEqualStrings(CSI ++ "31m", fg_red);
            
            // Background color
            const bg_blue = try Ansi.setBackgroundColor(allocator, @intFromEnum(Color.blue) + 10);
            defer allocator.free(bg_blue);
            try testing.expectEqualStrings(CSI ++ "44m", bg_blue);
            
            // RGB foreground
            const rgb_fg = try Ansi.setForegroundRGB(allocator, 255, 128, 0);
            defer allocator.free(rgb_fg);
            try testing.expectEqualStrings(CSI ++ "38;2;255;128;0m", rgb_fg);
            
            // RGB background
            const rgb_bg = try Ansi.setBackgroundRGB(allocator, 0, 255, 128);
            defer allocator.free(rgb_bg);
            try testing.expectEqualStrings(CSI ++ "48;2;0;255;128m", rgb_bg);
        }
        
        test "unit: Ansi: generates style sequences" {
            const allocator = testing.allocator;
            
            // Bold
            const bold = try Ansi.setBold(allocator);
            defer allocator.free(bold);
            try testing.expectEqualStrings(CSI ++ "1m", bold);
            
            // Dim
            const dim = try Ansi.setDim(allocator);
            defer allocator.free(dim);
            try testing.expectEqualStrings(CSI ++ "2m", dim);
            
            // Italic
            const italic = try Ansi.setItalic(allocator);
            defer allocator.free(italic);
            try testing.expectEqualStrings(CSI ++ "3m", italic);
            
            // Underline
            const underline = try Ansi.setUnderline(allocator);
            defer allocator.free(underline);
            try testing.expectEqualStrings(CSI ++ "4m", underline);
            
            // Reset
            const reset = try Ansi.reset(allocator);
            defer allocator.free(reset);
            try testing.expectEqualStrings(CSI ++ "0m", reset);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: Ansi sequence builder: combines multiple attributes" {
            const allocator = testing.allocator;
            
            var builder = try Ansi.SequenceBuilder.init(allocator);
            defer builder.deinit();
            
            try builder.addForegroundColor(@intFromEnum(Color.red));
            try builder.addBackgroundColor(@intFromEnum(Color.blue) + 10);
            try builder.addBold();
            try builder.addUnderline();
            
            const sequence = try builder.build();
            defer allocator.free(sequence);
            
            try testing.expectEqualStrings(CSI ++ "31;44;1;4m", sequence);
        }
        
        test "integration: Ansi with cursor control: complete positioning" {
            const allocator = testing.allocator;
            var buffer = std.ArrayList(u8).init(allocator);
            defer buffer.deinit();
            
            // Save cursor position
            const save = try Ansi.saveCursorPosition(allocator);
            defer allocator.free(save);
            try buffer.appendSlice(save);
            
            // Move to position
            const move = try Ansi.setCursorPosition(allocator, 10, 20);
            defer allocator.free(move);
            try buffer.appendSlice(move);
            
            // Write text with color
            const color = try Ansi.setForegroundColor(allocator, @intFromEnum(Color.green));
            defer allocator.free(color);
            try buffer.appendSlice(color);
            
            // Restore cursor position
            const restore = try Ansi.restoreCursorPosition(allocator);
            defer allocator.free(restore);
            try buffer.appendSlice(restore);
            
            // Verify complete sequence
            try testing.expect(buffer.items.len > 0);
            try testing.expect(std.mem.indexOf(u8, buffer.items, ESC ++ "7") != null);
            try testing.expect(std.mem.indexOf(u8, buffer.items, ESC ++ "8") != null);
        }
        
        test "integration: Ansi parser: extracts parameters correctly" {
            const allocator = testing.allocator;
            
            // Parse color sequence
            const color_seq = CSI ++ "38;2;255;128;64m";
            const params = try Ansi.parseSequence(allocator, color_seq);
            defer allocator.free(params);
            
            try testing.expectEqual(@as(usize, 5), params.len);
            try testing.expectEqual(@as(u8, 38), params[0]);
            try testing.expectEqual(@as(u8, 2), params[1]);
            try testing.expectEqual(@as(u8, 255), params[2]);
            try testing.expectEqual(@as(u8, 128), params[3]);
            try testing.expectEqual(@as(u8, 64), params[4]);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── E2E Tests ────────────────────────────┐
    
        test "e2e: complete terminal formatting: styled output generation" {
            const allocator = testing.allocator;
            var output = std.ArrayList(u8).init(allocator);
            defer output.deinit();
            
            // Clear screen and reset
            const clear = try Ansi.clearScreen(allocator);
            defer allocator.free(clear);
            try output.appendSlice(clear);
            
            const reset = try Ansi.reset(allocator);
            defer allocator.free(reset);
            try output.appendSlice(reset);
            
            // Position cursor at top
            const home = try Ansi.setCursorPosition(allocator, 1, 1);
            defer allocator.free(home);
            try output.appendSlice(home);
            
            // Write header with styling
            const bold = try Ansi.setBold(allocator);
            defer allocator.free(bold);
            try output.appendSlice(bold);
            
            const fg_white = try Ansi.setForegroundColor(allocator, @intFromEnum(Color.bright_white));
            defer allocator.free(fg_white);
            try output.appendSlice(fg_white);
            
            const bg_blue = try Ansi.setBackgroundColor(allocator, @intFromEnum(Color.blue) + 10);
            defer allocator.free(bg_blue);
            try output.appendSlice(bg_blue);
            
            try output.appendSlice(" TUI Application ");
            
            // Reset after header
            try output.appendSlice(reset);
            
            // Move to next line
            const next_line = try Ansi.cursorDown(allocator, 2);
            defer allocator.free(next_line);
            try output.appendSlice(next_line);
            
            // Verify output contains all sequences
            try testing.expect(output.items.len > 50);
            try testing.expect(std.mem.indexOf(u8, output.items, CSI ++ "2J") != null);
            try testing.expect(std.mem.indexOf(u8, output.items, CSI ++ "1;1H") != null);
        }
        
        test "e2e: terminal control flow: cursor hide/show cycle" {
            const allocator = testing.allocator;
            var commands = std.ArrayList([]const u8).init(allocator);
            defer {
                for (commands.items) |cmd| {
                    allocator.free(cmd);
                }
                commands.deinit();
            }
            
            // Hide cursor
            const hide = try Ansi.hideCursor(allocator);
            try commands.append(hide);
            
            // Perform operations
            const move1 = try Ansi.setCursorPosition(allocator, 10, 10);
            try commands.append(move1);
            
            const clear = try Ansi.clearLine(allocator);
            try commands.append(clear);
            
            const move2 = try Ansi.setCursorPosition(allocator, 20, 20);
            try commands.append(move2);
            
            // Show cursor
            const show = try Ansi.showCursor(allocator);
            try commands.append(show);
            
            // Verify sequence
            try testing.expectEqualStrings(CSI ++ "?25l", commands.items[0]);
            try testing.expectEqualStrings(CSI ++ "?25h", commands.items[commands.items.len - 1]);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: Ansi generation: creates many sequences quickly" {
            const allocator = testing.allocator;
            
            const iterations = 10000;
            var sequences = std.ArrayList([]u8).init(allocator);
            defer {
                for (sequences.items) |seq| {
                    allocator.free(seq);
                }
                sequences.deinit();
            }
            
            const start = std.time.milliTimestamp();
            
            for (0..iterations) |i| {
                const x = @as(u16, @intCast(i % 100));
                const y = @as(u16, @intCast(i % 50));
                const seq = try Ansi.setCursorPosition(allocator, x, y);
                try sequences.append(seq);
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should generate 10k sequences quickly
            try testing.expect(elapsed < 100);
            try testing.expectEqual(@as(usize, iterations), sequences.items.len);
        }
        
        test "performance: Ansi builder: builds complex sequences efficiently" {
            const allocator = testing.allocator;
            
            const iterations = 1000;
            const start = std.time.milliTimestamp();
            
            for (0..iterations) |i| {
                var builder = try Ansi.SequenceBuilder.init(allocator);
                defer builder.deinit();
                
                // Add many attributes
                try builder.addForegroundRGB(@intCast(i % 256), @intCast((i * 2) % 256), @intCast((i * 3) % 256));
                try builder.addBackgroundRGB(@intCast((i * 3) % 256), @intCast((i * 2) % 256), @intCast(i % 256));
                try builder.addBold();
                try builder.addItalic();
                try builder.addUnderline();
                
                const sequence = try builder.build();
                allocator.free(sequence);
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            
            // Should build complex sequences quickly
            try testing.expect(elapsed < 100);
        }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Stress Tests ────────────────────────────┐
    
        test "stress: Ansi: handles all color combinations" {
            const allocator = testing.allocator;
            
            // Test all foreground/background combinations
            for (30..38) |fg| {
                for (40..48) |bg| {
                    const fg_seq = try Ansi.setForegroundColor(allocator, @intCast(fg));
                    defer allocator.free(fg_seq);
                    
                    const bg_seq = try Ansi.setBackgroundColor(allocator, @intCast(bg));
                    defer allocator.free(bg_seq);
                    
                    try testing.expect(validateAnsiSequence(fg_seq));
                    try testing.expect(validateAnsiSequence(bg_seq));
                }
            }
            
            // Test bright colors
            for (90..98) |fg| {
                for (100..108) |bg| {
                    const fg_seq = try Ansi.setForegroundColor(allocator, @intCast(fg));
                    defer allocator.free(fg_seq);
                    
                    const bg_seq = try Ansi.setBackgroundColor(allocator, @intCast(bg));
                    defer allocator.free(bg_seq);
                    
                    try testing.expect(validateAnsiSequence(fg_seq));
                    try testing.expect(validateAnsiSequence(bg_seq));
                }
            }
        }
        
        test "stress: Ansi: generates maximum length sequences" {
            const allocator = testing.allocator;
            
            var builder = try Ansi.SequenceBuilder.init(allocator);
            defer builder.deinit();
            
            // Add many parameters
            for (0..20) |_| {
                try builder.addParameter(255);
            }
            
            const sequence = try builder.build();
            defer allocator.free(sequence);
            
            // Should handle long sequences
            try testing.expect(sequence.len > 50);
            try testing.expect(validateAnsiSequence(sequence));
        }
    
    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝