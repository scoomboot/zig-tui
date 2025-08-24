<!--------------------------------- SUMMARY --------------------------------->

# Issue #052: Integrate resize detection with screen buffer system

Integrate the newly implemented terminal resize detection with the screen buffer system to enable responsive layouts and dynamic screen buffer reallocation.

<!--------------------------------------------------------------------------->

<!-------------------------------- DESCRIPTION -------------------------------->

Issue #007 implemented comprehensive terminal size detection and resize event handling, but the screen buffer system still hardcodes 80x24 dimensions and has no mechanism to respond to terminal resize events. This creates a disconnect where resize events are detected but the screen system cannot adapt to new dimensions.

<!--------------------------------------------------------------------------->

<!---------------------------- CURRENT PROBLEM ------------------------------>

- `screen.zig:29` hardcodes `init_with_size(allocator, 80, 24)`
- No mechanism to reallocate screen buffers when terminal is resized
- Screen rendering will be clipped or incorrect when terminal size changes
- Layout system cannot respond to available screen space changes

<!--------------------------------------------------------------------------->  

<!--------------------------- ACCEPTANCE CRITERIA -------------------------->

## Acceptance Criteria
- [ ] Remove hardcoded 80x24 dimensions from screen initialization
- [ ] Add dynamic screen buffer reallocation on resize events
- [ ] Integrate with terminal resize callback system from Issue #007
- [ ] Implement efficient buffer resizing (preserve content when possible)
- [ ] Add screen resize validation and error handling
- [ ] Update screen tests to cover resize scenarios
- [ ] Ensure thread safety for concurrent resize operations
- [ ] Add resize event propagation to higher-level components
- [ ] Follow MCS style guidelines
- [ ] Performance: < 50ms for screen resize operation

<!--------------------------------------------------------------------------->  

<!-------------------------------- DEPENDENCIES -------------------------------->

## Dependencies
- Issue #007 (Add terminal size detection) - COMPLETED
- Issue #009 (Implement screen buffer) - Required for buffer management

<!--------------------------------------------------------------------------->  

<!-------------------------- IMPLEMENTATION NOTES --------------------------->  

## Implementation Notes
```zig
// screen.zig additions — Screen resize handling
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

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

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    // Extension to Screen struct
    pub const Screen = struct {
        // ... existing fields ...
        resize_mutex: std.Thread.Mutex,
        is_resizing: bool,
        terminal_ref: ?*Terminal,
        
        // ┌──────────────────────────── Initialization ────────────────────────────┐

            /// Initialize screen with terminal size detection
            pub fn initWithTerminal(allocator: std.mem.Allocator, terminal: *Terminal) !Screen {
                const size = try terminal.getSize();
                var screen = try Screen.init_with_size(allocator, size.cols, size.rows);
                screen.terminal_ref = terminal;
                
                // Register for resize events
                try terminal.onResize(screenResizeCallback);
                
                return screen;
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Resize Handling ────────────────────────────┐

            /// Handle terminal resize event
            pub fn handleResize(self: *Screen, new_size: Size, mode: ResizeMode) !void {
                self.resize_mutex.lock();
                defer self.resize_mutex.unlock();
                
                if (self.is_resizing) {
                    return ScreenResizeError.ResizeInProgress;
                }
                self.is_resizing = true;
                defer self.is_resizing = false;
                
                // Validate new dimensions
                if (new_size.cols == 0 or new_size.rows == 0) {
                    return ScreenResizeError.InvalidDimensions;
                }
                
                // Skip if no actual size change
                if (new_size.cols == self.width and new_size.rows == self.height) {
                    return;
                }
                
                try self.reallocateBuffers(new_size, mode);
            }

            /// Reallocate screen buffers for new size
            fn reallocateBuffers(self: *Screen, new_size: Size, mode: ResizeMode) !void {
                const new_buffer_size = @as(usize, new_size.cols) * @as(usize, new_size.rows);
                
                // Allocate new buffers
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

            /// Copy existing content to new buffer with size preservation
            fn copyExistingContent(self: *Screen, new_buffer: []cell_mod.Cell, new_size: Size) !void {
                // Initialize all cells to empty first
                for (new_buffer) |*cell| {
                    cell.* = cell_mod.Cell.empty();
                }
                
                // Copy overlapping region from old buffer
                const copy_width = @min(self.width, new_size.cols);
                const copy_height = @min(self.height, new_size.rows);
                
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

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Utility Methods ────────────────────────────┐

            /// Get current screen dimensions
            pub fn getSize(self: *Screen) Size {
                return Size{ .cols = self.width, .rows = self.height };
            }

            /// Check if screen is currently being resized
            pub fn isResizing(self: *Screen) bool {
                return self.is_resizing;
            }

            /// Force a full screen redraw after resize
            pub fn markForFullRedraw(self: *Screen) void {
                self.needs_full_redraw = true;
            }

        // └──────────────────────────────────────────────────────────────────┘

        // Update deinit to unregister resize callback
        pub fn deinit(self: *Screen) void {
            if (self.terminal_ref) |terminal| {
                terminal.removeResizeCallback(screenResizeCallback);
            }
            // ... existing cleanup code ...
        }

    };

    /// Resize callback function for terminal events
    fn screenResizeCallback(event: ResizeEvent) void {
        // This would need to be connected to the screen instance
        // Implementation depends on how callbacks are structured
        // May require a registry or weak reference system
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

<!--------------------------------------------------------------------------->  

<!--------------------------- TESTING REQUIREMENTS --------------------------->  

## Testing Requirements
- Test screen initialization with terminal size detection
- Test buffer reallocation on resize events
- Test content preservation modes
- Test resize validation and error handling
- Test thread safety with concurrent resize operations
- Test edge cases (very small/large sizes, rapid resizing)
- Performance test: resize operation should complete in < 50ms

<!--------------------------------------------------------------------------->  

<!--------------------------- INTEGRATION POINTS ----------------------------->  

## Integration Points
- **Terminal Module**: Use resize callbacks from Issue #007
- **Layout System**: Notify layouts of screen size changes
- **Widget System**: Propagate resize events to widgets
- **Rendering Pipeline**: Handle full redraws after resize

<!--------------------------------------------------------------------------->  

<!------------------------------- METADATA ----------------------------------->  

**Estimated Time:** 3 hours  
**Priority:** 🔴 Critical - Blocks responsive layouts and proper terminal integration  
**Category:** Screen Management  
**Added:** 2025-08-24 - Identified during session review after Issue #007 completion  

<!--------------------------------------------------------------------------->  

<!--------------------------------- NOTES ------------------------------------->  

This issue is critical for making the TUI library truly responsive. Without it, users will see clipped or incorrect rendering when they resize their terminal windows, which is a fundamental expectation for modern TUI applications.

<!--------------------------------------------------------------------------->