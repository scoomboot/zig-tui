// screen.zig — Screen buffer implementation and management
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══ PACK ══╗

    const std = @import("std");
    const cell_mod = @import("utils/cell/cell.zig");
    const rect_mod = @import("utils/rect/rect.zig");

// ╚══════════╝

// ╔══ CORE ══╗

    /// Screen buffer structure
    pub const Screen = struct {
        allocator: std.mem.Allocator,
        width: u16,
        height: u16,
        front_buffer: []cell_mod.Cell,
        back_buffer: []cell_mod.Cell,
        
        /// Initialize screen with given dimensions
        pub fn init(allocator: std.mem.Allocator) !Screen {
            return init_with_size(allocator, 80, 24);
        }
        
        /// Initialize screen with specific size
        pub fn init_with_size(allocator: std.mem.Allocator, width: u16, height: u16) !Screen {
            const buffer_size = @as(usize, width) * @as(usize, height);
            
            const front = try allocator.alloc(cell_mod.Cell, buffer_size);
            errdefer allocator.free(front);
            
            const back = try allocator.alloc(cell_mod.Cell, buffer_size);
            errdefer allocator.free(back);
            
            // Initialize buffers with empty cells
            for (front) |*cell| {
                cell.* = cell_mod.Cell.empty();
            }
            for (back) |*cell| {
                cell.* = cell_mod.Cell.empty();
            }
            
            return Screen{
                .allocator = allocator,
                .width = width,
                .height = height,
                .front_buffer = front,
                .back_buffer = back,
            };
        }
        
        /// Deinitialize screen
        pub fn deinit(self: *Screen) void {
            self.allocator.free(self.front_buffer);
            self.allocator.free(self.back_buffer);
        }
        
        /// Resize screen buffers
        pub fn resize(self: *Screen, width: u16, height: u16) !void {
            const new_size = @as(usize, width) * @as(usize, height);
            
            // Allocate new buffers
            const new_front = try self.allocator.alloc(cell_mod.Cell, new_size);
            errdefer self.allocator.free(new_front);
            
            const new_back = try self.allocator.alloc(cell_mod.Cell, new_size);
            errdefer self.allocator.free(new_back);
            
            // Initialize new buffers
            for (new_front) |*cell| {
                cell.* = cell_mod.Cell.empty();
            }
            for (new_back) |*cell| {
                cell.* = cell_mod.Cell.empty();
            }
            
            // Free old buffers
            self.allocator.free(self.front_buffer);
            self.allocator.free(self.back_buffer);
            
            // Update screen
            self.width = width;
            self.height = height;
            self.front_buffer = new_front;
            self.back_buffer = new_back;
        }
        
        /// Get cell at position
        pub fn get_cell(self: *Screen, x: u16, y: u16) ?*cell_mod.Cell {
            if (x >= self.width or y >= self.height) return null;
            
            const index = @as(usize, y) * @as(usize, self.width) + @as(usize, x);
            return &self.back_buffer[index];
        }
        
        /// Set cell at position
        pub fn set_cell(self: *Screen, x: u16, y: u16, cell: cell_mod.Cell) void {
            if (x >= self.width or y >= self.height) return;
            
            const index = @as(usize, y) * @as(usize, self.width) + @as(usize, x);
            self.back_buffer[index] = cell;
        }
        
        /// Clear screen buffer
        pub fn clear(self: *Screen) void {
            for (self.back_buffer) |*cell| {
                cell.* = cell_mod.Cell.empty();
            }
        }
        
        /// Swap front and back buffers
        pub fn swap_buffers(self: *Screen) void {
            const temp = self.front_buffer;
            self.front_buffer = self.back_buffer;
            self.back_buffer = temp;
        }
        
        /// Get differences between front and back buffers
        pub fn get_diff(self: *Screen, allocator: std.mem.Allocator) ![]const DiffCell {
            var diff_list = std.ArrayList(DiffCell).init(allocator);
            defer diff_list.deinit();
            
            for (self.front_buffer, self.back_buffer, 0..) |front, back, index| {
                if (!cell_mod.Cell.equals(front, back)) {
                    const y = @as(u16, @intCast(index / self.width));
                    const x = @as(u16, @intCast(index % self.width));
                    
                    try diff_list.append(DiffCell{
                        .x = x,
                        .y = y,
                        .cell = back,
                    });
                }
            }
            
            return try diff_list.toOwnedSlice();
        }
        
        /// Create a viewport into the screen
        pub fn viewport(self: *Screen, rect: rect_mod.Rect) Viewport {
            return Viewport{
                .screen = self,
                .rect = rect,
            };
        }
    };
    
    /// Diff cell structure
    pub const DiffCell = struct {
        x: u16,
        y: u16,
        cell: cell_mod.Cell,
    };
    
    /// Viewport structure
    pub const Viewport = struct {
        screen: *Screen,
        rect: rect_mod.Rect,
        
        /// Set cell relative to viewport
        pub fn set_cell(self: *Viewport, x: u16, y: u16, cell: cell_mod.Cell) void {
            const abs_x = self.rect.x + x;
            const abs_y = self.rect.y + y;
            
            if (x < self.rect.width and y < self.rect.height) {
                self.screen.set_cell(abs_x, abs_y, cell);
            }
        }
    };

// ╚══════════╝