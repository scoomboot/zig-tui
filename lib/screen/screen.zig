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
    

// ╚════════════════════════════════════════════════════════════════════════════════════════╝