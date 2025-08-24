// ansi_demo.zig — Example demonstrating ANSI escape sequence usage
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

const std = @import("std");
// For standalone demo, we'll define the path relative to project root
// Run with: zig run examples/ansi_demo.zig
const ansi = @import("lib/terminal/utils/ansi/ansi.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut();
    const writer = stdout.writer();
    
    // Get allocator for builder
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Create ANSI builder
    var builder = ansi.Ansi.init(allocator);
    defer builder.deinit();
    
    // Clear screen and hide cursor
    try builder.clearScreen();
    try builder.hideCursor();
    try writer.writeAll(builder.getSequence());
    
    // Draw a colorful header
    builder.clear();
    try builder.moveTo(2, 10);
    try builder.setFg(ansi.Color{ .rgb = .{ .r = 255, .g = 100, .b = 50 } });
    try builder.setStyle(ansi.Style{ .bold = true, .underline = true });
    try writer.writeAll(builder.getSequence());
    try writer.writeAll("ANSI Escape Sequence Demo");
    
    // Reset style
    builder.clear();
    try builder.reset();
    try writer.writeAll(builder.getSequence());
    
    // Show basic colors
    builder.clear();
    try builder.moveTo(4, 5);
    try writer.writeAll(builder.getSequence());
    try writer.writeAll("Basic Colors:");
    
    var row: u16 = 5;
    var col: u16 = 5;
    var color: u8 = 0;
    while (color < 8) : (color += 1) {
        builder.clear();
        try builder.moveTo(row, col);
        try builder.setFg(ansi.Color{ .basic = color });
        try writer.writeAll(builder.getSequence());
        try writer.print("Color {}", .{color});
        col += 10;
    }
    
    // Show extended colors
    builder.clear();
    try builder.reset();
    try builder.moveTo(7, 5);
    try writer.writeAll(builder.getSequence());
    try writer.writeAll("Extended Colors (bright):");
    
    row = 8;
    col = 5;
    color = 8;
    while (color < 16) : (color += 1) {
        builder.clear();
        try builder.moveTo(row, col);
        try builder.setFg(ansi.Color{ .extended = color });
        try writer.writeAll(builder.getSequence());
        try writer.print("Color {}", .{color});
        col += 10;
    }
    
    // Show 256 color palette sample
    builder.clear();
    try builder.reset();
    try builder.moveTo(10, 5);
    try writer.writeAll(builder.getSequence());
    try writer.writeAll("256 Color Palette Sample:");
    
    row = 11;
    col = 5;
    var indexed: u8 = 16;
    while (indexed < 232 and col < 70) : (indexed += 6) {
        builder.clear();
        try builder.moveTo(row, col);
        try builder.setBg(ansi.Color{ .indexed = indexed });
        try writer.writeAll(builder.getSequence());
        try writer.writeAll("  ");
        col += 2;
        if (col >= 70) {
            col = 5;
            row += 1;
        }
    }
    
    // Show RGB gradient
    builder.clear();
    try builder.reset();
    try builder.moveTo(15, 5);
    try writer.writeAll(builder.getSequence());
    try writer.writeAll("RGB Gradient:");
    
    row = 16;
    col = 5;
    var r: u8 = 0;
    while (r < 255) : (r += 5) {
        builder.clear();
        try builder.moveTo(row, col);
        try builder.setBg(ansi.Color{ .rgb = .{ .r = r, .g = 100, .b = 200 - @min(r, 200) } });
        try writer.writeAll(builder.getSequence());
        try writer.writeAll(" ");
        col += 1;
        if (col >= 70) {
            col = 5;
            row += 1;
        }
    }
    
    // Show text styles
    builder.clear();
    try builder.reset();
    try builder.moveTo(19, 5);
    try writer.writeAll(builder.getSequence());
    try writer.writeAll("Text Styles:");
    
    builder.clear();
    try builder.moveTo(20, 5);
    try builder.setStyle(ansi.Style{ .bold = true });
    try writer.writeAll(builder.getSequence());
    try writer.writeAll("Bold");
    
    builder.clear();
    try builder.moveTo(20, 15);
    try builder.reset();
    try builder.setStyle(ansi.Style{ .italic = true });
    try writer.writeAll(builder.getSequence());
    try writer.writeAll("Italic");
    
    builder.clear();
    try builder.moveTo(20, 25);
    try builder.reset();
    try builder.setStyle(ansi.Style{ .underline = true });
    try writer.writeAll(builder.getSequence());
    try writer.writeAll("Underline");
    
    builder.clear();
    try builder.moveTo(20, 40);
    try builder.reset();
    try builder.setStyle(ansi.Style{ .strikethrough = true });
    try writer.writeAll(builder.getSequence());
    try writer.writeAll("Strikethrough");
    
    builder.clear();
    try builder.moveTo(21, 5);
    try builder.reset();
    try builder.setStyle(ansi.Style{ .dim = true });
    try writer.writeAll(builder.getSequence());
    try writer.writeAll("Dim");
    
    builder.clear();
    try builder.moveTo(21, 15);
    try builder.reset();
    try builder.setStyle(ansi.Style{ .reverse = true });
    try writer.writeAll(builder.getSequence());
    try writer.writeAll("Reverse");
    
    builder.clear();
    try builder.moveTo(21, 25);
    try builder.reset();
    try builder.setStyle(ansi.Style{ .blink = true });
    try writer.writeAll(builder.getSequence());
    try writer.writeAll("Blink");
    
    // Reset and show cursor
    builder.clear();
    try builder.reset();
    try builder.moveTo(23, 1);
    try builder.showCursor();
    try writer.writeAll(builder.getSequence());
    
    try writer.writeAll("\nPress Enter to exit...");
    _ = try std.io.getStdIn().reader().readByte();
    
    // Clean up screen
    builder.clear();
    try builder.reset();
    try builder.clearScreen();
    try builder.moveTo(1, 1);
    try writer.writeAll(builder.getSequence());
}