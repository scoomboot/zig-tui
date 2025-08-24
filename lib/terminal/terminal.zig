// terminal.zig — Core terminal abstraction
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://fisty.github.io/zig-tui/terminal
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const RawMode = @import("utils/raw_mode/raw_mode.zig").RawMode;
    const ansi = @import("utils/ansi/ansi.zig");
    const os = std.os;
    const posix = std.posix;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    pub const TerminalError = error{
        InitFailed,
        NotATTY,
        GetSizeFailed,
        WriteFailed,
        RawModeFailed,
        ResizeMonitoringFailed,
        CallbackRegistrationFailed,
        InvalidSize,
        ThreadCreationFailed,
        SignalHandlingFailed,
        ANSIQueryFailed,
        DeviceStatusReportFailed,
    };

    pub const Size = struct {
        rows: u16,
        cols: u16,

        /// Check if size is equal to another size.
        ///
        /// Compares both rows and columns for exact equality.
        ///
        /// __Parameters__
        ///
        /// - `self`: The first Size instance to compare
        /// - `other`: The second Size instance to compare
        ///
        /// __Return__
        ///
        /// - `bool`: True if both dimensions are equal, false otherwise
        pub fn eql(self: Size, other: Size) bool {
            return self.rows == other.rows and self.cols == other.cols;
        }

        /// Check if size is valid (non-zero dimensions).
        ///
        /// Validates that both rows and columns are greater than zero.
        ///
        /// __Parameters__
        ///
        /// - `self`: Size instance to validate
        ///
        /// __Return__
        ///
        /// - `bool`: True if both dimensions are greater than zero, false otherwise
        pub fn isValid(self: Size) bool {
            return self.rows > 0 and self.cols > 0;
        }
    };

    pub const SizeConstraints = struct {
        min_rows: u16 = 1,
        min_cols: u16 = 1,
        max_rows: u16 = 9999,
        max_cols: u16 = 9999,

        /// Apply constraints to a size, clamping to valid range.
        ///
        /// Clamps the provided size dimensions to fit within the minimum
        /// and maximum constraints defined in this SizeConstraints instance.
        ///
        /// __Parameters__
        ///
        /// - `self`: SizeConstraints instance containing min/max limits
        /// - `size`: Size to apply constraints to
        ///
        /// __Return__
        ///
        /// - `Size`: New Size with dimensions clamped to constraint bounds
        pub fn apply(self: SizeConstraints, size: Size) Size {
            return Size{
                .rows = @max(self.min_rows, @min(self.max_rows, size.rows)),
                .cols = @max(self.min_cols, @min(self.max_cols, size.cols)),
            };
        }

        /// Check if a size meets the constraints.
        ///
        /// Validates that the size dimensions fall within the minimum
        /// and maximum bounds defined by this SizeConstraints instance.
        ///
        /// __Parameters__
        ///
        /// - `self`: SizeConstraints instance containing validation bounds
        /// - `size`: Size to validate against constraints
        ///
        /// __Return__
        ///
        /// - `bool`: True if size is within bounds, false otherwise
        pub fn validate(self: SizeConstraints, size: Size) bool {
            return size.rows >= self.min_rows and size.rows <= self.max_rows and
                   size.cols >= self.min_cols and size.cols <= self.max_cols;
        }
    };

    pub const ResizeEvent = struct {
        old_size: Size,
        new_size: Size,
        timestamp: i64,

        /// Create a new resize event with current timestamp.
        ///
        /// Initializes a ResizeEvent with the provided size transition
        /// and sets the timestamp to the current system time in milliseconds.
        ///
        /// __Parameters__
        ///
        /// - `old_size`: Terminal size before the resize event
        /// - `new_size`: Terminal size after the resize event
        ///
        /// __Return__
        ///
        /// - `ResizeEvent`: New event instance with current timestamp
        pub fn init(old_size: Size, new_size: Size) ResizeEvent {
            return ResizeEvent{
                .old_size = old_size,
                .new_size = new_size,
                .timestamp = std.time.milliTimestamp(),
            };
        }
    };

    pub const ResizeCallback = *const fn (event: ResizeEvent) void;

    pub const CursorStyle = enum {
        default,
        block,
        underline,
        bar,
        blinking_block,
        blinking_underline,
        blinking_bar,
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    pub const Terminal = struct {
        allocator: std.mem.Allocator,
        raw_mode: RawMode,
        stdout: std.fs.File,
        stdin: std.fs.File,
        is_raw: bool,
        use_alt_screen: bool,
        cursor_visible: bool,
        size: Size,
        ansi_builder: ansi.Ansi,
        
        // Size detection and caching
        size_cache: ?Size,
        size_constraints: SizeConstraints,
        
        // Resize monitoring and callbacks
        resize_callbacks: std.ArrayList(ResizeCallback),
        resize_thread: ?std.Thread,
        resize_mutex: std.Thread.Mutex,
        resize_monitoring: bool,

        // ┌──────────────────────────── Initialization ────────────────────────────┐

            /// Initialize terminal with default settings
            pub fn init(allocator: std.mem.Allocator) !Terminal {
                const stdout = std.io.getStdOut();
                const stdin = std.io.getStdIn();

                // Check if we're connected to a terminal
                // In test environments, we allow non-TTY initialization
                const is_test = @import("builtin").is_test;
                if (!is_test and !posix.isatty(stdout.handle)) {
                    return TerminalError.NotATTY;
                }

                // Get size - use fallback if not a TTY  
                // Create a temporary terminal for size query
                var temp_term = Terminal{
                    .allocator = allocator,
                    .raw_mode = RawMode.init(),
                    .stdout = stdout,
                    .stdin = stdin,
                    .is_raw = false,
                    .use_alt_screen = false,
                    .cursor_visible = true,
                    .size = Size{ .rows = 24, .cols = 80 }, // Temporary default
                    .ansi_builder = ansi.Ansi.init(allocator),
                    .size_cache = null,
                    .size_constraints = SizeConstraints{},
                    .resize_callbacks = std.ArrayList(ResizeCallback).init(allocator),
                    .resize_thread = null,
                    .resize_mutex = .{},
                    .resize_monitoring = false,
                };
                defer temp_term.resize_callbacks.deinit();
                defer temp_term.ansi_builder.deinit();

                const size = if (posix.isatty(stdout.handle)) 
                    temp_term.querySize() catch Size{ .rows = 24, .cols = 80 }
                else 
                    Size{ .rows = 24, .cols = 80 };

                var term = Terminal{
                    .allocator = allocator,
                    .raw_mode = RawMode.init(),
                    .stdout = stdout,
                    .stdin = stdin,
                    .is_raw = false,
                    .use_alt_screen = false,
                    .cursor_visible = true,
                    .size = size,
                    .ansi_builder = ansi.Ansi.init(allocator),
                    
                    // Initialize size detection and caching
                    .size_cache = size,
                    .size_constraints = SizeConstraints{},
                    
                    // Initialize resize monitoring
                    .resize_callbacks = std.ArrayList(ResizeCallback).init(allocator),
                    .resize_thread = null,
                    .resize_mutex = .{},
                    .resize_monitoring = false,
                };

                // Set up signal handlers for cleanup
                try term.setupSignalHandlers();

                return term;
            }

            /// Clean up and restore terminal state
            pub fn deinit(self: *Terminal) void {
                // Stop resize monitoring if active
                if (self.resize_monitoring) {
                    self.stopResizeMonitoring() catch {};
                }

                // Exit raw mode if active
                if (self.is_raw) {
                    self.exitRawMode() catch {};
                }

                // Exit alternative screen if active
                if (self.use_alt_screen) {
                    self.exitAltScreen() catch {};
                }

                // Show cursor if hidden
                if (!self.cursor_visible) {
                    self.showCursor() catch {};
                }

                // Clean up resize callbacks
                self.resize_callbacks.deinit();

                // Clean up ANSI builder
                self.ansi_builder.deinit();
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Mode Control ────────────────────────────┐

            /// Enter raw mode for direct input handling
            pub fn enterRawMode(self: *Terminal) !void {
                if (self.is_raw) return;
                
                // In test mode, skip actual raw mode operations
                const is_test = @import("builtin").is_test;
                if (!is_test) {
                    try self.raw_mode.enter();
                }
                self.is_raw = true;
            }

            /// Exit raw mode and restore normal terminal behavior
            pub fn exitRawMode(self: *Terminal) !void {
                if (!self.is_raw) return;
                
                // In test mode, skip actual raw mode operations
                const is_test = @import("builtin").is_test;
                if (!is_test) {
                    try self.raw_mode.exit();
                }
                self.is_raw = false;
            }

            /// Switch to alternative screen buffer
            pub fn enterAltScreen(self: *Terminal) !void {
                if (self.use_alt_screen) return;
                
                try self.writeSequence(ansi.ALT_SCREEN);
                self.use_alt_screen = true;
            }

            /// Return to main screen buffer
            pub fn exitAltScreen(self: *Terminal) !void {
                if (!self.use_alt_screen) return;
                
                try self.writeSequence(ansi.MAIN_SCREEN);
                self.use_alt_screen = false;
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Screen Operations ────────────────────────────┐

            /// Clear entire screen
            pub fn clear(self: *Terminal) !void {
                try self.writeSequence(ansi.CLEAR_SCREEN);
                try self.setCursorPos(1, 1);
            }

            /// Clear current line
            pub fn clearLine(self: *Terminal) !void {
                try self.writeSequence(ansi.CLEAR_LINE);
            }

            /// Get terminal size with caching and fallback strategies.
            ///
            /// Uses multiple detection methods in order of preference:
            /// cached size validation, system ioctl, ANSI query, environment
            /// variables, and fallback defaults. Applies size constraints
            /// and updates internal cache upon successful detection.
            ///
            /// __Parameters__
            ///
            /// - `self`: Terminal instance pointer
            ///
            /// __Return__
            ///
            /// - `Size`: Terminal dimensions with constraints applied
            /// - `TerminalError.GetSizeFailed`: If all detection methods fail
            /// - `TerminalError.InvalidSize`: If detected size is invalid
            pub fn getSize(self: *Terminal) !Size {
                // Try to get cached size first if still valid
                if (self.size_cache) |cached_size| {
                    // Validate that cached size is still reasonable
                    if (self.size_constraints.validate(cached_size)) {
                        return cached_size;
                    }
                }

                // Query new size using multiple methods
                const new_size = try self.querySize();
                
                // Apply constraints and cache the result
                const constrained_size = self.size_constraints.apply(new_size);
                self.size_cache = constrained_size;
                self.size = constrained_size;
                
                return constrained_size;
            }

            /// Force refresh of terminal size without using cache.
            ///
            /// Invalidates the size cache and queries the terminal size using
            /// all available detection methods. Useful when you need to ensure
            /// the most up-to-date size information.
            ///
            /// __Parameters__
            ///
            /// - `self`: Terminal instance pointer
            ///
            /// __Return__
            ///
            /// - `Size`: Current terminal dimensions with constraints applied
            /// - `TerminalError.GetSizeFailed`: If all detection methods fail
            /// - `TerminalError.InvalidSize`: If detected size is invalid
            pub fn refreshSize(self: *Terminal) !Size {
                self.size_cache = null;
                return self.getSize();
            }

            /// Set size constraints for validation.
            ///
            /// Updates the terminal's size constraints and invalidates the
            /// size cache to force revalidation on the next getSize() call.
            /// Constraints are applied to all future size queries.
            ///
            /// __Parameters__
            ///
            /// - `self`: Terminal instance pointer
            /// - `constraints`: New size constraints to apply
            ///
            /// __Return__
            ///
            /// - `void`: This function does not return a value
            pub fn setSizeConstraints(self: *Terminal, constraints: SizeConstraints) void {
                self.size_constraints = constraints;
                // Invalidate cache to force revalidation
                self.size_cache = null;
            }

            /// Flush output buffer
            pub fn flush(self: *Terminal) !void {
                // Stdout is unbuffered in raw mode, but flush anyway
                // In test mode or when not a TTY, skip sync operation
                const is_test = @import("builtin").is_test;
                if (!is_test and posix.isatty(self.stdout.handle)) {
                    self.stdout.sync() catch {
                        // Ignore sync errors for non-file streams
                    };
                }
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Cursor Control ────────────────────────────┐

            /// Set cursor position (1-based)
            pub fn setCursorPos(self: *Terminal, row: u16, col: u16) !void {
                self.ansi_builder.clear();
                try self.ansi_builder.moveTo(row, col);
                try self.writeSequence(self.ansi_builder.getSequence());
            }

            /// Hide cursor
            pub fn hideCursor(self: *Terminal) !void {
                if (!self.cursor_visible) return;
                
                try self.writeSequence(ansi.HIDE_CURSOR);
                self.cursor_visible = false;
            }

            /// Show cursor
            pub fn showCursor(self: *Terminal) !void {
                if (self.cursor_visible) return;
                
                try self.writeSequence(ansi.SHOW_CURSOR);
                self.cursor_visible = true;
            }

            /// Set cursor style
            pub fn setCursorStyle(self: *Terminal, style: CursorStyle) !void {
                const seq = switch (style) {
                    .default => ansi.CSI ++ "0 q",
                    .block => ansi.CSI ++ "2 q",
                    .underline => ansi.CSI ++ "4 q",
                    .bar => ansi.CSI ++ "6 q",
                    .blinking_block => ansi.CSI ++ "1 q",
                    .blinking_underline => ansi.CSI ++ "3 q",
                    .blinking_bar => ansi.CSI ++ "5 q",
                };
                try self.writeSequence(seq);
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Internal Helpers ────────────────────────────┐

            fn writeSequence(self: *Terminal, seq: []const u8) !void {
                _ = try self.stdout.write(seq);
            }

            /// Query terminal size using multiple fallback methods
            fn querySize(self: *Terminal) !Size {
                // Multi-tier fallback strategy for robust size detection:
                // - Tier 1: System-specific APIs (ioctl/Windows Console API) - most reliable
                // - Tier 2: ANSI escape sequence query - works in most terminals
                // - Tier 3: Environment variables (LINES/COLUMNS) - basic fallback
                // - Tier 4: Default 80x24 - guaranteed fallback for any environment
                
                // Try system-specific method first (fastest and most reliable)
                if (self.querySizeSystem()) |size| {
                    if (size.isValid()) {
                        return self.validateSize(size);
                    }
                } else |_| {
                    // System method failed, continue to fallbacks
                }

                // Try ANSI escape sequence method
                if (self.querySizeANSI()) |size| {
                    if (size.isValid()) {
                        return self.validateSize(size);
                    }
                } else |_| {
                    // ANSI method failed, continue to fallbacks
                }

                // Try environment variables
                if (self.querySizeEnv()) |size| {
                    if (size.isValid()) {
                        return self.validateSize(size);
                    }
                } else |_| {
                    // Environment method failed, use default
                }

                // Final fallback to standard terminal size
                return self.validateSize(Size{ .rows = 24, .cols = 80 });
            }

            /// Query terminal size using system-specific methods
            fn querySizeSystem(self: *Terminal) TerminalError!Size {
                if (@import("builtin").os.tag == .windows) {
                    return self.querySizeWindows();
                } else {
                    return self.querySizeUnix();
                }
            }

            /// Query size using Unix ioctl (POSIX systems)
            fn querySizeUnix(self: *Terminal) TerminalError!Size {
                _ = self;
                
                const stdout_handle = std.io.getStdOut().handle;
                
                if (@hasDecl(posix.system, "winsize")) {
                    var ws: posix.system.winsize = undefined;
                    const result = posix.system.ioctl(stdout_handle, posix.system.T.IOCGWINSZ, @intFromPtr(&ws));
                    if (result != 0) {
                        return TerminalError.GetSizeFailed;
                    }
                    
                    return Size{
                        .rows = ws.ws_row,
                        .cols = ws.ws_col,
                    };
                } else {
                    return TerminalError.GetSizeFailed;
                }
            }

            /// Query size using Windows console API
            fn querySizeWindows(self: *Terminal) TerminalError!Size {
                _ = self;
                
                if (@import("builtin").os.tag != .windows) {
                    return TerminalError.GetSizeFailed;
                }

                const windows = std.os.windows;
                const kernel32 = windows.kernel32;

                // Get console screen buffer info
                const handle = kernel32.GetStdHandle(windows.STD_OUTPUT_HANDLE) catch {
                    return TerminalError.GetSizeFailed;
                };

                var csbi: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
                if (kernel32.GetConsoleScreenBufferInfo(handle, &csbi) == 0) {
                    return TerminalError.GetSizeFailed;
                }

                const rows = @as(u16, @intCast(csbi.srWindow.Bottom - csbi.srWindow.Top + 1));
                const cols = @as(u16, @intCast(csbi.srWindow.Right - csbi.srWindow.Left + 1));

                return Size{ .rows = rows, .cols = cols };
            }

            /// Query size using ANSI escape sequences (Device Status Report)
            fn querySizeANSI(self: *Terminal) TerminalError!Size {
                // This method uses cursor positioning to detect terminal boundaries
                // Save cursor position
                self.writeSequence(ansi.SAVE_CURSOR) catch {
                    return TerminalError.ANSIQueryFailed;
                };
                
                // Move to bottom-right corner (999,999 - terminal will clamp to actual size)
                self.writeSequence(ansi.CSI ++ "999;999H") catch {
                    return TerminalError.ANSIQueryFailed;
                };
                
                // Query cursor position
                self.writeSequence(ansi.CSI ++ "6n") catch {
                    return TerminalError.ANSIQueryFailed;
                };
                
                // Try to read the device status report
                var buffer: [32]u8 = undefined;
                const bytes_read = self.stdin.read(&buffer) catch {
                    // Restore cursor and fail
                    self.writeSequence(ansi.RESTORE_CURSOR) catch {};
                    return TerminalError.ANSIQueryFailed;
                };
                
                // Restore cursor position
                self.writeSequence(ansi.RESTORE_CURSOR) catch {
                    return TerminalError.ANSIQueryFailed;
                };
                
                // Parse the response: ESC[row;colR
                const response = buffer[0..bytes_read];
                return self.parseDeviceStatusReport(response);
            }

            /// Parse Device Status Report response to extract terminal size
            fn parseDeviceStatusReport(self: *Terminal, response: []const u8) TerminalError!Size {
                _ = self;
                
                // Expected format: ESC[row;colR or CSI row;colR
                if (response.len < 6) {
                    return TerminalError.DeviceStatusReportFailed;
                }
                
                // Find the start of the CSI sequence
                var start: usize = 0;
                if (response.len >= 2 and response[0] == 0x1B and response[1] == '[') {
                    start = 2; // Skip ESC[
                } else if (response.len >= 1 and response[0] == 0x9B) {
                    start = 1; // Skip CSI
                } else {
                    return TerminalError.DeviceStatusReportFailed;
                }
                
                // Find semicolon separator
                var semicolon_pos: ?usize = null;
                var end_pos: ?usize = null;
                
                for (start..response.len) |i| {
                    if (response[i] == ';' and semicolon_pos == null) {
                        semicolon_pos = i;
                    } else if (response[i] == 'R') {
                        end_pos = i;
                        break;
                    }
                }
                
                const semi_pos = semicolon_pos orelse return TerminalError.DeviceStatusReportFailed;
                const final_pos = end_pos orelse return TerminalError.DeviceStatusReportFailed;
                
                // Parse row and column values
                const row_str = response[start..semi_pos];
                const col_str = response[semi_pos + 1..final_pos];
                
                const rows = std.fmt.parseInt(u16, row_str, 10) catch {
                    return TerminalError.DeviceStatusReportFailed;
                };
                const cols = std.fmt.parseInt(u16, col_str, 10) catch {
                    return TerminalError.DeviceStatusReportFailed;
                };
                
                return Size{ .rows = rows, .cols = cols };
            }

            /// Query size from environment variables (LINES, COLUMNS)
            fn querySizeEnv(self: *Terminal) TerminalError!Size {
                _ = self;
                
                const lines_str = std.posix.getenv("LINES") orelse return TerminalError.GetSizeFailed;
                const columns_str = std.posix.getenv("COLUMNS") orelse return TerminalError.GetSizeFailed;
                
                const rows = std.fmt.parseInt(u16, lines_str, 10) catch {
                    return TerminalError.GetSizeFailed;
                };
                const cols = std.fmt.parseInt(u16, columns_str, 10) catch {
                    return TerminalError.GetSizeFailed;
                };
                
                return Size{ .rows = rows, .cols = cols };
            }

            /// Validate and apply constraints to a size
            fn validateSize(self: *Terminal, size: Size) TerminalError!Size {
                if (!size.isValid()) {
                    return TerminalError.InvalidSize;
                }
                
                return self.size_constraints.apply(size);
            }

            fn setupSignalHandlers(self: *Terminal) !void {
                // Signal handling is already managed by RawMode module
                // This is a placeholder for any terminal-specific signal handling
                _ = self;
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Resize Monitoring ────────────────────────────┐

            /// Start monitoring terminal resize events.
            ///
            /// Begins platform-specific resize monitoring using SIGWINCH on Unix
            /// systems or console events polling on Windows. Creates necessary
            /// background threads and signal handlers for event detection.
            ///
            /// __Parameters__
            ///
            /// - `self`: Terminal instance pointer
            ///
            /// __Return__
            ///
            /// - `void`: Success, monitoring is now active
            /// - `TerminalError.ResizeMonitoringFailed`: Platform-specific monitoring setup failed
            /// - `TerminalError.ThreadCreationFailed`: Failed to create monitoring thread (Windows)
            /// - `TerminalError.SignalHandlingFailed`: Failed to install signal handler (Unix)
            pub fn startResizeMonitoring(self: *Terminal) !void {
                if (self.resize_monitoring) return;

                self.resize_mutex.lock();
                defer self.resize_mutex.unlock();

                if (@import("builtin").os.tag == .windows) {
                    try self.startWindowsResizeMonitoring();
                } else {
                    try self.startUnixResizeMonitoring();
                }

                self.resize_monitoring = true;
            }

            /// Stop monitoring terminal resize events.
            ///
            /// Cleanly shuts down resize monitoring by restoring default signal
            /// handlers on Unix or terminating monitoring threads on Windows.
            /// Ensures all monitoring resources are properly released.
            ///
            /// __Parameters__
            ///
            /// - `self`: Terminal instance pointer
            ///
            /// __Return__
            ///
            /// - `void`: Success, monitoring is now inactive
            /// - `TerminalError.ResizeMonitoringFailed`: Platform-specific cleanup failed
            pub fn stopResizeMonitoring(self: *Terminal) !void {
                if (!self.resize_monitoring) return;

                self.resize_mutex.lock();
                defer self.resize_mutex.unlock();

                if (@import("builtin").os.tag == .windows) {
                    try self.stopWindowsResizeMonitoring();
                } else {
                    try self.stopUnixResizeMonitoring();
                }

                self.resize_monitoring = false;
            }

            /// Register a callback for resize events.
            ///
            /// Adds a callback function to be invoked whenever a terminal resize
            /// event occurs. Callbacks are called in registration order with
            /// ResizeEvent containing old and new dimensions.
            ///
            /// __Parameters__
            ///
            /// - `self`: Terminal instance pointer
            /// - `callback`: Function pointer to invoke on resize events
            ///
            /// __Return__
            ///
            /// - `void`: Callback successfully registered
            /// - `std.mem.Allocator.Error.OutOfMemory`: Failed to allocate callback storage
            pub fn onResize(self: *Terminal, callback: ResizeCallback) !void {
                self.resize_mutex.lock();
                defer self.resize_mutex.unlock();

                try self.resize_callbacks.append(callback);
            }

            /// Remove a callback for resize events.
            ///
            /// Removes the first matching callback from the resize callback list.
            /// If the callback is not found, the function returns without error.
            /// Uses pointer equality for callback matching.
            ///
            /// __Parameters__
            ///
            /// - `self`: Terminal instance pointer
            /// - `callback`: Function pointer to remove from callback list
            ///
            /// __Return__
            ///
            /// - `void`: This function does not return a value
            pub fn removeResizeCallback(self: *Terminal, callback: ResizeCallback) void {
                self.resize_mutex.lock();
                defer self.resize_mutex.unlock();

                for (self.resize_callbacks.items, 0..) |cb, i| {
                    if (cb == callback) {
                        _ = self.resize_callbacks.orderedRemove(i);
                        break;
                    }
                }
            }

            /// Handle a terminal resize event
            pub fn handleResize(self: *Terminal, new_size: Size) void {
                self.resize_mutex.lock();
                defer self.resize_mutex.unlock();

                const old_size = self.size;
                
                // Apply size constraints to the new size
                const constrained_size = self.size_constraints.apply(new_size);
                
                if (old_size.eql(constrained_size)) return; // No actual change

                // Update internal size state
                self.size = constrained_size;
                self.size_cache = constrained_size;

                // Create resize event
                const event = ResizeEvent.init(old_size, constrained_size);

                // Notify all callbacks
                for (self.resize_callbacks.items) |callback| {
                    callback(event);
                }
            }

            /// Start Unix resize monitoring (SIGWINCH)
            fn startUnixResizeMonitoring(self: *Terminal) !void {
                // Install SIGWINCH handler
                const handler = posix.Sigaction{
                    .handler = .{ .handler = handleSigwinch },
                    .mask = posix.empty_sigset,
                    .flags = posix.SA.RESTART,
                };

                // Store previous handler (for restoration)
                _ = posix.sigaction(posix.SIG.WINCH, &handler, null);

                // Store terminal reference globally for signal handler access
                setGlobalTerminalForSignals(self);
            }

            /// Stop Unix resize monitoring
            fn stopUnixResizeMonitoring(self: *Terminal) !void {
                // Restore default SIGWINCH handler
                const default_handler = posix.Sigaction{
                    .handler = .{ .handler = posix.SIG.DFL },
                    .mask = posix.empty_sigset,
                    .flags = 0,
                };

                _ = posix.sigaction(posix.SIG.WINCH, &default_handler, null);

                clearGlobalTerminalForSignals();
                _ = self;
            }

            /// Start Windows resize monitoring (console events in thread)
            fn startWindowsResizeMonitoring(self: *Terminal) !void {
                if (@import("builtin").os.tag != .windows) {
                    return TerminalError.ResizeMonitoringFailed;
                }

                // Create monitoring thread
                self.resize_thread = std.Thread.spawn(.{}, monitorWindowsResize, .{self}) catch {
                    return TerminalError.ThreadCreationFailed;
                };
            }

            /// Stop Windows resize monitoring
            fn stopWindowsResizeMonitoring(self: *Terminal) !void {
                if (self.resize_thread) |thread| {
                    // Signal thread to stop and wait for it to finish
                    thread.join();
                    self.resize_thread = null;
                }
            }

            /// Windows resize monitoring thread function
            fn monitorWindowsResize(self: *Terminal) void {
                if (@import("builtin").os.tag != .windows) return;

                const windows = std.os.windows;
                const kernel32 = windows.kernel32;

                // Get console input handle for potential future use
                _ = kernel32.GetStdHandle(windows.STD_INPUT_HANDLE) catch {
                    return;
                };

                var last_size = self.getSize() catch return;

                while (self.resize_monitoring) {
                    // Poll for console size changes
                    std.time.sleep(50 * std.time.ns_per_ms); // Check every 50ms

                    if (self.querySizeWindows()) |current_size| {
                        if (!last_size.eql(current_size)) {
                            self.handleResize(current_size);
                            last_size = current_size;
                        }
                    } else |_| {
                        // Error getting size, continue monitoring
                    }
                }
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Compatibility Methods ────────────────────────────┐

            // These methods provide backward compatibility with the old API
            
            /// Enter raw mode (old API compatibility)
            pub fn enter_raw_mode(self: *Terminal) !void {
                return self.enterRawMode();
            }

            /// Exit raw mode (old API compatibility)
            pub fn exit_raw_mode(self: *Terminal) !void {
                return self.exitRawMode();
            }

            /// Check if in raw mode (old API compatibility)
            pub fn is_raw_mode(self: *Terminal) bool {
                return self.is_raw;
            }

            /// Get terminal size (old API compatibility)
            pub fn get_size(self: *Terminal) !Size {
                return self.getSize();
            }

            /// Move cursor to position (old API compatibility)
            pub fn move_cursor(self: *Terminal, pos: Position) !void {
                return self.setCursorPos(pos.y, pos.x);
            }

            /// Hide cursor (old API compatibility)
            pub fn hide_cursor(self: *Terminal) !void {
                return self.hideCursor();
            }

            /// Show cursor (old API compatibility)
            pub fn show_cursor(self: *Terminal) !void {
                return self.showCursor();
            }

            /// Set cursor style (old API compatibility)
            pub fn set_cursor_style(self: *Terminal, style: CursorStyle) !void {
                return self.setCursorStyle(style);
            }

            /// Enter alternative screen buffer (old API compatibility)
            pub fn enter_alt_screen(self: *Terminal) !void {
                return self.enterAltScreen();
            }

            /// Exit alternative screen buffer (old API compatibility)  
            pub fn exit_alt_screen(self: *Terminal) !void {
                return self.exitAltScreen();
            }

            /// Write text at current position (old API compatibility)
            pub fn write(self: *Terminal, text: []const u8) !void {
                try self.stdout.writeAll(text);
            }

        // └──────────────────────────────────────────────────────────────────┘

    };

    // ┌──────────────────────────── Global Signal Handling ────────────────────────────┐

        // Global terminal reference for signal handling
        var global_terminal_for_signals: ?*Terminal = null;
        var global_signal_mutex: std.Thread.Mutex = .{};

        /// Set global terminal reference for signal handling
        fn setGlobalTerminalForSignals(terminal: *Terminal) void {
            global_signal_mutex.lock();
            defer global_signal_mutex.unlock();
            global_terminal_for_signals = terminal;
        }

        /// Clear global terminal reference
        fn clearGlobalTerminalForSignals() void {
            global_signal_mutex.lock();
            defer global_signal_mutex.unlock();
            global_terminal_for_signals = null;
        }

        /// SIGWINCH signal handler
        fn handleSigwinch(sig: c_int) callconv(.C) void {
            _ = sig;

            global_signal_mutex.lock();
            defer global_signal_mutex.unlock();

            if (global_terminal_for_signals) |terminal| {
                // Get new terminal size
                if (terminal.refreshSize()) |new_size| {
                    // Handle resize will be called during refreshSize if size changed
                    _ = new_size;
                } else |_| {
                    // Error getting size, ignore for signal handler safety
                }
            }
        }

    // └──────────────────────────────────────────────────────────────────────────┘

    // Position struct for backward compatibility
    pub const Position = struct {
        x: u16,
        y: u16,
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝