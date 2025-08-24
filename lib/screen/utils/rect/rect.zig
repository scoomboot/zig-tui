// rect.zig — Rectangle utilities for layout and positioning
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══ PACK ══╗

    const std = @import("std");

// ╚══════════╝

// ╔══ CORE ══╗

    /// Rectangle structure
    pub const Rect = struct {
        x: u16,
        y: u16,
        width: u16,
        height: u16,
        
        /// Create rectangle with position and size
        pub fn new(x: u16, y: u16, width: u16, height: u16) Rect {
            return Rect{
                .x = x,
                .y = y,
                .width = width,
                .height = height,
            };
        }
        
        /// Create rectangle from two points
        pub fn from_points(x1: u16, y1: u16, x2: u16, y2: u16) Rect {
            const x = @min(x1, x2);
            const y = @min(y1, y2);
            const width = if (x2 > x1) x2 - x1 else x1 - x2;
            const height = if (y2 > y1) y2 - y1 else y1 - y2;
            
            return Rect{
                .x = x,
                .y = y,
                .width = width,
                .height = height,
            };
        }
        
        /// Get right edge coordinate
        pub fn right(self: Rect) u16 {
            return self.x + self.width;
        }
        
        /// Get bottom edge coordinate
        pub fn bottom(self: Rect) u16 {
            return self.y + self.height;
        }
        
        /// Get center x coordinate
        pub fn center_x(self: Rect) u16 {
            return self.x + self.width / 2;
        }
        
        /// Get center y coordinate
        pub fn center_y(self: Rect) u16 {
            return self.y + self.height / 2;
        }
        
        /// Get area of rectangle
        pub fn area(self: Rect) u32 {
            return @as(u32, self.width) * @as(u32, self.height);
        }
        
        /// Check if rectangle is empty
        pub fn is_empty(self: Rect) bool {
            return self.width == 0 or self.height == 0;
        }
        
        /// Check if point is inside rectangle
        pub fn contains_point(self: Rect, px: u16, py: u16) bool {
            return px >= self.x and px < self.right() and
                   py >= self.y and py < self.bottom();
        }
        
        /// Check if rectangle contains another rectangle
        pub fn contains_rect(self: Rect, other: Rect) bool {
            return other.x >= self.x and 
                   other.y >= self.y and
                   other.right() <= self.right() and
                   other.bottom() <= self.bottom();
        }
        
        /// Check if rectangle intersects with another
        pub fn intersects(self: Rect, other: Rect) bool {
            return self.x < other.right() and
                   self.right() > other.x and
                   self.y < other.bottom() and
                   self.bottom() > other.y;
        }
        
        /// Get intersection of two rectangles
        pub fn intersection(self: Rect, other: Rect) ?Rect {
            if (!self.intersects(other)) return null;
            
            const x = @max(self.x, other.x);
            const y = @max(self.y, other.y);
            const right_edge = @min(self.right(), other.right());
            const bottom_edge = @min(self.bottom(), other.bottom());
            
            return Rect{
                .x = x,
                .y = y,
                .width = right_edge - x,
                .height = bottom_edge - y,
            };
        }
        
        /// Get union of two rectangles
        pub fn @"union"(self: Rect, other: Rect) Rect {
            const x = @min(self.x, other.x);
            const y = @min(self.y, other.y);
            const right_edge = @max(self.right(), other.right());
            const bottom_edge = @max(self.bottom(), other.bottom());
            
            return Rect{
                .x = x,
                .y = y,
                .width = right_edge - x,
                .height = bottom_edge - y,
            };
        }
        
        /// Inflate rectangle by given amounts
        pub fn inflate(self: Rect, dx: i16, dy: i16) Rect {
            const new_x = if (dx < 0 and @abs(dx) > self.x) 
                0 
            else 
                @as(u16, @intCast(@as(i32, self.x) - dx));
            
            const new_y = if (dy < 0 and @abs(dy) > self.y) 
                0 
            else 
                @as(u16, @intCast(@as(i32, self.y) - dy));
            
            const new_width = @as(u16, @intCast(@max(0, @as(i32, self.width) + 2 * dx)));
            const new_height = @as(u16, @intCast(@max(0, @as(i32, self.height) + 2 * dy)));
            
            return Rect{
                .x = new_x,
                .y = new_y,
                .width = new_width,
                .height = new_height,
            };
        }
        
        /// Translate rectangle by offset
        pub fn translate(self: Rect, dx: i16, dy: i16) Rect {
            const new_x = if (dx < 0 and @abs(dx) > self.x)
                0
            else
                @as(u16, @intCast(@as(i32, self.x) + dx));
            
            const new_y = if (dy < 0 and @abs(dy) > self.y)
                0
            else
                @as(u16, @intCast(@as(i32, self.y) + dy));
            
            return Rect{
                .x = new_x,
                .y = new_y,
                .width = self.width,
                .height = self.height,
            };
        }
        
        /// Split rectangle horizontally
        pub fn split_horizontal(self: Rect, at: u16) struct { top: Rect, bottom: Rect } {
            const split_y = @min(at, self.height);
            
            return .{
                .top = Rect{
                    .x = self.x,
                    .y = self.y,
                    .width = self.width,
                    .height = split_y,
                },
                .bottom = Rect{
                    .x = self.x,
                    .y = self.y + split_y,
                    .width = self.width,
                    .height = self.height - split_y,
                },
            };
        }
        
        /// Split rectangle vertically
        pub fn split_vertical(self: Rect, at: u16) struct { left: Rect, right: Rect } {
            const split_x = @min(at, self.width);
            
            return .{
                .left = Rect{
                    .x = self.x,
                    .y = self.y,
                    .width = split_x,
                    .height = self.height,
                },
                .right = Rect{
                    .x = self.x + split_x,
                    .y = self.y,
                    .width = self.width - split_x,
                    .height = self.height,
                },
            };
        }
        
        /// Check equality
        pub fn equals(self: Rect, other: Rect) bool {
            return self.x == other.x and
                   self.y == other.y and
                   self.width == other.width and
                   self.height == other.height;
        }
    };

// ╚══════════╝