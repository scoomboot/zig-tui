// layout.zig — Layout management for widget positioning and sizing
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══ PACK ══╗

    const std = @import("std");
    const widget = @import("../widget/widget.zig");
    const rect_mod = @import("../screen/utils/rect/rect.zig");

// ╚══════════╝

// ╔══ CORE ══╗

    /// Layout direction
    pub const Direction = enum {
        horizontal,
        vertical,
    };
    
    /// Layout alignment
    pub const Alignment = enum {
        start,
        center,
        end,
        stretch,
    };
    
    /// Layout constraint
    pub const Constraint = union(enum) {
        fixed: u16,
        percentage: u8,
        min: u16,
        max: u16,
        weight: f32,
    };
    
    /// Layout interface
    pub const Layout = struct {
        vtable: *const VTable,
        ptr: *anyopaque,
        
        pub const VTable = struct {
            apply: *const fn (ptr: *anyopaque, bounds: rect_mod.Rect, widgets: []widget.Widget) void,
        };
        
        /// Apply layout to widgets
        pub fn apply(self: Layout, bounds: rect_mod.Rect, widgets: []widget.Widget) void {
            self.vtable.apply(self.ptr, bounds, widgets);
        }
    };
    
    /// Linear layout (horizontal or vertical)
    pub const LinearLayout = struct {
        direction: Direction,
        spacing: u16,
        alignment: Alignment,
        constraints: std.ArrayList(Constraint),
        allocator: std.mem.Allocator,
        
        /// Initialize linear layout
        pub fn init(allocator: std.mem.Allocator, direction: Direction) !LinearLayout {
            return LinearLayout{
                .direction = direction,
                .spacing = 0,
                .alignment = .start,
                .constraints = std.ArrayList(Constraint).init(allocator),
                .allocator = allocator,
            };
        }
        
        /// Deinitialize layout
        pub fn deinit(self: *LinearLayout) void {
            self.constraints.deinit();
        }
        
        /// Add constraint
        pub fn add_constraint(self: *LinearLayout, constraint: Constraint) !void {
            try self.constraints.append(constraint);
        }
        
        /// Get layout interface
        pub fn layout(self: *LinearLayout) Layout {
            return Layout{
                .vtable = &linear_vtable,
                .ptr = self,
            };
        }
        
        // VTable implementation
        fn apply_impl(ptr: *anyopaque, bounds: rect_mod.Rect, widgets: []widget.Widget) void {
            const self = @as(*LinearLayout, @ptrCast(@alignCast(ptr)));
            
            if (widgets.len == 0) return;
            
            // Calculate available space
            const total_spacing = self.spacing * @as(u16, @intCast(widgets.len - 1));
            const available = if (self.direction == .horizontal)
                bounds.width - total_spacing
            else
                bounds.height - total_spacing;
            
            // Calculate sizes based on constraints
            var current_pos: u16 = if (self.direction == .horizontal) bounds.x else bounds.y;
            
            for (widgets, 0..) |w, i| {
                const constraint = if (i < self.constraints.items.len)
                    self.constraints.items[i]
                else
                    Constraint{ .weight = 1.0 };
                
                const size = calculate_size(constraint, available);
                
                const widget_bounds = if (self.direction == .horizontal)
                    rect_mod.Rect{
                        .x = current_pos,
                        .y = bounds.y,
                        .width = size,
                        .height = bounds.height,
                    }
                else
                    rect_mod.Rect{
                        .x = bounds.x,
                        .y = current_pos,
                        .width = bounds.width,
                        .height = size,
                    };
                
                w.set_bounds(widget_bounds);
                
                current_pos += size + self.spacing;
            }
        }
        
        fn calculate_size(constraint: Constraint, available: u16) u16 {
            return switch (constraint) {
                .fixed => |size| size,
                .percentage => |pct| @as(u16, @intCast(@as(u32, available) * @as(u32, pct) / 100)),
                .min => |min| @max(min, available),
                .max => |max| @min(max, available),
                .weight => |weight| @as(u16, @intFromFloat(@as(f32, @floatFromInt(available)) * weight)),
            };
        }
        
        const linear_vtable = Layout.VTable{
            .apply = apply_impl,
        };
    };
    
    /// Grid layout
    pub const GridLayout = struct {
        rows: u16,
        columns: u16,
        row_spacing: u16,
        column_spacing: u16,
        
        /// Initialize grid layout
        pub fn init(rows: u16, columns: u16) GridLayout {
            return GridLayout{
                .rows = rows,
                .columns = columns,
                .row_spacing = 0,
                .column_spacing = 0,
            };
        }
        
        /// Get layout interface
        pub fn layout(self: *GridLayout) Layout {
            return Layout{
                .vtable = &grid_vtable,
                .ptr = self,
            };
        }
        
        // VTable implementation
        fn apply_impl(ptr: *anyopaque, bounds: rect_mod.Rect, widgets: []widget.Widget) void {
            const self = @as(*GridLayout, @ptrCast(@alignCast(ptr)));
            
            if (widgets.len == 0) return;
            
            const cell_width = (bounds.width - self.column_spacing * (self.columns - 1)) / self.columns;
            const cell_height = (bounds.height - self.row_spacing * (self.rows - 1)) / self.rows;
            
            for (widgets, 0..) |w, i| {
                const row = @as(u16, @intCast(i / self.columns));
                const col = @as(u16, @intCast(i % self.columns));
                
                if (row >= self.rows) break;
                
                const widget_bounds = rect_mod.Rect{
                    .x = bounds.x + col * (cell_width + self.column_spacing),
                    .y = bounds.y + row * (cell_height + self.row_spacing),
                    .width = cell_width,
                    .height = cell_height,
                };
                
                w.set_bounds(widget_bounds);
            }
        }
        
        const grid_vtable = Layout.VTable{
            .apply = apply_impl,
        };
    };

// ╚══════════╝