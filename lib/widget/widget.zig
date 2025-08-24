// widget.zig — Base widget interface and common widget functionality
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══ PACK ══╗

    const std = @import("std");
    const screen = @import("../screen/screen.zig");
    const event = @import("../event/event.zig");
    const rect_mod = @import("../screen/utils/rect/rect.zig");

// ╚══════════╝

// ╔══ CORE ══╗

    /// Widget interface
    pub const Widget = struct {
        /// Widget vtable for polymorphism
        vtable: *const VTable,
        /// Pointer to widget implementation
        ptr: *anyopaque,
        
        pub const VTable = struct {
            draw: *const fn (ptr: *anyopaque, viewport: *screen.Viewport) void,
            handle_event: *const fn (ptr: *anyopaque, ev: event.Event) bool,
            get_bounds: *const fn (ptr: *anyopaque) rect_mod.Rect,
            set_bounds: *const fn (ptr: *anyopaque, bounds: rect_mod.Rect) void,
        };
        
        /// Draw widget to viewport
        pub fn draw(self: Widget, viewport: *screen.Viewport) void {
            self.vtable.draw(self.ptr, viewport);
        }
        
        /// Handle event, returns true if consumed
        pub fn handle_event(self: Widget, ev: event.Event) bool {
            return self.vtable.handle_event(self.ptr, ev);
        }
        
        /// Get widget bounds
        pub fn get_bounds(self: Widget) rect_mod.Rect {
            return self.vtable.get_bounds(self.ptr);
        }
        
        /// Set widget bounds
        pub fn set_bounds(self: Widget, bounds: rect_mod.Rect) void {
            self.vtable.set_bounds(self.ptr, bounds);
        }
    };
    
    /// Base widget state
    pub const BaseWidget = struct {
        bounds: rect_mod.Rect,
        visible: bool,
        focused: bool,
        enabled: bool,
        
        /// Initialize base widget
        pub fn init() BaseWidget {
            return BaseWidget{
                .bounds = rect_mod.Rect{
                    .x = 0,
                    .y = 0,
                    .width = 0,
                    .height = 0,
                },
                .visible = true,
                .focused = false,
                .enabled = true,
            };
        }
    };
    
    /// Widget container
    pub const Container = struct {
        allocator: std.mem.Allocator,
        base: BaseWidget,
        children: std.ArrayList(Widget),
        
        /// Initialize container
        pub fn init(allocator: std.mem.Allocator) !Container {
            return Container{
                .allocator = allocator,
                .base = BaseWidget.init(),
                .children = std.ArrayList(Widget).init(allocator),
            };
        }
        
        /// Deinitialize container
        pub fn deinit(self: *Container) void {
            self.children.deinit();
        }
        
        /// Add child widget
        pub fn add_child(self: *Container, child: Widget) !void {
            try self.children.append(child);
        }
        
        /// Remove child widget
        pub fn remove_child(self: *Container, index: usize) void {
            _ = self.children.orderedRemove(index);
        }
        
        /// Get widget interface
        pub fn widget(self: *Container) Widget {
            return Widget{
                .vtable = &container_vtable,
                .ptr = self,
            };
        }
        
        // VTable implementation
        fn draw_impl(ptr: *anyopaque, viewport: *screen.Viewport) void {
            const self = @as(*Container, @ptrCast(@alignCast(ptr)));
            
            // Draw children
            for (self.children.items) |child| {
                child.draw(viewport);
            }
        }
        
        fn handle_event_impl(ptr: *anyopaque, ev: event.Event) bool {
            const self = @as(*Container, @ptrCast(@alignCast(ptr)));
            
            // Pass event to children
            for (self.children.items) |child| {
                if (child.handle_event(ev)) {
                    return true;
                }
            }
            
            return false;
        }
        
        fn get_bounds_impl(ptr: *anyopaque) rect_mod.Rect {
            const self = @as(*Container, @ptrCast(@alignCast(ptr)));
            return self.base.bounds;
        }
        
        fn set_bounds_impl(ptr: *anyopaque, bounds: rect_mod.Rect) void {
            const self = @as(*Container, @ptrCast(@alignCast(ptr)));
            self.base.bounds = bounds;
        }
        
        const container_vtable = Widget.VTable{
            .draw = draw_impl,
            .handle_event = handle_event_impl,
            .get_bounds = get_bounds_impl,
            .set_bounds = set_bounds_impl,
        };
    };

// ╚══════════╝