// screen_manager.zig — Multi-screen management and layout coordination
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════════╗

    const std = @import("std");
    const Screen = @import("../../screen.zig").Screen;
    const Terminal = @import("../../../terminal/terminal.zig").Terminal;
    const Rect = @import("../rect/rect.zig").Rect;
    const Size = @import("../../screen.zig").Size;

// ╚════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════════╗

    /// Layout types for organizing multiple screens
    pub const LayoutType = enum {
        /// Single screen fills entire terminal
        single,
        
        /// Horizontal split (side by side)
        split_horizontal,
        
        /// Vertical split (top and bottom)
        split_vertical,
        
        /// Grid layout with rows and columns
        grid,
        
        /// Multiple screens, only one visible (tabbed interface)
        tabbed,
        
        /// Overlapping screens with z-ordering
        floating,
        
        /// Custom layout with manually specified regions
        custom,
    };

    /// Screen entry in the manager
    pub const ManagedScreen = struct {
        /// Pointer to the actual screen instance
        screen: *Screen,
        
        /// Screen's assigned viewport within terminal
        viewport: Rect,
        
        /// Z-index for layering (higher = on top)
        z_index: i32,
        
        /// Whether screen is currently visible
        visible: bool,
        
        /// Whether screen can receive focus
        focusable: bool,
        
        /// Optional identifier for the screen
        id: ?[]const u8,
        
        /// Initialize managed screen entry.
        ///
        /// __Parameters__
        ///
        /// - `screen`: Screen instance to manage
        /// - `viewport`: Initial viewport bounds
        ///
        /// __Return__
        ///
        /// - Initialized ManagedScreen with default settings
        pub fn init(screen: *Screen, viewport: Rect) ManagedScreen {
            return ManagedScreen{
                .screen = screen,
                .viewport = viewport,
                .z_index = 0,
                .visible = true,
                .focusable = true,
                .id = null,
            };
        }
        
        /// Check if screen bounds contain a point.
        ///
        /// __Parameters__
        ///
        /// - `self`: ManagedScreen instance
        /// - `x`: X coordinate to test
        /// - `y`: Y coordinate to test
        ///
        /// __Return__
        ///
        /// - `bool`: True if point is within screen bounds
        pub inline fn containsPoint(self: *const ManagedScreen, x: u16, y: u16) bool {
            return self.viewport.contains(x, y);
        }
        
        /// Update screen's viewport and trigger resize.
        ///
        /// __Parameters__
        ///
        /// - `self`: ManagedScreen instance
        /// - `new_viewport`: New viewport bounds
        ///
        /// __Return__
        ///
        /// - Error if screen resize fails
        pub fn updateViewport(self: *ManagedScreen, new_viewport: Rect) !void {
            self.viewport = new_viewport;
            
            // Update screen's viewport bounds
            self.screen.setViewportBounds(new_viewport);
            
            const size = Size{
                .cols = new_viewport.width,
                .rows = new_viewport.height,
            };
            
            // Use direct resize to avoid ScreenManager coordination recursion
            try self.screen.handleResizeDirectly(size, .preserve_content);
        }
    };

    /// Error types for screen manager operations
    pub const ScreenManagerError = error{
        AllocationFailed,
        ScreenNotFound,
        InvalidLayout,
        DuplicateId,
        TerminalNotSet,
        NoScreensManaged,
        LayoutCalculationFailed,
        ResizeInProgress,
        FocusLocked,
        NoFocusableScreens,
    };
    
    /// Focus event types
    pub const FocusEventType = enum {
        gained,
        lost,
        locked,
        unlocked,
    };
    
    /// Focus event data
    pub const FocusEvent = struct {
        event_type: FocusEventType,
        screen: ?*Screen,
        previous_screen: ?*Screen,
        timestamp: i64,
        
        pub fn init(event_type: FocusEventType, screen: ?*Screen, previous_screen: ?*Screen) FocusEvent {
            return FocusEvent{
                .event_type = event_type,
                .screen = screen,
                .previous_screen = previous_screen,
                .timestamp = std.time.timestamp(),
            };
        }
    };
    
    /// Focus event callback function type
    pub const FocusCallback = *const fn (event: FocusEvent) void;

    /// Layout configuration for grid layouts
    pub const GridConfig = struct {
        rows: u16,
        cols: u16,
        row_spacing: u16 = 0,
        col_spacing: u16 = 0,
    };

    /// Layout configuration for split layouts
    pub const SplitConfig = struct {
        /// Split ratio (0.0 to 1.0) for first screen
        ratio: f32 = 0.5,
        
        /// Spacing between split screens
        spacing: u16 = 0,
    };

// ╚════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════════╗

    /// Multi-screen manager for coordinating multiple screens within a terminal.
    ///
    /// The ScreenManager provides centralized management of multiple screen instances
    /// within a single terminal, enabling advanced TUI features like split-screen
    /// layouts, tabbed interfaces, and floating windows. It handles viewport
    /// calculation, resize coordination, and focus management.
    ///
    /// The manager integrates with the existing terminal callback registry to
    /// receive resize events and distribute them to all managed screens according
    /// to their assigned regions.
    pub const ScreenManager = struct {
        /// Memory allocator for dynamic allocations
        allocator: std.mem.Allocator,
        
        /// Terminal instance that owns this manager
        terminal: ?*Terminal,
        
        /// List of managed screen entries
        screens: std.ArrayList(ManagedScreen),
        
        /// Current layout type
        layout: LayoutType,
        
        /// Currently focused screen index (null if none)
        focused_screen: ?usize,
        
        /// Currently active screen for tabbed layout
        active_screen: ?usize,
        
        /// Thread safety mutex
        mutex: std.Thread.Mutex,
        
        /// Layout-specific configuration
        grid_config: GridConfig,
        split_config: SplitConfig,
        
        /// Whether resize is in progress (for thread safety)
        is_resizing: bool,
        
        /// Advanced focus management
        focus_callbacks: std.ArrayList(FocusCallback),
        focus_locked: bool,
        focus_lock_screen: ?*Screen,
        modal_screen: ?*Screen,
        
        /// Initialize screen manager.
        ///
        /// Creates a new screen manager with the specified allocator and initial
        /// layout type. The manager starts empty and screens must be added
        /// through addScreen calls.
        ///
        /// __Parameters__
        ///
        /// - `allocator`: Memory allocator for internal data structures
        /// - `initial_layout`: Starting layout type for the manager
        ///
        /// __Return__
        ///
        /// - `ScreenManager`: Initialized manager instance
        /// - `ScreenManagerError.AllocationFailed`: If initialization fails
        pub fn init(allocator: std.mem.Allocator, initial_layout: LayoutType) !ScreenManager {
            return ScreenManager{
                .allocator = allocator,
                .terminal = null,
                .screens = std.ArrayList(ManagedScreen).init(allocator),
                .layout = initial_layout,
                .focused_screen = null,
                .active_screen = null,
                .mutex = .{},
                .grid_config = GridConfig{ .rows = 2, .cols = 2 },
                .split_config = SplitConfig{},
                .is_resizing = false,
                .focus_callbacks = std.ArrayList(FocusCallback).init(allocator),
                .focus_locked = false,
                .focus_lock_screen = null,
                .modal_screen = null,
            };
        }
        
        /// Deinitialize manager and clean up resources.
        ///
        /// Clears all managed screens and frees internal resources.
        /// Managed screens will need to be cleaned up separately by their owners.
        /// After calling deinit, the manager should not be used.
        ///
        /// __Parameters__
        ///
        /// - `self`: Manager instance to deinitialize
        pub fn deinit(self: *ScreenManager) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            // Clear parent manager references from all managed screens
            for (self.screens.items) |managed| {
                managed.screen.clearParentManager();
            }
            
            // Clear screen list and focus callbacks
            self.screens.deinit();
            self.focus_callbacks.deinit();
        }
        
        /// Set terminal for this manager.
        ///
        /// Associates the manager with a terminal instance. The ScreenManager
        /// will coordinate resize events for all its managed screens through
        /// the existing callback registry mechanism.
        ///
        /// __Parameters__
        ///
        /// - `self`: Manager instance
        /// - `terminal`: Terminal instance to associate with
        ///
        /// __Return__
        ///
        /// - `void`: Successfully associated with terminal
        pub fn setTerminal(self: *ScreenManager, terminal: *Terminal) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            self.terminal = terminal;
            // Note: Individual screens will register with callback registry
            // The ScreenManager coordinates their resize handling
        }
        
        /// Add screen to manager.
        ///
        /// Adds a new screen to the manager and calculates its initial viewport
        /// based on the current layout. The screen will be configured for
        /// coordinated resize handling through the manager.
        ///
        /// __Parameters__
        ///
        /// - `self`: Manager instance
        /// - `screen`: Screen instance to add
        /// - `id`: Optional identifier for the screen
        ///
        /// __Return__
        ///
        /// - `void`: Screen successfully added
        /// - `ScreenManagerError`: If addition fails
        pub fn addScreen(self: *ScreenManager, screen: *Screen, id: ?[]const u8) !void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            // Check for duplicate ID
            if (id) |screen_id| {
                for (self.screens.items) |managed| {
                    if (managed.id) |existing_id| {
                        if (std.mem.eql(u8, screen_id, existing_id)) {
                            return ScreenManagerError.DuplicateId;
                        }
                    }
                }
            }
            
            // Set up screen-manager relationship
            screen.setParentManager(@as(*anyopaque, @ptrCast(self)));
            
            // Create managed screen with initial viewport
            var managed = ManagedScreen.init(screen, Rect.init(0, 0, 80, 24));
            managed.id = id;
            
            try self.screens.append(managed);
            
            // Set first screen as focused and active
            if (self.screens.items.len == 1) {
                self.focused_screen = 0;
                self.active_screen = 0;
            }
            
            // Recalculate layout for all screens
            try self.updateLayout();
        }
        
        /// Remove screen from manager.
        ///
        /// Removes a screen from management and recalculates layout for
        /// remaining screens. Focus is adjusted if necessary.
        ///
        /// __Parameters__
        ///
        /// - `self`: Manager instance
        /// - `screen`: Screen instance to remove
        ///
        /// __Return__
        ///
        /// - `void`: Screen successfully removed
        /// - `ScreenManagerError.ScreenNotFound`: If screen not in manager
        pub fn removeScreen(self: *ScreenManager, screen: *Screen) !void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            // Find and remove screen
            var found_index: ?usize = null;
            for (self.screens.items, 0..) |managed, i| {
                if (managed.screen == screen) {
                    found_index = i;
                    break;
                }
            }
            
            const index = found_index orelse return ScreenManagerError.ScreenNotFound;
            
            // Clear parent manager relationship
            screen.clearParentManager();
            
            _ = self.screens.swapRemove(index);
            
            // Adjust focus and active screen indices
            if (self.focused_screen) |focused| {
                if (focused == index) {
                    self.focused_screen = if (self.screens.items.len > 0) @as(?usize, 0) else null;
                } else if (focused > index) {
                    self.focused_screen = focused - 1;
                }
            }
            
            if (self.active_screen) |active| {
                if (active == index) {
                    self.active_screen = if (self.screens.items.len > 0) @as(?usize, 0) else null;
                } else if (active > index) {
                    self.active_screen = active - 1;
                }
            }
            
            // Recalculate layout for remaining screens
            if (self.screens.items.len > 0) {
                try self.updateLayout();
            }
        }
        
        /// Change layout type and recalculate screen positions.
        ///
        /// Updates the layout type and recalculates viewport bounds for all
        /// managed screens according to the new layout rules.
        ///
        /// __Parameters__
        ///
        /// - `self`: Manager instance
        /// - `new_layout`: New layout type to apply
        ///
        /// __Return__
        ///
        /// - `void`: Layout successfully changed
        /// - `ScreenManagerError`: If layout change fails
        pub fn setLayout(self: *ScreenManager, new_layout: LayoutType) !void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            self.layout = new_layout;
            try self.updateLayout();
        }
        
        /// Handle terminal resize event (callback registry compatibility).
        ///
        /// This method provides compatibility with the callback registry's
        /// expected signature. It's called when the registry casts the
        /// ScreenManager back to a Screen-like interface.
        ///
        /// __Parameters__
        ///
        /// - `self`: Manager instance (cast from anyopaque)
        /// - `new_cols`: New terminal width
        /// - `new_rows`: New terminal height
        /// - `mode`: Content preservation mode
        ///
        /// __Return__
        ///
        /// - Error if resize handling fails
        pub fn handleResize(self: *ScreenManager, new_cols: u16, new_rows: u16, mode: Screen.ResizeMode) !void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            // Prevent concurrent resize operations
            if (self.is_resizing) {
                return ScreenManagerError.ResizeInProgress;
            }
            self.is_resizing = true;
            defer self.is_resizing = false;
            
            // Store new terminal size for layout calculation
            const terminal_size = Size{ .cols = new_cols, .rows = new_rows };
            
            // Recalculate layout with new terminal size
            try self.calculateLayoutViewports(terminal_size);
            
            // Apply resize to all managed screens using direct resize to avoid recursion
            for (self.screens.items) |*managed| {
                if (managed.visible) {
                    const screen_size = Size{
                        .cols = managed.viewport.width,
                        .rows = managed.viewport.height,
                    };
                    // Use handleResizeDirectly to bypass ScreenManager coordination
                    // and avoid infinite recursion
                    managed.screen.handleResizeDirectly(screen_size, mode) catch {
                        // Continue with other screens even if one fails
                        continue;
                    };
                }
            }
        }
        
        // ┌──────────────────────────── Private Implementation ────────────────────────────┐
        
            /// Update layout for all managed screens.
            ///
            /// Internal method that recalculates viewport bounds for all screens
            /// based on current layout type and terminal size.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance (must be locked)
            ///
            /// __Return__
            ///
            /// - Error if layout calculation fails
            fn updateLayout(self: *ScreenManager) !void {
                const terminal = self.terminal orelse return ScreenManagerError.TerminalNotSet;
                const terminal_size = try terminal.getSize();
                try self.calculateLayoutViewports(terminal_size);
            }
            
            /// Calculate viewport bounds for current layout.
            ///
            /// Core layout calculation method that assigns viewport rectangles
            /// to each managed screen based on layout type and configuration.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance (must be locked)
            /// - `terminal_size`: Available terminal space
            ///
            /// __Return__
            ///
            /// - Error if calculation fails
            fn calculateLayoutViewports(self: *ScreenManager, terminal_size: Size) !void {
                if (self.screens.items.len == 0) return;
                
                switch (self.layout) {
                    .single => {
                        // Single screen fills entire terminal
                        if (self.screens.items.len > 0) {
                            self.screens.items[0].viewport = Rect.init(0, 0, terminal_size.cols, terminal_size.rows);
                            // Hide all other screens in single mode
                            for (self.screens.items[1..]) |*managed| {
                                managed.visible = false;
                            }
                        }
                    },
                    
                    .split_horizontal => {
                        try self.calculateSplitLayout(terminal_size, true);
                    },
                    
                    .split_vertical => {
                        try self.calculateSplitLayout(terminal_size, false);
                    },
                    
                    .grid => {
                        try self.calculateGridLayout(terminal_size);
                    },
                    
                    .tabbed => {
                        try self.calculateTabbedLayout(terminal_size);
                    },
                    
                    .floating => {
                        try self.calculateFloatingLayout(terminal_size);
                    },
                    
                    .custom => {
                        // Custom layout - viewports manually set, just ensure visibility
                        for (self.screens.items) |*managed| {
                            managed.visible = true;
                        }
                    },
                }
            }
            
            /// Calculate split layout viewports.
            ///
            /// Divides terminal space between screens either horizontally or vertically
            /// based on the split configuration ratio.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance (must be locked)
            /// - `terminal_size`: Available terminal space
            /// - `horizontal`: True for horizontal split, false for vertical
            ///
            /// __Return__
            ///
            /// - Error if calculation fails
            fn calculateSplitLayout(self: *ScreenManager, terminal_size: Size, horizontal: bool) !void {
                if (self.screens.items.len == 0) return;
                
                if (self.screens.items.len == 1) {
                    // Single screen gets full space
                    self.screens.items[0].viewport = Rect.init(0, 0, terminal_size.cols, terminal_size.rows);
                    self.screens.items[0].visible = true;
                    return;
                }
                
                // Calculate split dimensions
                const spacing = self.split_config.spacing;
                const ratio = @max(0.1, @min(0.9, self.split_config.ratio));
                
                if (horizontal) {
                    // Horizontal split (side by side)
                    const available_width = if (terminal_size.cols > spacing) terminal_size.cols - spacing else 0;
                    const first_width = @as(u16, @intFromFloat(@as(f32, @floatFromInt(available_width)) * ratio));
                    const second_width = available_width - first_width;
                    
                    // First screen (left)
                    self.screens.items[0].viewport = Rect.init(0, 0, first_width, terminal_size.rows);
                    self.screens.items[0].visible = true;
                    
                    // Second screen (right)
                    if (self.screens.items.len > 1) {
                        self.screens.items[1].viewport = Rect.init(first_width + spacing, 0, second_width, terminal_size.rows);
                        self.screens.items[1].visible = true;
                    }
                } else {
                    // Vertical split (top and bottom)
                    const available_height = if (terminal_size.rows > spacing) terminal_size.rows - spacing else 0;
                    const first_height = @as(u16, @intFromFloat(@as(f32, @floatFromInt(available_height)) * ratio));
                    const second_height = available_height - first_height;
                    
                    // First screen (top)
                    self.screens.items[0].viewport = Rect.init(0, 0, terminal_size.cols, first_height);
                    self.screens.items[0].visible = true;
                    
                    // Second screen (bottom)
                    if (self.screens.items.len > 1) {
                        self.screens.items[1].viewport = Rect.init(0, first_height + spacing, terminal_size.cols, second_height);
                        self.screens.items[1].visible = true;
                    }
                }
                
                // Hide additional screens in split mode (only 2 supported)
                for (self.screens.items[2..]) |*managed| {
                    managed.visible = false;
                }
            }
            
            /// Calculate grid layout viewports.
            ///
            /// Arranges screens in a grid pattern based on grid configuration.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance (must be locked)
            /// - `terminal_size`: Available terminal space
            ///
            /// __Return__
            ///
            /// - Error if calculation fails
            fn calculateGridLayout(self: *ScreenManager, terminal_size: Size) !void {
                const rows = self.grid_config.rows;
                const cols = self.grid_config.cols;
                const row_spacing = self.grid_config.row_spacing;
                const col_spacing = self.grid_config.col_spacing;
                
                if (rows == 0 or cols == 0) {
                    return ScreenManagerError.LayoutCalculationFailed;
                }
                
                // Calculate cell dimensions
                const total_col_spacing = if (cols > 1) col_spacing * (cols - 1) else 0;
                const total_row_spacing = if (rows > 1) row_spacing * (rows - 1) else 0;
                
                const available_width = if (terminal_size.cols > total_col_spacing) terminal_size.cols - total_col_spacing else 0;
                const available_height = if (terminal_size.rows > total_row_spacing) terminal_size.rows - total_row_spacing else 0;
                
                const cell_width = available_width / cols;
                const cell_height = available_height / rows;
                
                // Assign viewports to screens
                for (self.screens.items, 0..) |*managed, i| {
                    if (i >= rows * cols) {
                        // Hide screens that don't fit in grid
                        managed.visible = false;
                        continue;
                    }
                    
                    const row = @as(u16, @intCast(i / cols));
                    const col = @as(u16, @intCast(i % cols));
                    
                    const x = col * (cell_width + col_spacing);
                    const y = row * (cell_height + row_spacing);
                    
                    managed.viewport = Rect.init(x, y, cell_width, cell_height);
                    managed.visible = true;
                }
            }
            
            /// Calculate tabbed layout viewports.
            ///
            /// In tabbed mode, only the active screen is visible and fills
            /// the entire terminal space.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance (must be locked)
            /// - `terminal_size`: Available terminal space
            ///
            /// __Return__
            ///
            /// - Error if calculation fails
            fn calculateTabbedLayout(self: *ScreenManager, terminal_size: Size) !void {
                for (self.screens.items, 0..) |*managed, i| {
                    if (self.active_screen == i) {
                        // Active screen gets full space
                        managed.viewport = Rect.init(0, 0, terminal_size.cols, terminal_size.rows);
                        managed.visible = true;
                    } else {
                        // Other screens are hidden
                        managed.visible = false;
                    }
                }
            }
            
            /// Calculate floating layout viewports.
            ///
            /// In floating mode, all screens maintain their current viewports
            /// and visibility is controlled by z-ordering.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance (must be locked)
            /// - `terminal_size`: Available terminal space
            ///
            /// __Return__
            ///
            /// - Error if calculation fails
            fn calculateFloatingLayout(self: *ScreenManager, terminal_size: Size) !void {
                // In floating mode, screens maintain their custom viewports
                // but we need to ensure they don't exceed terminal bounds
                for (self.screens.items) |*managed| {
                    managed.visible = true;
                    
                    // Clamp viewport to terminal bounds
                    const max_x = if (managed.viewport.x < terminal_size.cols) terminal_size.cols - managed.viewport.x else 0;
                    const max_y = if (managed.viewport.y < terminal_size.rows) terminal_size.rows - managed.viewport.y else 0;
                    
                    managed.viewport.width = @min(managed.viewport.width, max_x);
                    managed.viewport.height = @min(managed.viewport.height, max_y);
                }
            }
        
        // └──────────────────────────────────────────────────────────────────┘
        
        // ┌──────────────────────────── Public API Methods ────────────────────────────┐
        
            /// Get screen by ID.
            ///
            /// Returns a pointer to the managed screen with the specified ID.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            /// - `id`: Screen identifier to search for
            ///
            /// __Return__
            ///
            /// - `*Screen`: Pointer to found screen
            /// - `ScreenManagerError.ScreenNotFound`: If no screen with given ID exists
            pub fn getScreenById(self: *ScreenManager, id: []const u8) !*Screen {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                for (self.screens.items) |managed| {
                    if (managed.id) |screen_id| {
                        if (std.mem.eql(u8, screen_id, id)) {
                            return managed.screen;
                        }
                    }
                }
                return ScreenManagerError.ScreenNotFound;
            }
            
            /// Get currently focused screen.
            ///
            /// Returns a pointer to the screen that currently has focus,
            /// or null if no screen is focused.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            ///
            /// __Return__
            ///
            /// - `?*Screen`: Pointer to focused screen or null
            pub fn getFocusedScreen(self: *ScreenManager) ?*Screen {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                if (self.focused_screen) |index| {
                    if (index < self.screens.items.len) {
                        return self.screens.items[index].screen;
                    }
                }
                return null;
            }
            
            /// Set focus to a specific screen.
            ///
            /// Moves keyboard focus to the specified screen. The screen must
            /// be managed by this manager and marked as focusable.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            /// - `screen`: Screen to focus
            ///
            /// __Return__
            ///
            /// - `void`: Focus successfully changed
            /// - `ScreenManagerError.ScreenNotFound`: If screen not in manager
            /// - `ScreenManagerError.FocusLocked`: If focus is locked to another screen
            pub fn focusScreen(self: *ScreenManager, screen: *Screen) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                // Check if focus is locked to a different screen
                if (self.focus_locked and self.focus_lock_screen != screen) {
                    return ScreenManagerError.FocusLocked;
                }
                
                const previous_screen = if (self.focused_screen) |idx| self.screens.items[idx].screen else null;
                
                for (self.screens.items, 0..) |managed, i| {
                    if (managed.screen == screen and managed.focusable) {
                        if (self.focused_screen != i) {
                            self.focused_screen = i;
                            
                            // Fire focus events
                            if (previous_screen) |prev| {
                                self.fireFocusEvent(FocusEvent.init(.lost, prev, screen));
                            }
                            self.fireFocusEvent(FocusEvent.init(.gained, screen, previous_screen));
                        }
                        return;
                    }
                }
                return ScreenManagerError.ScreenNotFound;
            }
            
            /// Move focus to next focusable screen.
            ///
            /// Cycles through focusable screens in order. If no screen is
            /// currently focused, focuses the first focusable screen.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            ///
            /// __Return__
            ///
            /// - `void`: Focus moved to next screen
            pub fn focusNext(self: *ScreenManager) void {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                if (self.screens.items.len == 0) return;
                
                const start_index = if (self.focused_screen) |current| (current + 1) % self.screens.items.len else 0;
                var index = start_index;
                
                // Find next focusable screen
                while (true) {
                    if (self.screens.items[index].focusable) {
                        self.focused_screen = index;
                        break;
                    }
                    index = (index + 1) % self.screens.items.len;
                    if (index == start_index) break; // Full cycle, no focusable screens
                }
            }
            
            /// Move focus to previous focusable screen.
            ///
            /// Cycles through focusable screens in reverse order.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            ///
            /// __Return__
            ///
            /// - `void`: Focus moved to previous screen
            pub fn focusPrevious(self: *ScreenManager) void {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                if (self.screens.items.len == 0) return;
                
                const start_index = if (self.focused_screen) |current|
                    if (current > 0) current - 1 else self.screens.items.len - 1
                else
                    self.screens.items.len - 1;
                    
                var index = start_index;
                
                // Find previous focusable screen
                while (true) {
                    if (self.screens.items[index].focusable) {
                        self.focused_screen = index;
                        break;
                    }
                    index = if (index > 0) index - 1 else self.screens.items.len - 1;
                    if (index == start_index) break; // Full cycle, no focusable screens
                }
            }
            
            // ┌──────────────────────────── Advanced Focus Management ────────────────────────────┐
            
                /// Add focus event callback.
                ///
                /// Registers a callback function that will be called whenever focus
                /// events occur (gained, lost, locked, unlocked).
                ///
                /// __Parameters__
                ///
                /// - `self`: Manager instance
                /// - `callback`: Function to call on focus events
                ///
                /// __Return__
                ///
                /// - `void`: Callback registered successfully
                /// - `ScreenManagerError.AllocationFailed`: If registration fails
                pub fn addFocusCallback(self: *ScreenManager, callback: FocusCallback) !void {
                    self.mutex.lock();
                    defer self.mutex.unlock();
                    
                    try self.focus_callbacks.append(callback);
                }
                
                /// Remove focus event callback.
                ///
                /// Unregisters a previously registered focus event callback.
                ///
                /// __Parameters__
                ///
                /// - `self`: Manager instance
                /// - `callback`: Function to unregister
                pub fn removeFocusCallback(self: *ScreenManager, callback: FocusCallback) void {
                    self.mutex.lock();
                    defer self.mutex.unlock();
                    
                    for (self.focus_callbacks.items, 0..) |registered_callback, i| {
                        if (registered_callback == callback) {
                            _ = self.focus_callbacks.swapRemove(i);
                            break;
                        }
                    }
                }
                
                /// Lock focus to a specific screen.
                ///
                /// Prevents focus from being moved away from the specified screen
                /// until unlocked. Useful for modal dialogs and critical operations.
                ///
                /// __Parameters__
                ///
                /// - `self`: Manager instance
                /// - `screen`: Screen to lock focus to (null to unlock)
                ///
                /// __Return__
                ///
                /// - `void`: Focus locked successfully
                /// - `ScreenManagerError.ScreenNotFound`: If screen not in manager
                pub fn lockFocus(self: *ScreenManager, screen: ?*Screen) !void {
                    self.mutex.lock();
                    defer self.mutex.unlock();
                    
                    if (screen) |target_screen| {
                        // Verify screen is managed and focusable
                        var found = false;
                        for (self.screens.items) |managed| {
                            if (managed.screen == target_screen and managed.focusable) {
                                found = true;
                                break;
                            }
                        }
                        
                        if (!found) {
                            return ScreenManagerError.ScreenNotFound;
                        }
                        
                        // Lock focus and set focus to target screen
                        self.focus_locked = true;
                        self.focus_lock_screen = target_screen;
                        try self.focusScreenInternal(target_screen);
                        
                        self.fireFocusEvent(FocusEvent.init(.locked, target_screen, null));
                    } else {
                        // Unlock focus
                        const previous_lock_screen = self.focus_lock_screen;
                        self.focus_locked = false;
                        self.focus_lock_screen = null;
                        
                        self.fireFocusEvent(FocusEvent.init(.unlocked, previous_lock_screen, null));
                    }
                }
                
                /// Check if focus is currently locked.
                ///
                /// __Parameters__
                ///
                /// - `self`: Manager instance
                ///
                /// __Return__
                ///
                /// - `bool`: True if focus is locked
                pub inline fn isFocusLocked(self: *ScreenManager) bool {
                    self.mutex.lock();
                    defer self.mutex.unlock();
                    
                    return self.focus_locked;
                }
                
                /// Get the screen that focus is locked to.
                ///
                /// __Parameters__
                ///
                /// - `self`: Manager instance
                ///
                /// __Return__
                ///
                /// - `?*Screen`: Screen with locked focus or null if not locked
                pub fn getFocusLockScreen(self: *ScreenManager) ?*Screen {
                    self.mutex.lock();
                    defer self.mutex.unlock();
                    
                    return if (self.focus_locked) self.focus_lock_screen else null;
                }
                
                /// Set modal screen.
                ///
                /// Designates a screen as modal, which affects focus behavior
                /// and visibility. Modal screens typically appear on top and
                /// capture all input.
                ///
                /// __Parameters__
                ///
                /// - `self`: Manager instance
                /// - `screen`: Screen to make modal (null to clear modal)
                ///
                /// __Return__
                ///
                /// - `void`: Modal screen set successfully
                /// - `ScreenManagerError.ScreenNotFound`: If screen not in manager
                pub fn setModalScreen(self: *ScreenManager, screen: ?*Screen) !void {
                    self.mutex.lock();
                    defer self.mutex.unlock();
                    
                    if (screen) |modal_screen| {
                        // Verify screen is managed
                        var found = false;
                        for (self.screens.items) |managed| {
                            if (managed.screen == modal_screen) {
                                found = true;
                                break;
                            }
                        }
                        
                        if (!found) {
                            return ScreenManagerError.ScreenNotFound;
                        }
                        
                        self.modal_screen = modal_screen;
                        
                        // Bring modal screen to front and lock focus
                        try self.bringToFront(modal_screen);
                        try self.lockFocus(modal_screen);
                    } else {
                        // Clear modal screen and unlock focus
                        self.modal_screen = null;
                        try self.lockFocus(null);
                    }
                }
                
                /// Get current modal screen.
                ///
                /// __Parameters__
                ///
                /// - `self`: Manager instance
                ///
                /// __Return__
                ///
                /// - `?*Screen`: Current modal screen or null
                pub fn getModalScreen(self: *ScreenManager) ?*Screen {
                    self.mutex.lock();
                    defer self.mutex.unlock();
                    
                    return self.modal_screen;
                }
                
                /// Check if a screen is currently modal.
                ///
                /// __Parameters__
                ///
                /// - `self`: Manager instance
                /// - `screen`: Screen to check
                ///
                /// __Return__
                ///
                /// - `bool`: True if screen is modal
                pub fn isModalScreen(self: *ScreenManager, screen: *Screen) bool {
                    self.mutex.lock();
                    defer self.mutex.unlock();
                    
                    return self.modal_screen == screen;
                }
                
                /// Find next focusable screen after given index.
                ///
                /// Utility method for focus cycling that skips non-focusable
                /// and invisible screens.
                ///
                /// __Parameters__
                ///
                /// - `self`: Manager instance
                /// - `start_index`: Starting index for search
                ///
                /// __Return__
                ///
                /// - `?usize`: Index of next focusable screen or null
                fn findNextFocusableScreen(self: *ScreenManager, start_index: usize) ?usize {
                    if (self.screens.items.len == 0) return null;
                    
                    const len = self.screens.items.len;
                    var index = start_index % len;
                    var checked = @as(usize, 0);
                    
                    while (checked < len) {
                        const managed = self.screens.items[index];
                        if (managed.focusable and managed.visible) {
                            return index;
                        }
                        index = (index + 1) % len;
                        checked += 1;
                    }
                    
                    return null;
                }
                
                /// Find previous focusable screen before given index.
                ///
                /// Utility method for focus cycling that skips non-focusable
                /// and invisible screens.
                ///
                /// __Parameters__
                ///
                /// - `self`: Manager instance
                /// - `start_index`: Starting index for search
                ///
                /// __Return__
                ///
                /// - `?usize`: Index of previous focusable screen or null
                fn findPreviousFocusableScreen(self: *ScreenManager, start_index: usize) ?usize {
                    if (self.screens.items.len == 0) return null;
                    
                    const len = self.screens.items.len;
                    var index = if (start_index > 0) start_index - 1 else len - 1;
                    var checked = @as(usize, 0);
                    
                    while (checked < len) {
                        const managed = self.screens.items[index];
                        if (managed.focusable and managed.visible) {
                            return index;
                        }
                        index = if (index > 0) index - 1 else len - 1;
                        checked += 1;
                    }
                    
                    return null;
                }
                
                /// Internal focus method without locking checks.
                ///
                /// __Parameters__
                ///
                /// - `self`: Manager instance (must be locked)
                /// - `screen`: Screen to focus
                ///
                /// __Return__
                ///
                /// - Error if screen not found
                fn focusScreenInternal(self: *ScreenManager, screen: *Screen) !void {
                    for (self.screens.items, 0..) |managed, i| {
                        if (managed.screen == screen and managed.focusable) {
                            self.focused_screen = i;
                            return;
                        }
                    }
                    return ScreenManagerError.ScreenNotFound;
                }
                
                /// Fire focus event to all registered callbacks.
                ///
                /// __Parameters__
                ///
                /// - `self`: Manager instance (must be locked)
                /// - `event`: Focus event to fire
                fn fireFocusEvent(self: *ScreenManager, event: FocusEvent) void {
                    for (self.focus_callbacks.items) |callback| {
                        callback(event);
                    }
                }
            
            // └──────────────────────────────────────────────────────────────────┘
            
            /// Set active screen for tabbed layout.
            ///
            /// In tabbed layout mode, sets which screen should be visible.
            /// Has no effect in other layout modes.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            /// - `screen`: Screen to make active
            ///
            /// __Return__
            ///
            /// - `void`: Active screen changed and layout updated
            /// - `ScreenManagerError`: If screen not found or update fails
            pub fn setActiveScreen(self: *ScreenManager, screen: *Screen) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                for (self.screens.items, 0..) |managed, i| {
                    if (managed.screen == screen) {
                        self.active_screen = i;
                        if (self.layout == .tabbed) {
                            try self.updateLayout();
                        }
                        return;
                    }
                }
                return ScreenManagerError.ScreenNotFound;
            }
            
            /// Configure grid layout parameters.
            ///
            /// Updates the grid configuration and recalculates layout if
            /// currently using grid layout mode.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            /// - `config`: New grid configuration
            ///
            /// __Return__
            ///
            /// - `void`: Grid configuration updated
            /// - `ScreenManagerError`: If layout update fails
            pub fn setGridConfig(self: *ScreenManager, config: GridConfig) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                self.grid_config = config;
                if (self.layout == .grid) {
                    try self.updateLayout();
                }
            }
            
            /// Configure split layout parameters.
            ///
            /// Updates the split configuration and recalculates layout if
            /// currently using split layout mode.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            /// - `config`: New split configuration
            ///
            /// __Return__
            ///
            /// - `void`: Split configuration updated
            /// - `ScreenManagerError`: If layout update fails
            pub fn setSplitConfig(self: *ScreenManager, config: SplitConfig) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                self.split_config = config;
                if (self.layout == .split_horizontal or self.layout == .split_vertical) {
                    try self.updateLayout();
                }
            }
            
            /// Set custom viewport for a screen.
            ///
            /// Manually sets the viewport bounds for a specific screen.
            /// This is primarily useful in custom or floating layout modes.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            /// - `screen`: Screen to update
            /// - `viewport`: New viewport bounds
            ///
            /// __Return__
            ///
            /// - `void`: Viewport updated and screen resized
            /// - `ScreenManagerError`: If screen not found or resize fails
            pub fn setScreenViewport(self: *ScreenManager, screen: *Screen, viewport: Rect) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                for (self.screens.items) |*managed| {
                    if (managed.screen == screen) {
                        try managed.updateViewport(viewport);
                        return;
                    }
                }
                return ScreenManagerError.ScreenNotFound;
            }
            
            /// Set screen visibility.
            ///
            /// Controls whether a screen is visible and receives rendering.
            /// Invisible screens still exist and maintain their state.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            /// - `screen`: Screen to update
            /// - `visible`: New visibility state
            ///
            /// __Return__
            ///
            /// - `void`: Visibility updated
            /// - `ScreenManagerError.ScreenNotFound`: If screen not in manager
            pub fn setScreenVisibility(self: *ScreenManager, screen: *Screen, visible: bool) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                for (self.screens.items) |*managed| {
                    if (managed.screen == screen) {
                        managed.visible = visible;
                        return;
                    }
                }
                return ScreenManagerError.ScreenNotFound;
            }
            
            /// Set screen z-index for layering.
            ///
            /// Controls the layering order in floating layout mode.
            /// Higher z-index values appear on top.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            /// - `screen`: Screen to update
            /// - `z_index`: New z-index value
            ///
            /// __Return__
            ///
            /// - `void`: Z-index updated
            /// - `ScreenManagerError.ScreenNotFound`: If screen not in manager
            pub fn setScreenZIndex(self: *ScreenManager, screen: *Screen, z_index: i32) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                for (self.screens.items) |*managed| {
                    if (managed.screen == screen) {
                        managed.z_index = z_index;
                        return;
                    }
                }
                return ScreenManagerError.ScreenNotFound;
            }
            
            /// Get screen count.
            ///
            /// Returns the number of screens currently managed.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            ///
            /// __Return__
            ///
            /// - `usize`: Number of managed screens
            pub fn getScreenCount(self: *ScreenManager) usize {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                return self.screens.items.len;
            }
            
            /// Get current layout type.
            ///
            /// Returns the currently active layout type.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            ///
            /// __Return__
            ///
            /// - `LayoutType`: Current layout type
            pub fn getLayout(self: *ScreenManager) LayoutType {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                return self.layout;
            }
            
            /// Get screen at point.
            ///
            /// Returns the topmost visible screen that contains the specified
            /// point, taking z-ordering into account.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            /// - `x`: X coordinate to test
            /// - `y`: Y coordinate to test
            ///
            /// __Return__
            ///
            /// - `?*Screen`: Topmost screen at point or null
            pub fn getScreenAtPoint(self: *ScreenManager, x: u16, y: u16) ?*Screen {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                var topmost_screen: ?*Screen = null;
                var topmost_z_index: i32 = std.math.minInt(i32);
                
                for (self.screens.items) |managed| {
                    if (managed.visible and managed.containsPoint(x, y)) {
                        if (managed.z_index >= topmost_z_index) {
                            topmost_screen = managed.screen;
                            topmost_z_index = managed.z_index;
                        }
                    }
                }
                
                return topmost_screen;
            }
            
            /// Bring screen to front (highest z-index).
            ///
            /// Moves the specified screen to the top of the z-order stack,
            /// making it appear above all other screens.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            /// - `screen`: Screen to bring to front
            ///
            /// __Return__
            ///
            /// - `void`: Screen brought to front
            /// - `ScreenManagerError.ScreenNotFound`: If screen not in manager
            pub fn bringToFront(self: *ScreenManager, screen: *Screen) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                // Find the highest current z-index
                var max_z_index: i32 = std.math.minInt(i32);
                for (self.screens.items) |managed| {
                    if (managed.z_index > max_z_index) {
                        max_z_index = managed.z_index;
                    }
                }
                
                // Set target screen to highest z-index + 1
                for (self.screens.items) |*managed| {
                    if (managed.screen == screen) {
                        managed.z_index = max_z_index + 1;
                        return;
                    }
                }
                
                return ScreenManagerError.ScreenNotFound;
            }
            
            /// Send screen to back (lowest z-index).
            ///
            /// Moves the specified screen to the bottom of the z-order stack,
            /// making it appear behind all other screens.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            /// - `screen`: Screen to send to back
            ///
            /// __Return__
            ///
            /// - `void`: Screen sent to back
            /// - `ScreenManagerError.ScreenNotFound`: If screen not in manager
            pub fn sendToBack(self: *ScreenManager, screen: *Screen) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                // Find the lowest current z-index
                var min_z_index: i32 = std.math.maxInt(i32);
                for (self.screens.items) |managed| {
                    if (managed.z_index < min_z_index) {
                        min_z_index = managed.z_index;
                    }
                }
                
                // Set target screen to lowest z-index - 1
                for (self.screens.items) |*managed| {
                    if (managed.screen == screen) {
                        managed.z_index = min_z_index - 1;
                        return;
                    }
                }
                
                return ScreenManagerError.ScreenNotFound;
            }
            
            /// Move screen up one level in z-order.
            ///
            /// Swaps the screen's z-index with the next higher screen,
            /// moving it one level closer to the front.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            /// - `screen`: Screen to move up
            ///
            /// __Return__
            ///
            /// - `void`: Screen moved up or already at front
            /// - `ScreenManagerError.ScreenNotFound`: If screen not in manager
            pub fn moveUp(self: *ScreenManager, screen: *Screen) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                // Find target screen and the screen immediately above it
                var target_index: ?usize = null;
                var target_z_index: i32 = 0;
                
                for (self.screens.items, 0..) |managed, i| {
                    if (managed.screen == screen) {
                        target_index = i;
                        target_z_index = managed.z_index;
                        break;
                    }
                }
                
                const target_idx = target_index orelse return ScreenManagerError.ScreenNotFound;
                
                // Find screen with next higher z-index
                var next_higher_index: ?usize = null;
                var next_higher_z_index = std.math.maxInt(i32);
                
                for (self.screens.items, 0..) |managed, i| {
                    if (i != target_idx and managed.z_index > target_z_index) {
                        if (managed.z_index < next_higher_z_index) {
                            next_higher_index = i;
                            next_higher_z_index = managed.z_index;
                        }
                    }
                }
                
                // Swap z-indices if found
                if (next_higher_index) |higher_idx| {
                    self.screens.items[target_idx].z_index = next_higher_z_index;
                    self.screens.items[higher_idx].z_index = target_z_index;
                }
            }
            
            /// Move screen down one level in z-order.
            ///
            /// Swaps the screen's z-index with the next lower screen,
            /// moving it one level closer to the back.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            /// - `screen`: Screen to move down
            ///
            /// __Return__
            ///
            /// - `void`: Screen moved down or already at back
            /// - `ScreenManagerError.ScreenNotFound`: If screen not in manager
            pub fn moveDown(self: *ScreenManager, screen: *Screen) !void {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                // Find target screen and the screen immediately below it
                var target_index: ?usize = null;
                var target_z_index: i32 = 0;
                
                for (self.screens.items, 0..) |managed, i| {
                    if (managed.screen == screen) {
                        target_index = i;
                        target_z_index = managed.z_index;
                        break;
                    }
                }
                
                const target_idx = target_index orelse return ScreenManagerError.ScreenNotFound;
                
                // Find screen with next lower z-index
                var next_lower_index: ?usize = null;
                var next_lower_z_index = std.math.minInt(i32);
                
                for (self.screens.items, 0..) |managed, i| {
                    if (i != target_idx and managed.z_index < target_z_index) {
                        if (managed.z_index > next_lower_z_index) {
                            next_lower_index = i;
                            next_lower_z_index = managed.z_index;
                        }
                    }
                }
                
                // Swap z-indices if found
                if (next_lower_index) |lower_idx| {
                    self.screens.items[target_idx].z_index = next_lower_z_index;
                    self.screens.items[lower_idx].z_index = target_z_index;
                }
            }
            
            /// Get screens sorted by z-order (back to front).
            ///
            /// Returns a list of screens sorted by their z-index values,
            /// with lower z-index values first (back) and higher values last (front).
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            /// - `allocator`: Allocator for result array
            ///
            /// __Return__
            ///
            /// - `[]*Screen`: Array of screens sorted by z-order
            /// - `ScreenManagerError.AllocationFailed`: If allocation fails
            pub fn getScreensByZOrder(self: *ScreenManager, allocator: std.mem.Allocator) ![]const *Screen {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                // Create array of screen pointers with z-index
                const ScreenZEntry = struct {
                    screen: *Screen,
                    z_index: i32,
                };
                
                var entries = std.ArrayList(ScreenZEntry).init(allocator);
                defer entries.deinit();
                
                for (self.screens.items) |managed| {
                    try entries.append(ScreenZEntry{
                        .screen = managed.screen,
                        .z_index = managed.z_index,
                    });
                }
                
                // Sort by z-index (ascending: back to front)
                const SortContext = struct {
                    pub fn lessThan(context: void, a: ScreenZEntry, b: ScreenZEntry) bool {
                        _ = context;
                        return a.z_index < b.z_index;
                    }
                };
                
                std.mem.sort(ScreenZEntry, entries.items, {}, SortContext.lessThan);
                
                // Extract screen pointers
                var result = try allocator.alloc(*Screen, entries.items.len);
                for (entries.items, 0..) |entry, i| {
                    result[i] = entry.screen;
                }
                
                return result;
            }
            
            /// Normalize z-index values to prevent overflow.
            ///
            /// Redistributes z-index values across all screens to use a
            /// compact range starting from 0, preserving relative ordering.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            pub fn normalizeZIndices(self: *ScreenManager) void {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                if (self.screens.items.len == 0) return;
                
                // Create array of screen indices with z-index for sorting
                const ScreenIndexEntry = struct {
                    index: usize,
                    z_index: i32,
                };
                
                var temp_allocator = std.heap.ArenaAllocator.init(self.allocator);
                defer temp_allocator.deinit();
                const arena = temp_allocator.allocator();
                
                var entries = std.ArrayList(ScreenIndexEntry).init(arena);
                
                for (self.screens.items, 0..) |managed, i| {
                    entries.append(ScreenIndexEntry{
                        .index = i,
                        .z_index = managed.z_index,
                    }) catch return; // Silently fail on allocation error
                }
                
                // Sort by z-index
                const SortContext = struct {
                    pub fn lessThan(context: void, a: ScreenIndexEntry, b: ScreenIndexEntry) bool {
                        _ = context;
                        return a.z_index < b.z_index;
                    }
                };
                
                std.mem.sort(ScreenIndexEntry, entries.items, {}, SortContext.lessThan);
                
                // Reassign z-indices starting from 0
                for (entries.items, 0..) |entry, new_z| {
                    self.screens.items[entry.index].z_index = @as(i32, @intCast(new_z));
                }
            }
            
            /// Get screen z-index.
            ///
            /// Returns the current z-index value for the specified screen.
            ///
            /// __Parameters__
            ///
            /// - `self`: Manager instance
            /// - `screen`: Screen to query
            ///
            /// __Return__
            ///
            /// - `i32`: Screen's z-index value
            /// - `ScreenManagerError.ScreenNotFound`: If screen not in manager
            pub fn getScreenZIndex(self: *ScreenManager, screen: *Screen) !i32 {
                self.mutex.lock();
                defer self.mutex.unlock();
                
                for (self.screens.items) |managed| {
                    if (managed.screen == screen) {
                        return managed.z_index;
                    }
                }
                
                return ScreenManagerError.ScreenNotFound;
            }
        
        // └──────────────────────────────────────────────────────────────────┘
    };

// ╚════════════════════════════════════════════════════════════════════════════════════════╝