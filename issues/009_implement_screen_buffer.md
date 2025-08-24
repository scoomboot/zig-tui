# Issue #009: Implement screen buffer

## Summary
Create a double-buffered screen management system for efficient terminal rendering.

## Description
Implement a Screen structure that manages two buffers (front and back) of cells, providing methods for drawing, buffer swapping, and efficient change detection. The screen buffer should handle coordinate validation, clipping, and provide various drawing primitives.

## Acceptance Criteria
- [ ] Create `lib/screen/screen.zig`
- [ ] Implement double-buffering system
- [ ] Add drawing primitives:
  - [ ] Set cell at position
  - [ ] Write text/strings
  - [ ] Draw lines (horizontal/vertical)
  - [ ] Fill rectangles
  - [ ] Clear regions
- [ ] Implement buffer comparison for dirty regions
- [ ] Add viewport/clipping support
- [ ] Handle coordinate validation
- [ ] Optimize memory allocation
- [ ] Create comprehensive tests
- [ ] Follow MCS style guidelines

## Dependencies
- Issue #008 (Implement cell structure)

## Implementation Notes
```zig
// screen.zig — Double-buffered screen management
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const Cell = @import("utils/cell/cell.zig").Cell;
    const Color = @import("utils/cell/cell.zig").Color;
    const Style = @import("utils/cell/cell.zig").Style;
    const Rect = @import("utils/rect/rect.zig").Rect;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    pub const ScreenError = error{
        OutOfBounds,
        InvalidDimensions,
        AllocationFailed,
    };

    pub const DrawOptions = struct {
        fg: ?Color = null,
        bg: ?Color = null,
        style: ?Style = null,
        wrap: bool = false,
        clip: bool = true,
    };

    pub const DirtyRegion = struct {
        start_row: u16,
        end_row: u16,
        start_col: u16,
        end_col: u16,
        
        pub fn isEmpty(self: DirtyRegion) bool {
            return self.start_row > self.end_row or self.start_col > self.end_col;
        }
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    pub const Screen = struct {
        allocator: std.mem.Allocator,
        width: u16,
        height: u16,
        front_buffer: []Cell,
        back_buffer: []Cell,
        dirty_region: ?DirtyRegion,
        default_cell: Cell,

        // ┌──────────────────────────── Initialization ────────────────────────────┐

            /// Create a new screen with specified dimensions
            pub fn init(allocator: std.mem.Allocator, width: u16, height: u16) !Screen {
                if (width == 0 or height == 0) {
                    return ScreenError.InvalidDimensions;
                }

                const buffer_size = @as(usize, width) * @as(usize, height);
                
                var screen = Screen{
                    .allocator = allocator,
                    .width = width,
                    .height = height,
                    .front_buffer = try allocator.alloc(Cell, buffer_size),
                    .back_buffer = try allocator.alloc(Cell, buffer_size),
                    .dirty_region = null,
                    .default_cell = Cell.empty(),
                };

                // Initialize buffers with empty cells
                for (screen.front_buffer) |*cell| {
                    cell.* = Cell.empty();
                }
                for (screen.back_buffer) |*cell| {
                    cell.* = Cell.empty();
                }

                return screen;
            }

            /// Clean up screen resources
            pub fn deinit(self: *Screen) void {
                self.allocator.free(self.front_buffer);
                self.allocator.free(self.back_buffer);
            }

            /// Resize the screen buffers
            pub fn resize(self: *Screen, new_width: u16, new_height: u16) !void {
                if (new_width == 0 or new_height == 0) {
                    return ScreenError.InvalidDimensions;
                }

                const new_size = @as(usize, new_width) * @as(usize, new_height);
                
                // Allocate new buffers
                const new_front = try self.allocator.alloc(Cell, new_size);
                const new_back = try self.allocator.alloc(Cell, new_size);
                
                // Initialize new buffers
                for (new_front) |*cell| {
                    cell.* = self.default_cell;
                }
                for (new_back) |*cell| {
                    cell.* = self.default_cell;
                }
                
                // Copy existing content (with clipping)
                const copy_width = @min(self.width, new_width);
                const copy_height = @min(self.height, new_height);
                
                var y: u16 = 0;
                while (y < copy_height) : (y += 1) {
                    const old_start = y * self.width;
                    const new_start = y * new_width;
                    
                    std.mem.copy(
                        Cell,
                        new_front[new_start..new_start + copy_width],
                        self.front_buffer[old_start..old_start + copy_width],
                    );
                    std.mem.copy(
                        Cell,
                        new_back[new_start..new_start + copy_width],
                        self.back_buffer[old_start..old_start + copy_width],
                    );
                }
                
                // Free old buffers
                self.allocator.free(self.front_buffer);
                self.allocator.free(self.back_buffer);
                
                // Update screen
                self.front_buffer = new_front;
                self.back_buffer = new_back;
                self.width = new_width;
                self.height = new_height;
                self.dirty_region = null;
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Drawing Operations ────────────────────────────┐

            /// Set a cell at the given position
            pub fn setCell(self: *Screen, x: u16, y: u16, cell: Cell) !void {
                if (x >= self.width or y >= self.height) {
                    return ScreenError.OutOfBounds;
                }

                const index = y * self.width + x;
                self.back_buffer[index] = cell;
                self.markDirty(x, y, x, y);
            }

            /// Write text at the given position
            pub fn writeText(self: *Screen, x: u16, y: u16, text: []const u8, opts: DrawOptions) !void {
                var cur_x = x;
                var cur_y = y;
                
                var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
                while (iter.nextCodepoint()) |ch| {
                    // Handle newlines
                    if (ch == '\n') {
                        cur_x = x;
                        cur_y += 1;
                        if (cur_y >= self.height) {
                            if (!opts.wrap) break;
                            cur_y = 0;
                        }
                        continue;
                    }
                    
                    // Check bounds
                    if (cur_x >= self.width) {
                        if (!opts.wrap) break;
                        cur_x = 0;
                        cur_y += 1;
                        if (cur_y >= self.height) break;
                    }
                    
                    // Create and set cell
                    const cell = Cell.init(ch, opts.fg, opts.bg, opts.style);
                    try self.setCell(cur_x, cur_y, cell);
                    
                    cur_x += @intCast(u16, cell.width());
                }
            }

            /// Draw a horizontal line
            pub fn drawHLine(self: *Screen, x: u16, y: u16, width: u16, ch: u21, opts: DrawOptions) !void {
                if (y >= self.height) return;
                
                const end_x = @min(x + width, self.width);
                var cur_x = x;
                
                while (cur_x < end_x) : (cur_x += 1) {
                    const cell = Cell.init(ch, opts.fg, opts.bg, opts.style);
                    try self.setCell(cur_x, y, cell);
                }
            }

            /// Draw a vertical line
            pub fn drawVLine(self: *Screen, x: u16, y: u16, height: u16, ch: u21, opts: DrawOptions) !void {
                if (x >= self.width) return;
                
                const end_y = @min(y + height, self.height);
                var cur_y = y;
                
                while (cur_y < end_y) : (cur_y += 1) {
                    const cell = Cell.init(ch, opts.fg, opts.bg, opts.style);
                    try self.setCell(x, cur_y, cell);
                }
            }

            /// Fill a rectangle with a character
            pub fn fillRect(self: *Screen, rect: Rect, ch: u21, opts: DrawOptions) !void {
                const cell = Cell.init(ch, opts.fg, opts.bg, opts.style);
                
                var y = rect.y;
                while (y < rect.y + rect.height and y < self.height) : (y += 1) {
                    var x = rect.x;
                    while (x < rect.x + rect.width and x < self.width) : (x += 1) {
                        try self.setCell(x, y, cell);
                    }
                }
            }

            /// Clear a region of the screen
            pub fn clearRegion(self: *Screen, rect: Rect) !void {
                try self.fillRect(rect, ' ', .{});
            }

            /// Clear the entire screen
            pub fn clear(self: *Screen) !void {
                for (self.back_buffer) |*cell| {
                    cell.* = self.default_cell;
                }
                self.markDirty(0, 0, self.width - 1, self.height - 1);
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Buffer Management ────────────────────────────┐

            /// Swap front and back buffers
            pub fn present(self: *Screen) void {
                std.mem.swap([]Cell, &self.front_buffer, &self.back_buffer);
                self.dirty_region = null;
            }

            /// Get changes between front and back buffers
            pub fn getDiff(self: *Screen) []const DiffEntry {
                // Implementation would return list of changed cells
                // This is used by the renderer to minimize terminal updates
            }

            /// Mark a region as dirty (needs redraw)
            fn markDirty(self: *Screen, x1: u16, y1: u16, x2: u16, y2: u16) void {
                if (self.dirty_region) |*region| {
                    region.start_row = @min(region.start_row, y1);
                    region.end_row = @max(region.end_row, y2);
                    region.start_col = @min(region.start_col, x1);
                    region.end_col = @max(region.end_col, x2);
                } else {
                    self.dirty_region = DirtyRegion{
                        .start_row = y1,
                        .end_row = y2,
                        .start_col = x1,
                        .end_col = x2,
                    };
                }
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Utility Methods ────────────────────────────┐

            /// Get cell at position (from back buffer)
            pub fn getCell(self: *Screen, x: u16, y: u16) ?Cell {
                if (x >= self.width or y >= self.height) return null;
                return self.back_buffer[y * self.width + x];
            }

            /// Get cell at position (from front buffer)
            pub fn getFrontCell(self: *Screen, x: u16, y: u16) ?Cell {
                if (x >= self.width or y >= self.height) return null;
                return self.front_buffer[y * self.width + x];
            }

            /// Check if position is within screen bounds
            pub fn contains(self: *Screen, x: u16, y: u16) bool {
                return x < self.width and y < self.height;
            }

        // └──────────────────────────────────────────────────────────────────┘

    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Test buffer initialization
- Test drawing operations
- Test text wrapping
- Test clipping behavior
- Test buffer swapping
- Test dirty region tracking
- Test resize operations
- Memory usage: O(width × height × cell_size)
- Performance: < 1ms for full screen clear

## Estimated Time
4 hours

## Priority
🟡 High - Core rendering component

## Category
Screen Management