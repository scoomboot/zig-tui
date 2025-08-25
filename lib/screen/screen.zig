// screen.zig — Screen buffer implementation and management
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════════╗

    const std = @import("std");
    const cell_mod = @import("utils/cell/cell.zig");
    const rect_mod = @import("utils/rect/rect.zig");
    const terminal_mod = @import("../terminal/terminal.zig");

// ╚════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════════╗

    pub const ResizeMode = enum {
        preserve_content,  // Keep existing content in new buffer
        clear_content,     // Clear buffer after resize
        scale_content,     // Attempt to scale content (future enhancement)
    };

    pub const ScreenResizeError = error{
        AllocationFailed,
        InvalidDimensions,
        ResizeInProgress,
    };

    pub const Size = struct {
        cols: u16,
        rows: u16,
        
        pub fn init(cols: u16, rows: u16) Size {
            return Size{ .cols = cols, .rows = rows };
        }
    };

// ╚════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════════╗

    /// Screen buffer structure
    pub const Screen = struct {
        allocator: std.mem.Allocator,
        width: u16,
        height: u16,
        front_buffer: []cell_mod.Cell,
        back_buffer: []cell_mod.Cell,
        
        // Resize handling and thread safety
        resize_mutex: std.Thread.Mutex,
        is_resizing: bool,
        terminal_ref: ?*terminal_mod.Terminal,
        needs_full_redraw: bool,
        registry_id: ?u64,
        
        // Multi-screen support fields
        parent_manager: ?*anyopaque, // ScreenManager reference (using anyopaque to avoid circular deps)
        viewport_bounds: ?rect_mod.Rect, // Viewport within parent terminal/manager
        is_managed: bool, // Whether screen is managed by a ScreenManager
        
        /// Initialize screen with given dimensions.
        ///
        /// __Parameters__
        ///
        /// - `allocator`: Memory allocator for screen buffers
        ///
        /// __Return__
        ///
        /// - Initialized Screen with default 80x24 dimensions or error
        pub fn init(allocator: std.mem.Allocator) !Screen {
            return init_with_size(allocator, 80, 24);
        }
        
        /// Initialize screen with terminal size detection.
        ///
        /// __Parameters__
        ///
        /// - `allocator`: Memory allocator for screen buffers
        /// - `terminal`: Terminal instance for size detection and resize events
        ///
        /// __Return__
        ///
        /// - Initialized Screen with terminal dimensions or error
        pub fn initWithTerminal(allocator: std.mem.Allocator, terminal: *terminal_mod.Terminal) !Screen {
            const size = try terminal.getSize();
            var screen = try init_with_size(allocator, size.cols, size.rows);
            screen.terminal_ref = terminal;
            
            // Register with terminal's callback registry for resize events
            const registry = terminal.getCallbackRegistry();
            screen.registry_id = try registry.register(
                @as(*anyopaque, @ptrCast(terminal)),
                @as(*anyopaque, @ptrCast(&screen))
            );
            
            return screen;
        }
        
        /// Initialize screen with specific size.
        ///
        /// __Parameters__
        ///
        /// - `allocator`: Memory allocator for screen buffers
        /// - `width`: Screen width in columns
        /// - `height`: Screen height in rows
        ///
        /// __Return__
        ///
        /// - Initialized Screen with specified dimensions or error
        pub fn init_with_size(allocator: std.mem.Allocator, width: u16, height: u16) !Screen {
            // Performance optimization: Calculate buffer size once, use for both allocations
            const buffer_size = @as(usize, width) * @as(usize, height);
            
            const front = try allocator.alloc(cell_mod.Cell, buffer_size);
            errdefer allocator.free(front);
            
            const back = try allocator.alloc(cell_mod.Cell, buffer_size);
            errdefer allocator.free(back);
            
            // Performance optimization: Use memset-style initialization for better cache usage
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
                
                // Initialize resize handling fields
                .resize_mutex = .{},
                .is_resizing = false,
                .terminal_ref = null,
                .needs_full_redraw = true,
                .registry_id = null,
                
                // Initialize multi-screen support fields
                .parent_manager = null,
                .viewport_bounds = null,
                .is_managed = false,
            };
        }
        
        /// Deinitialize screen.
        ///
        /// __Parameters__
        ///
        /// - `self`: Screen instance to deinitialize
        pub fn deinit(self: *Screen) void {
            // Unregister from callback registry if registered
            if (self.registry_id) |id| {
                if (self.terminal_ref) |terminal| {
                    const registry = terminal.getCallbackRegistry();
                    registry.unregister(id) catch {
                        // Silently ignore unregister errors during cleanup
                        // This ensures deinit always succeeds
                    };
                }
            }
            
            // Free screen buffers in reverse order of allocation
            self.allocator.free(self.front_buffer);
            self.allocator.free(self.back_buffer);
        }
        
        /// Resize screen buffers.
        ///
        /// __Parameters__
        ///
        /// - `self`: Screen instance to resize
        /// - `width`: New width in columns
        /// - `height`: New height in rows
        ///
        /// __Return__
        ///
        /// - Error if allocation fails
        pub fn resize(self: *Screen, width: u16, height: u16) !void {
            // Performance optimization: Single calculation for buffer size
            const new_size = @as(usize, width) * @as(usize, height);
            
            // Allocate new buffers before freeing old ones for safety
            const new_front = try self.allocator.alloc(cell_mod.Cell, new_size);
            errdefer self.allocator.free(new_front);
            
            const new_back = try self.allocator.alloc(cell_mod.Cell, new_size);
            errdefer self.allocator.free(new_back);
            
            // Initialize new buffers with empty cells
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
        
        /// Handle terminal resize event with cols/rows parameters (for CallbackRegistry).
        ///
        /// __Parameters__
        ///
        /// - `self`: Screen instance to resize
        /// - `new_cols`: New width in columns
        /// - `new_rows`: New height in rows
        /// - `mode`: Content preservation mode during resize
        ///
        /// __Return__
        ///
        /// - Error if resize fails or is already in progress
        pub fn handleResize(self: *Screen, new_cols: u16, new_rows: u16, mode: ResizeMode) !void {
            const new_size = Size{ .cols = new_cols, .rows = new_rows };
            return self.handleResizeWithSize(new_size, mode);
        }
        
        /// Handle terminal resize event with Size parameter.
        ///
        /// __Parameters__
        ///
        /// - `self`: Screen instance to resize
        /// - `new_size`: New terminal dimensions
        /// - `mode`: Content preservation mode during resize
        ///
        /// __Return__
        ///
        /// - Error if resize fails or is already in progress
        pub fn handleResizeWithSize(self: *Screen, new_size: Size, mode: ResizeMode) !void {
            // Check if this screen is managed by a ScreenManager
            if (self.is_managed and self.parent_manager != null) {
                // If managed, delegate to parent ScreenManager for coordinated resize
                // The ScreenManager will handle layout calculation and coordinate all screens
                const ScreenManager = @import("utils/screen_manager/screen_manager.zig").ScreenManager;
                const manager = @as(*ScreenManager, @ptrCast(@alignCast(self.parent_manager.?)));
                try manager.handleResize(new_size.cols, new_size.rows, mode);
                return;
            }
            
            // Independent screen: handle resize directly
            try self.handleResizeDirectly(new_size, mode);
        }
        
        /// Handle resize directly without ScreenManager coordination.
        ///
        /// This method performs the actual resize operation for independent screens
        /// or when called by a ScreenManager for coordinated multi-screen resize.
        ///
        /// __Parameters__
        ///
        /// - `self`: Screen instance to resize
        /// - `new_size`: New screen dimensions
        /// - `mode`: Content preservation mode during resize
        ///
        /// __Return__
        ///
        /// - Error if resize fails or is already in progress
        pub fn handleResizeDirectly(self: *Screen, new_size: Size, mode: ResizeMode) !void {
            // Thread safety: Acquire mutex for entire resize operation
            self.resize_mutex.lock();
            defer self.resize_mutex.unlock();
            
            // Prevent concurrent resize operations
            if (self.is_resizing) {
                return ScreenResizeError.ResizeInProgress;
            }
            self.is_resizing = true;
            defer self.is_resizing = false;
            
            // Validate new dimensions before allocation
            if (new_size.cols == 0 or new_size.rows == 0) {
                return ScreenResizeError.InvalidDimensions;
            }
            
            // Performance optimization: Skip resize if dimensions unchanged
            if (new_size.cols == self.width and new_size.rows == self.height) {
                return;
            }
            
            try self.reallocateBuffers(new_size, mode);
            
            // Update viewport bounds if managed
            if (self.is_managed) {
                self.viewport_bounds = rect_mod.Rect.init(0, 0, new_size.cols, new_size.rows);
            }
        }
        
        /// Reallocate screen buffers for new size with content preservation.
        ///
        /// __Parameters__
        ///
        /// - `self`: Screen instance
        /// - `new_size`: New dimensions for buffers
        /// - `mode`: Content preservation mode
        ///
        /// __Return__
        ///
        /// - Error if allocation fails
        fn reallocateBuffers(self: *Screen, new_size: Size, mode: ResizeMode) !void {
            // Performance optimization: Single buffer size calculation
            const new_buffer_size = @as(usize, new_size.cols) * @as(usize, new_size.rows);
            
            // Allocate new buffers before releasing old ones for safety
            const new_front = try self.allocator.alloc(cell_mod.Cell, new_buffer_size);
            errdefer self.allocator.free(new_front);
            
            const new_back = try self.allocator.alloc(cell_mod.Cell, new_buffer_size);
            errdefer self.allocator.free(new_back);
            
            // Handle content preservation based on mode
            switch (mode) {
                .preserve_content => try self.copyExistingContent(new_front, new_size),
                .clear_content => {
                    for (new_front) |*cell| cell.* = cell_mod.Cell.empty();
                },
                .scale_content => {
                    // Future enhancement - for now, clear
                    for (new_front) |*cell| cell.* = cell_mod.Cell.empty();
                },
            }
            
            // Initialize back buffer
            for (new_back) |*cell| {
                cell.* = cell_mod.Cell.empty();
            }
            
            // Replace old buffers
            self.allocator.free(self.front_buffer);
            self.allocator.free(self.back_buffer);
            self.front_buffer = new_front;
            self.back_buffer = new_back;
            self.width = new_size.cols;
            self.height = new_size.rows;
            
            // Mark for full redraw
            self.needs_full_redraw = true;
        }
        
        /// Copy existing content to new buffer with size preservation.
        ///
        /// __Parameters__
        ///
        /// - `self`: Screen instance with existing content
        /// - `new_buffer`: Target buffer for content copy
        /// - `new_size`: Dimensions of new buffer
        ///
        /// __Return__
        ///
        /// - Error if copy operation fails
        fn copyExistingContent(self: *Screen, new_buffer: []cell_mod.Cell, new_size: Size) !void {
            // Initialize all cells to empty first for clean slate
            for (new_buffer) |*cell| {
                cell.* = cell_mod.Cell.empty();
            }
            
            // Performance optimization: Calculate copy bounds once
            const copy_width = @min(self.width, new_size.cols);
            const copy_height = @min(self.height, new_size.rows);
            
            // Performance optimization: Row-major iteration for cache locality
            var row: u16 = 0;
            while (row < copy_height) : (row += 1) {
                var col: u16 = 0;
                while (col < copy_width) : (col += 1) {
                    const old_idx = @as(usize, row) * @as(usize, self.width) + @as(usize, col);
                    const new_idx = @as(usize, row) * @as(usize, new_size.cols) + @as(usize, col);
                    new_buffer[new_idx] = self.front_buffer[old_idx];
                }
            }
        }
        
        /// Get cell at position.
        ///
        /// __Parameters__
        ///
        /// - `self`: Screen instance
        /// - `x`: Column position
        /// - `y`: Row position
        ///
        /// __Return__
        ///
        /// - Pointer to cell at position or null if out of bounds
        pub inline fn get_cell(self: *Screen, x: u16, y: u16) ?*cell_mod.Cell {
            // Performance optimization: Inline for hot path
            if (x >= self.width or y >= self.height) return null;
            
            const index = @as(usize, y) * @as(usize, self.width) + @as(usize, x);
            return &self.back_buffer[index];
        }
        
        /// Set cell at position.
        ///
        /// __Parameters__
        ///
        /// - `self`: Screen instance
        /// - `x`: Column position
        /// - `y`: Row position
        /// - `cell`: Cell data to set
        pub inline fn set_cell(self: *Screen, x: u16, y: u16, cell: cell_mod.Cell) void {
            // Performance optimization: Inline for hot path
            if (x >= self.width or y >= self.height) return;
            
            const index = @as(usize, y) * @as(usize, self.width) + @as(usize, x);
            self.back_buffer[index] = cell;
        }
        
        /// Clear screen buffer.
        ///
        /// __Parameters__
        ///
        /// - `self`: Screen instance to clear
        pub fn clear(self: *Screen) void {
            // Performance optimization: Memset-style clear for cache efficiency
            for (self.back_buffer) |*cell| {
                cell.* = cell_mod.Cell.empty();
            }
        }
        
        /// Swap front and back buffers.
        ///
        /// __Parameters__
        ///
        /// - `self`: Screen instance
        pub inline fn swap_buffers(self: *Screen) void {
            // Performance optimization: Inline pointer swap for double buffering
            const temp = self.front_buffer;
            self.front_buffer = self.back_buffer;
            self.back_buffer = temp;
        }
        
        /// Get differences between front and back buffers.
        ///
        /// __Parameters__
        ///
        /// - `self`: Screen instance
        /// - `allocator`: Allocator for diff list
        ///
        /// __Return__
        ///
        /// - Array of cells that differ between buffers
        pub fn get_diff(self: *Screen, allocator: std.mem.Allocator) ![]const DiffCell {
            var diff_list = std.ArrayList(DiffCell).init(allocator);
            defer diff_list.deinit();
            
            // Performance optimization: Single pass comparison with index tracking
            for (self.front_buffer, self.back_buffer, 0..) |front, back, index| {
                if (!cell_mod.Cell.equals(front, back)) {
                    // Performance optimization: Compute coordinates from linear index
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
        
        /// Get current screen dimensions.
        ///
        /// __Parameters__
        ///
        /// - `self`: Screen instance
        ///
        /// __Return__
        ///
        /// - Current screen size in columns and rows
        pub inline fn getSize(self: *Screen) Size {
            // Performance optimization: Inline for frequent access
            return Size{ .cols = self.width, .rows = self.height };
        }

        /// Check if screen is currently being resized.
        ///
        /// __Parameters__
        ///
        /// - `self`: Screen instance
        ///
        /// __Return__
        ///
        /// - true if resize operation is in progress
        pub inline fn isResizing(self: *Screen) bool {
            // Performance optimization: Inline for status checks
            return self.is_resizing;
        }

        /// Force a full screen redraw after resize.
        ///
        /// __Parameters__
        ///
        /// - `self`: Screen instance
        pub inline fn markForFullRedraw(self: *Screen) void {
            // Performance optimization: Inline for flag setting
            self.needs_full_redraw = true;
        }
        
        // ┌──────────────────────────── Multi-Screen Viewport Support ────────────────────────────┐
        
            /// Set parent screen manager.
            ///
            /// Associates this screen with a ScreenManager for multi-screen coordination.
            /// This enables viewport management and coordinated resize handling.
            ///
            /// __Parameters__
            ///
            /// - `self`: Screen instance
            /// - `manager`: ScreenManager instance to associate with
            pub fn setParentManager(self: *Screen, manager: *anyopaque) void {
                self.parent_manager = manager;
                self.is_managed = true;
            }
            
            /// Clear parent screen manager.
            ///
            /// Removes association with ScreenManager, making this screen
            /// independent again.
            ///
            /// __Parameters__
            ///
            /// - `self`: Screen instance
            pub fn clearParentManager(self: *Screen) void {
                self.parent_manager = null;
                self.is_managed = false;
                self.viewport_bounds = null;
            }
            
            /// Set viewport bounds within parent coordinate system.
            ///
            /// Defines the region within the parent terminal or manager
            /// that this screen should occupy. Used by ScreenManager for
            /// layout coordination.
            ///
            /// __Parameters__
            ///
            /// - `self`: Screen instance
            /// - `bounds`: Viewport bounds in parent coordinates
            pub fn setViewportBounds(self: *Screen, bounds: rect_mod.Rect) void {
                self.viewport_bounds = bounds;
            }
            
            /// Get viewport bounds within parent coordinate system.
            ///
            /// Returns the region assigned to this screen by its parent
            /// manager, or null if not managed.
            ///
            /// __Parameters__
            ///
            /// - `self`: Screen instance
            ///
            /// __Return__
            ///
            /// - `?rect_mod.Rect`: Viewport bounds or null if not managed
            pub fn getViewportBounds(self: *Screen) ?rect_mod.Rect {
                return self.viewport_bounds;
            }
            
            /// Check if screen is managed by a ScreenManager.
            ///
            /// Returns true if this screen is currently managed by a
            /// ScreenManager for multi-screen coordination.
            ///
            /// __Parameters__
            ///
            /// - `self`: Screen instance
            ///
            /// __Return__
            ///
            /// - `bool`: True if managed, false if independent
            pub inline fn isManaged(self: *Screen) bool {
                return self.is_managed;
            }
            
            /// Get screen dimensions within viewport constraints.
            ///
            /// Returns the effective size of the screen, considering viewport
            /// bounds if managed by a ScreenManager.
            ///
            /// __Parameters__
            ///
            /// - `self`: Screen instance
            ///
            /// __Return__
            ///
            /// - `Size`: Effective screen dimensions
            pub fn getEffectiveSize(self: *Screen) Size {
                if (self.viewport_bounds) |bounds| {
                    return Size{
                        .cols = bounds.width,
                        .rows = bounds.height,
                    };
                }
                return Size{
                    .cols = self.width,
                    .rows = self.height,
                };
            }
            
            /// Set cell with viewport-aware coordinates.
            ///
            /// Sets a cell using coordinates relative to the screen's viewport.
            /// If the screen is managed, coordinates are relative to viewport bounds.
            ///
            /// __Parameters__
            ///
            /// - `self`: Screen instance
            /// - `x`: Column position within viewport
            /// - `y`: Row position within viewport
            /// - `cell`: Cell data to set
            pub inline fn setViewportCell(self: *Screen, x: u16, y: u16, cell: cell_mod.Cell) void {
                if (self.viewport_bounds) |bounds| {
                    // Managed screen: translate viewport coordinates to screen coordinates
                    const screen_x = x;
                    const screen_y = y;
                    
                    // Bounds check within viewport
                    if (screen_x < bounds.width and screen_y < bounds.height) {
                        self.set_cell(screen_x, screen_y, cell);
                    }
                } else {
                    // Independent screen: direct coordinate mapping
                    self.set_cell(x, y, cell);
                }
            }
            
            /// Get cell with viewport-aware coordinates.
            ///
            /// Gets a cell using coordinates relative to the screen's viewport.
            /// If the screen is managed, coordinates are relative to viewport bounds.
            ///
            /// __Parameters__
            ///
            /// - `self`: Screen instance
            /// - `x`: Column position within viewport
            /// - `y`: Row position within viewport
            ///
            /// __Return__
            ///
            /// - `?*cell_mod.Cell`: Pointer to cell or null if out of bounds
            pub inline fn getViewportCell(self: *Screen, x: u16, y: u16) ?*cell_mod.Cell {
                if (self.viewport_bounds) |bounds| {
                    // Managed screen: translate viewport coordinates to screen coordinates
                    const screen_x = x;
                    const screen_y = y;
                    
                    // Bounds check within viewport
                    if (screen_x < bounds.width and screen_y < bounds.height) {
                        return self.get_cell(screen_x, screen_y);
                    }
                    return null;
                } else {
                    // Independent screen: direct coordinate mapping
                    return self.get_cell(x, y);
                }
            }
            
            /// Create a viewport-aware drawing context.
            ///
            /// Returns a drawing context that automatically handles coordinate
            /// translation for managed screens or provides direct access for
            /// independent screens.
            ///
            /// __Parameters__
            ///
            /// - `self`: Screen instance
            ///
            /// __Return__
            ///
            /// - `ViewportContext`: Context for viewport-aware drawing
            pub fn getViewportContext(self: *Screen) ViewportContext {
                return ViewportContext{
                    .screen = self,
                    .viewport_bounds = self.viewport_bounds,
                };
            }
        
        // └──────────────────────────────────────────────────────────────────┘
        
        /// Create a viewport into the screen.
        ///
        /// __Parameters__
        ///
        /// - `self`: Screen instance
        /// - `rect`: Rectangle defining viewport bounds
        ///
        /// __Return__
        ///
        /// - Viewport structure for constrained screen access
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
    
    /// Viewport-aware drawing context for multi-screen support.
    ///
    /// Provides drawing operations that automatically handle coordinate
    /// translation for managed screens. This context enables seamless
    /// drawing operations regardless of whether a screen is independent
    /// or managed by a ScreenManager.
    pub const ViewportContext = struct {
        screen: *Screen,
        viewport_bounds: ?rect_mod.Rect,
        
        /// Set cell using context-aware coordinates.
        ///
        /// Automatically translates coordinates based on whether the screen
        /// is managed and has viewport bounds defined.
        ///
        /// __Parameters__
        ///
        /// - `self`: ViewportContext instance
        /// - `x`: Column position (context-relative)
        /// - `y`: Row position (context-relative)
        /// - `cell`: Cell data to set
        pub inline fn setCell(self: *ViewportContext, x: u16, y: u16, cell: cell_mod.Cell) void {
            if (self.viewport_bounds) |bounds| {
                // Managed screen with viewport bounds
                if (x < bounds.width and y < bounds.height) {
                    self.screen.set_cell(x, y, cell);
                }
            } else {
                // Independent screen or no viewport bounds
                self.screen.set_cell(x, y, cell);
            }
        }
        
        /// Get cell using context-aware coordinates.
        ///
        /// Automatically translates coordinates based on whether the screen
        /// is managed and has viewport bounds defined.
        ///
        /// __Parameters__
        ///
        /// - `self`: ViewportContext instance
        /// - `x`: Column position (context-relative)
        /// - `y`: Row position (context-relative)
        ///
        /// __Return__
        ///
        /// - `?*cell_mod.Cell`: Pointer to cell or null if out of bounds
        pub inline fn getCell(self: *ViewportContext, x: u16, y: u16) ?*cell_mod.Cell {
            if (self.viewport_bounds) |bounds| {
                // Managed screen with viewport bounds
                if (x < bounds.width and y < bounds.height) {
                    return self.screen.get_cell(x, y);
                }
                return null;
            } else {
                // Independent screen or no viewport bounds
                return self.screen.get_cell(x, y);
            }
        }
        
        /// Clear the drawable area within the context.
        ///
        /// Clears all cells within the current context bounds, respecting
        /// viewport constraints for managed screens.
        ///
        /// __Parameters__
        ///
        /// - `self`: ViewportContext instance
        pub fn clear(self: *ViewportContext) void {
            const effective_size = self.getEffectiveSize();
            
            var y: u16 = 0;
            while (y < effective_size.rows) : (y += 1) {
                var x: u16 = 0;
                while (x < effective_size.cols) : (x += 1) {
                    self.setCell(x, y, cell_mod.Cell.empty());
                }
            }
        }
        
        /// Get effective drawing size for this context.
        ///
        /// Returns the available drawing area, considering viewport bounds
        /// for managed screens or full screen size for independent screens.
        ///
        /// __Parameters__
        ///
        /// - `self`: ViewportContext instance
        ///
        /// __Return__
        ///
        /// - `Size`: Available drawing dimensions
        pub fn getEffectiveSize(self: *ViewportContext) Size {
            if (self.viewport_bounds) |bounds| {
                return Size{
                    .cols = bounds.width,
                    .rows = bounds.height,
                };
            } else {
                return Size{
                    .cols = self.screen.width,
                    .rows = self.screen.height,
                };
            }
        }
        
        /// Check if coordinates are within drawable bounds.
        ///
        /// Validates that the given coordinates are within the effective
        /// drawing area of this context.
        ///
        /// __Parameters__
        ///
        /// - `self`: ViewportContext instance
        /// - `x`: Column position to test
        /// - `y`: Row position to test
        ///
        /// __Return__
        ///
        /// - `bool`: True if coordinates are within bounds
        pub inline fn isWithinBounds(self: *ViewportContext, x: u16, y: u16) bool {
            const effective_size = self.getEffectiveSize();
            return x < effective_size.cols and y < effective_size.rows;
        }
        
        /// Fill a rectangular region with a cell.
        ///
        /// Fills the specified rectangle with the given cell data,
        /// respecting viewport bounds.
        ///
        /// __Parameters__
        ///
        /// - `self`: ViewportContext instance
        /// - `rect`: Rectangle to fill
        /// - `cell`: Cell data to fill with
        pub fn fillRect(self: *ViewportContext, rect: rect_mod.Rect, cell: cell_mod.Cell) void {
            const effective_size = self.getEffectiveSize();
            
            // Clip rectangle to context bounds
            const start_x = @min(rect.x, effective_size.cols);
            const start_y = @min(rect.y, effective_size.rows);
            const end_x = @min(rect.x + rect.width, effective_size.cols);
            const end_y = @min(rect.y + rect.height, effective_size.rows);
            
            var y = start_y;
            while (y < end_y) : (y += 1) {
                var x = start_x;
                while (x < end_x) : (x += 1) {
                    self.setCell(x, y, cell);
                }
            }
        }
        
        /// Draw a horizontal line.
        ///
        /// Draws a horizontal line at the specified position using the
        /// given cell data.
        ///
        /// __Parameters__
        ///
        /// - `self`: ViewportContext instance
        /// - `start_x`: Starting column
        /// - `y`: Row position
        /// - `length`: Line length
        /// - `cell`: Cell data for line
        pub fn drawHorizontalLine(self: *ViewportContext, start_x: u16, y: u16, length: u16, cell: cell_mod.Cell) void {
            const effective_size = self.getEffectiveSize();
            
            if (y >= effective_size.rows) return;
            
            const end_x = @min(start_x + length, effective_size.cols);
            var x = start_x;
            while (x < end_x) : (x += 1) {
                self.setCell(x, y, cell);
            }
        }
        
        /// Draw a vertical line.
        ///
        /// Draws a vertical line at the specified position using the
        /// given cell data.
        ///
        /// __Parameters__
        ///
        /// - `self`: ViewportContext instance
        /// - `x`: Column position
        /// - `start_y`: Starting row
        /// - `length`: Line length
        /// - `cell`: Cell data for line
        pub fn drawVerticalLine(self: *ViewportContext, x: u16, start_y: u16, length: u16, cell: cell_mod.Cell) void {
            const effective_size = self.getEffectiveSize();
            
            if (x >= effective_size.cols) return;
            
            const end_y = @min(start_y + length, effective_size.rows);
            var y = start_y;
            while (y < end_y) : (y += 1) {
                self.setCell(x, y, cell);
            }
        }
    };
    

// ╚════════════════════════════════════════════════════════════════════════════════════════╝