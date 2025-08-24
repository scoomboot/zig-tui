// tui.zig — Main entry point for Zig TUI library
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs/tui
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════════╗

    const std = @import("std");
    const builtin = @import("builtin");
    
    // Core modules
    pub const Terminal = @import("terminal/terminal.zig").Terminal;
    pub const Screen = @import("screen/screen.zig").Screen;
    pub const Event = @import("event/event.zig").Event;
    pub const EventHandler = @import("event/event.zig").EventHandler;
    pub const EventType = @import("event/event.zig").EventType;
    pub const EventDispatcher = @import("event/event.zig").EventDispatcher;
    
    // Keyboard and mouse utilities
    pub const KeyCode = @import("event/utils/keyboard/keyboard.zig").KeyCode;
    pub const KeyEvent = @import("event/utils/keyboard/keyboard.zig").KeyEvent;
    pub const Modifiers = @import("event/utils/keyboard/keyboard.zig").Modifiers;
    pub const MouseButton = @import("event/utils/mouse/mouse.zig").MouseButton;
    pub const MouseEvent = @import("event/utils/mouse/mouse.zig").MouseEvent;
    
    // Screen utilities
    pub const Cell = @import("screen/utils/cell/cell.zig").Cell;
    pub const Rect = @import("screen/utils/rect/rect.zig").Rect;
    
    // Terminal utilities
    pub const ansi = @import("terminal/utils/ansi/ansi.zig");
    
    // Layout and widget modules (future expansion)
    pub const Widget = @import("widget/widget.zig").Widget;
    pub const Layout = @import("layout/layout.zig").Layout;

// ╚════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════════╗

    // Library metadata
    pub const version = "0.1.0";
    pub const author = "Fisty";
    pub const license = "MIT";
    pub const repository = "https://github.com/fisty/zig-tui";
    
    // Common color definitions
    pub const Color = union(enum) {
        default,
        black,
        red,
        green,
        yellow,
        blue,
        magenta,
        cyan,
        white,
        bright_black,
        bright_red,
        bright_green,
        bright_yellow,
        bright_blue,
        bright_magenta,
        bright_cyan,
        bright_white,
        indexed: u8,
        rgb: packed struct { r: u8, g: u8, b: u8 }, // Use packed struct for better memory layout
        
        /// Convert color to ANSI escape sequence value.
        ///
        /// __Parameters__
        ///
        /// - `self`: The color to convert
        ///
        /// __Return__
        ///
        /// - ANSI escape sequence value as u8
        pub inline fn toAnsi(self: Color) u8 {
            // Performance optimization: inline for hot path
            // Use compact switch with computed values where possible
            return switch (self) {
                .default => 39,
                .black => 30,
                .red => 31,
                .green => 32,
                .yellow => 33,
                .blue => 34,
                .magenta => 35,
                .cyan => 36,
                .white => 37,
                .bright_black => 90,
                .bright_red => 91,
                .bright_green => 92,
                .bright_yellow => 93,
                .bright_blue => 94,
                .bright_magenta => 95,
                .bright_cyan => 96,
                .bright_white => 97,
                .indexed => |idx| idx,
                .rgb => 39, // Default for RGB (requires special handling)
            };
        }
        
        /// Format RGB color for ANSI 24-bit color sequences.
        ///
        /// __Parameters__
        ///
        /// - `self`: The color to format
        /// - `writer`: Writer to output the escape sequence to
        /// - `is_foreground`: true for foreground, false for background
        ///
        /// __Return__
        ///
        /// - Error if writing fails
        pub fn writeAnsiRgb(
            self: Color,
            writer: anytype,
            is_foreground: bool,
        ) !void {
            switch (self) {
                .rgb => |rgb| {
                    // ESC[38;2;r;g;bm for foreground, ESC[48;2;r;g;bm for background
                    const code: u8 = if (is_foreground) 38 else 48;
                    try writer.print("\x1b[{d};2;{d};{d};{d}m", .{
                        code, rgb.r, rgb.g, rgb.b,
                    });
                },
                .indexed => |idx| {
                    // ESC[38;5;indexm for foreground, ESC[48;5;indexm for background
                    const code: u8 = if (is_foreground) 38 else 48;
                    try writer.print("\x1b[{d};5;{d}m", .{ code, idx });
                },
                else => {
                    // Standard ANSI colors
                    const base = self.toAnsi();
                    const code = if (is_foreground) base else base + 10;
                    try writer.print("\x1b[{d}m", .{code});
                },
            }
        }
    };
    
    // Text attributes for styling
    pub const Attributes = packed struct {
        bold: bool = false,
        italic: bool = false,
        underline: bool = false,
        blink: bool = false,
        reverse: bool = false,
        hidden: bool = false,
        strikethrough: bool = false,
        dim: bool = false,
        
        /// Create default attributes with no styling.
        ///
        /// __Return__
        ///
        /// - Default Attributes struct with all fields false
        pub fn none() Attributes {
            return .{};
        }
        
        /// Check if any attributes are set.
        ///
        /// __Parameters__
        ///
        /// - `self`: The attributes to check
        ///
        /// __Return__
        ///
        /// - true if any attribute is set, false otherwise
        pub inline fn isSet(self: Attributes) bool {
            // Performance optimization: treat packed struct as u8 for bit operations
            // This is much faster than checking each field individually
            return @as(u8, @bitCast(self)) != 0;
        }
        
        /// Write ANSI escape sequences for enabled attributes.
        ///
        /// __Parameters__
        ///
        /// - `self`: The attributes to write
        /// - `writer`: Writer to output escape sequences to
        ///
        /// __Return__
        ///
        /// - Error if writing fails
        pub fn writeAnsi(self: Attributes, writer: anytype) !void {
            if (self.bold) try writer.writeAll("\x1b[1m");
            if (self.dim) try writer.writeAll("\x1b[2m");
            if (self.italic) try writer.writeAll("\x1b[3m");
            if (self.underline) try writer.writeAll("\x1b[4m");
            if (self.blink) try writer.writeAll("\x1b[5m");
            if (self.reverse) try writer.writeAll("\x1b[7m");
            if (self.hidden) try writer.writeAll("\x1b[8m");
            if (self.strikethrough) try writer.writeAll("\x1b[9m");
        }
    };
    
    // Style structure for cell formatting
    pub const Style = struct {
        fg: Color = .default,
        bg: Color = .default,
        attrs: Attributes = Attributes.none(),
        
        /// Create default style.
        ///
        /// __Return__
        ///
        /// - Style with default colors and no attributes
        pub fn default() Style {
            return .{};
        }
        
        /// Create style with foreground color.
        ///
        /// __Parameters__
        ///
        /// - `fg`: Foreground color to set
        ///
        /// __Return__
        ///
        /// - New Style with specified foreground color
        pub fn withFg(fg: Color) Style {
            return .{ .fg = fg };
        }
        
        /// Create style with background color.
        ///
        /// __Parameters__
        ///
        /// - `bg`: Background color to set
        ///
        /// __Return__
        ///
        /// - New Style with specified background color
        pub fn withBg(bg: Color) Style {
            return .{ .bg = bg };
        }
        
        /// Create style with both colors.
        ///
        /// __Parameters__
        ///
        /// - `fg`: Foreground color to set
        /// - `bg`: Background color to set
        ///
        /// __Return__
        ///
        /// - New Style with specified colors
        pub fn withColors(fg: Color, bg: Color) Style {
            return .{ .fg = fg, .bg = bg };
        }
    };
    
    // Position and size types
    pub const Point = struct {
        x: u16,
        y: u16,
        
        /// Create a new point.
        ///
        /// __Parameters__
        ///
        /// - `x`: X coordinate
        /// - `y`: Y coordinate
        ///
        /// __Return__
        ///
        /// - New Point with specified coordinates
        pub fn new(x: u16, y: u16) Point {
            return .{ .x = x, .y = y };
        }
        
        /// Origin point (0, 0).
        ///
        /// __Return__
        ///
        /// - Point at origin (0, 0)
        pub fn zero() Point {
            return .{ .x = 0, .y = 0 };
        }
    };
    
    pub const Size = struct {
        width: u16,
        height: u16,
        
        /// Create a new size.
        ///
        /// __Parameters__
        ///
        /// - `width`: Width dimension
        /// - `height`: Height dimension
        ///
        /// __Return__
        ///
        /// - New Size with specified dimensions
        pub fn new(width: u16, height: u16) Size {
            return .{ .width = width, .height = height };
        }
        
        /// Check if size is empty.
        ///
        /// __Parameters__
        ///
        /// - `self`: The size to check
        ///
        /// __Return__
        ///
        /// - true if width or height is zero
        pub fn isEmpty(self: Size) bool {
            return self.width == 0 or self.height == 0;
        }
        
        /// Calculate total area.
        ///
        /// __Parameters__
        ///
        /// - `self`: The size to calculate area for
        ///
        /// __Return__
        ///
        /// - Total area as width * height
        pub inline fn area(self: Size) u32 {
            // Inline for performance in hot paths
            return @as(u32, self.width) * @as(u32, self.height);
        }
        
        /// Check if a point is within this size boundary.
        ///
        /// __Parameters__
        ///
        /// - `self`: The size defining the boundary
        /// - `point`: The point to check
        ///
        /// __Return__
        ///
        /// - true if point is within bounds
        pub inline fn contains(self: Size, point: Point) bool {
            return point.x < self.width and point.y < self.height;
        }
    };
    
    // Error types for TUI operations
    pub const TuiError = error{
        TerminalInitFailed,
        ScreenBufferFull,
        InvalidDimensions,
        EventQueueFull,
        RawModeError,
        IoError,
        AllocationError,
        NotImplemented,
        InvalidInput,
        UnsupportedTerminal,
        PipeError,
        SignalError,
        ThreadError,
        Timeout,
    };

// ╚════════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════════╗

    // ┌───────────────────────────── TUI Context ─────────────────────────────┐
    
        /// Main TUI context structure
        pub const TUI = struct {
            allocator: std.mem.Allocator,
            terminal: Terminal,
            screen: Screen,
            event_handler: EventHandler,
            running: std.atomic.Value(bool), // Thread-safe state management
            render_buffer: std.ArrayList(u8), // Reusable render buffer
            last_render_time: i64, // For frame rate limiting
            target_fps: u32, // Configurable frame rate
            
            /// Deinitialize the TUI system.
            ///
            /// __Parameters__
            ///
            /// - `self`: TUI instance to deinitialize
            pub fn deinit(self: *TUI) void {
                // Ensure we stop before cleanup
                self.running.store(false, .seq_cst);
                
                // Clean up in reverse order of initialization
                self.event_handler.deinit();
                self.screen.deinit();
                
                // Ensure terminal is restored even if errors occurred
                self.terminal.exit_raw_mode() catch {};
                self.terminal.show_cursor() catch {};
                self.terminal.deinit();
                
                // Free render buffer
                self.render_buffer.deinit();
            }
            
            /// Start the main event loop.
            ///
            /// __Parameters__
            ///
            /// - `self`: TUI instance to run
            pub fn run(self: *TUI) !void {
                self.running.store(true, .seq_cst);
                
                // Set up terminal with proper error handling
                try self.terminal.enter_raw_mode();
                errdefer self.terminal.exit_raw_mode() catch {};
                
                try self.terminal.hide_cursor();
                errdefer self.terminal.show_cursor() catch {};
                
                try self.terminal.clear();
                
                // Calculate frame duration for target FPS
                const frame_duration_ns = @divFloor(std.time.ns_per_s, self.target_fps);
                
                while (self.running.load(.seq_cst)) {
                    const frame_start = std.time.nanoTimestamp();
                    
                    // Process events (poll_timeout would be ideal but using poll for now)
                    if (try self.event_handler.poll()) |event| {
                        try self.handleEvent(event);
                    }
                    
                    // Check if we should render this frame
                    const now = std.time.nanoTimestamp();
                    const elapsed = now - self.last_render_time;
                    
                    if (elapsed >= frame_duration_ns) {
                        try self.render();
                        self.last_render_time = now;
                    }
                    
                    // Sleep for remaining frame time if we finished early
                    const frame_elapsed = std.time.nanoTimestamp() - frame_start;
                    if (frame_elapsed < frame_duration_ns) {
                        std.time.sleep(@intCast(frame_duration_ns - frame_elapsed));
                    }
                }
            }
            
            /// Handle a single event.
            ///
            /// __Parameters__
            ///
            /// - `self`: TUI instance
            /// - `event`: Event to handle
            fn handleEvent(self: *TUI, event: Event) !void {
                switch (event) {
                    .key => |key_event| {
                        // Handle Ctrl+C and Ctrl+D to quit
                        if (key_event.modifiers.ctrl) {
                            const char = switch (key_event.code) {
                                .char => |c| c,
                                else => 0,
                            };
                            if (char == 'c' or char == 'd' or char == 'C' or char == 'D') {
                                self.stop();
                            }
                        }
                    },
                    .resize => |resize_event| {
                        // Validate dimensions before resizing
                        if (resize_event.width == 0 or resize_event.height == 0) {
                            return TuiError.InvalidDimensions;
                        }
                        try self.screen.resize(resize_event.width, resize_event.height);
                        // Force full redraw after resize
                        try self.forceRedraw();
                    },
                    .mouse => |mouse_event| {
                        // Mouse events can be handled by widgets
                        _ = mouse_event;
                    },
                    else => {},
                }
            }
            
            /// Stop the event loop.
            ///
            /// __Parameters__
            ///
            /// - `self`: TUI instance to stop
            pub inline fn stop(self: *TUI) void {
                self.running.store(false, .seq_cst);
            }
            
            /// Check if the TUI is currently running.
            ///
            /// __Return__
            ///
            /// - true if the event loop is active
            pub inline fn isRunning(self: *const TUI) bool {
                return self.running.load(.seq_cst);
            }
            
            /// Force a full screen redraw on next render.
            pub fn forceRedraw(self: *TUI) !void {
                // Mark all cells as dirty for full redraw
                // This would call screen.mark_all_dirty() when available
                try self.render();
            }
            
            /// Render the screen to terminal.
            ///
            /// __Parameters__
            ///
            /// - `self`: TUI instance to render
            pub fn render(self: *TUI) !void {
                // Clear and reuse render buffer for efficiency
                self.render_buffer.clearRetainingCapacity();
                const writer = self.render_buffer.writer();
                
                // Get screen changes efficiently
                const diff_cells = try self.screen.get_diff(self.allocator);
                defer self.allocator.free(diff_cells);
                
                // Batch rendering commands for performance
                var last_style: ?Style = null;
                var last_pos: ?Point = null;
                
                for (diff_cells) |diff_cell| {
                    const pos = Point.new(diff_cell.x, diff_cell.y);
                    const cell = diff_cell.cell;
                    
                    // Optimize cursor movement - only move if not sequential
                    const needs_move = if (last_pos) |prev| 
                        (pos.x != prev.x + 1 or pos.y != prev.y)
                    else 
                        true;
                    
                    if (needs_move) {
                        // ESC[y;xH - cursor position (1-indexed)
                        try writer.print("\x1b[{d};{d}H", .{ pos.y + 1, pos.x + 1 });
                    }
                    
                    // Apply style changes only if different from last
                    if (last_style == null or !styleEqual(last_style.?, cell.style)) {
                        // Reset attributes
                        try writer.writeAll("\x1b[0m");
                        
                        // Apply new style
                        if (cell.style.attrs.isSet()) {
                            try cell.style.attrs.writeAnsi(writer);
                        }
                        
                        // Apply colors
                        try cell.style.fg.writeAnsiRgb(writer, true);
                        try cell.style.bg.writeAnsiRgb(writer, false);
                        
                        last_style = cell.style;
                    }
                    
                    // Write character
                    if (cell.char == 0 or cell.char == ' ') {
                        try writer.writeByte(' ');
                    } else {
                        var utf8_buf: [4]u8 = undefined;
                        const len = try std.unicode.utf8Encode(cell.char, &utf8_buf);
                        try writer.writeAll(utf8_buf[0..len]);
                    }
                    
                    last_pos = pos;
                }
                
                // Write entire buffer to terminal at once
                if (self.render_buffer.items.len > 0) {
                    try self.terminal.write(self.render_buffer.items);
                    self.screen.swap_buffers();
                    try self.terminal.flush();
                }
            }
            
            /// Check if two styles are equal.
            fn styleEqual(a: Style, b: Style) bool {
                return std.meta.eql(a, b);
            }
        };
    
    // └────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────── Convenience Functions ───────────────────────┐
    
        /// Initialize TUI with default settings.
        ///
        /// __Parameters__
        ///
        /// - `allocator`: Memory allocator for TUI components
        ///
        /// __Return__
        ///
        /// - Initialized TUI instance or error
        pub fn init(allocator: std.mem.Allocator) !TUI {
            return initWithConfig(allocator, .{});
        }
        
        /// Configuration options for TUI initialization.
        pub const Config = struct {
            target_fps: u32 = 60,
            initial_buffer_capacity: usize = 4096,
            enable_mouse: bool = true,
            enable_bracketed_paste: bool = true,
        };
        
        /// Initialize TUI with custom configuration.
        ///
        /// __Parameters__
        ///
        /// - `allocator`: Memory allocator for TUI components
        /// - `config`: Configuration options
        ///
        /// __Return__
        ///
        /// - Initialized TUI instance or error
        pub fn initWithConfig(allocator: std.mem.Allocator, config: Config) !TUI {
            // Validate configuration
            if (config.target_fps == 0 or config.target_fps > 240) {
                return TuiError.InvalidInput;
            }
            
            var terminal = try Terminal.init(allocator);
            errdefer terminal.deinit();
            
            // Get and validate terminal size
            const size = try terminal.get_size();
            if (size.width == 0 or size.height == 0) {
                return TuiError.InvalidDimensions;
            }
            
            var screen = try Screen.init_with_size(
                allocator,
                size.width,
                size.height
            );
            errdefer screen.deinit();
            
            var event_handler = try EventHandler.init(allocator);
            errdefer event_handler.deinit();
            
            // Configure event handler based on config
            // NOTE: Mouse and bracketed paste support would be enabled here
            // when the EventHandler module supports these features.
            _ = config.enable_mouse;
            _ = config.enable_bracketed_paste;
            
            // Pre-allocate render buffer
            var render_buffer = try std.ArrayList(u8).initCapacity(
                allocator,
                config.initial_buffer_capacity
            );
            errdefer render_buffer.deinit();
            
            return TUI{
                .allocator = allocator,
                .terminal = terminal,
                .screen = screen,
                .event_handler = event_handler,
                .running = std.atomic.Value(bool).init(false),
                .render_buffer = render_buffer,
                .last_render_time = 0,
                .target_fps = config.target_fps,
            };
        }
        
        /// Quick setup for simple applications.
        ///
        /// __Parameters__
        ///
        /// - `allocator`: Memory allocator for TUI components
        pub fn quickStart(allocator: std.mem.Allocator) !void {
            var tui = try init(allocator);
            defer tui.deinit();
            
            // Run the main loop (terminal setup is handled in run())
            try tui.run();
        }
        
        /// Quick setup with custom configuration.
        ///
        /// __Parameters__
        ///
        /// - `allocator`: Memory allocator for TUI components
        /// - `config`: Configuration options
        pub fn quickStartWithConfig(
            allocator: std.mem.Allocator,
            config: Config,
        ) !void {
            var tui = try initWithConfig(allocator, config);
            defer tui.deinit();
            
            try tui.run();
        }
        
        /// Deinitialize a TUI instance.
        ///
        /// __Parameters__
        ///
        /// - `tui`: TUI instance to deinitialize
        pub fn deinit(tui: *TUI) void {
            tui.deinit();
        }
    
    // └────────────────────────────────────────────────────────────────────────┘

// ╚════════════════════════════════════════════════════════════════════════════════════════╝