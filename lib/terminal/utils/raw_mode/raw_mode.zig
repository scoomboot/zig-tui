// raw_mode.zig — Terminal raw mode management
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by fisty.
//
// Features:
// - Cross-platform raw mode management (POSIX & Windows)
// - Automatic terminal restoration on signals (SIGINT, SIGTERM, etc.)
// - Global cleanup handler for unexpected exits
// - Thread-safe global instance tracking
// - Configurable read timeouts and minimum character counts

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const builtin = @import("builtin");
    const os = std.os;
    const posix = std.posix;

// ╚════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    /// Error set for raw mode operations
    pub const RawModeError = error{
        AlreadyInRawMode,
        NotInRawMode,
        TerminalNotAvailable,
        SystemCallFailed,
        UnsupportedPlatform,
        SignalHandlerFailed,
    };

    /// Platform-specific terminal state
    pub const TerminalState = if (builtin.os.tag == .windows)
        struct {
            original_mode: u32,
            is_raw: bool,
        }
    else
        struct {
            original_termios: posix.termios,
            is_raw: bool,
        };

    // Global state for signal handling and cleanup
    var global_raw_mode: ?*RawMode = null;
    var global_mutex: std.Thread.Mutex = .{};
    var signal_handlers_installed: bool = false;

// ╚════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Raw mode manager for terminal input/output
    pub const RawMode = struct {
        state: TerminalState,
        stdin_fd: posix.fd_t,

        // ┌────────────────────────────────── Init ──────────────────────────────────┐
        // └──────────────────────────────────────────────────────────────────────────┘

        /// Initialize a new RawMode instance
        ///
        /// __Parameters__
        /// None
        ///
        /// __Return__
        /// A new RawMode instance with default settings
        pub fn init() RawMode {
            return .{
                .state = if (builtin.os.tag == .windows)
                    TerminalState{ .original_mode = 0, .is_raw = false }
                else
                    TerminalState{ .original_termios = undefined, .is_raw = false },
                .stdin_fd = std.io.getStdIn().handle,
            };
        }

        // ┌───────────────────────────── Mode Control ───────────────────────────────┐
        // └──────────────────────────────────────────────────────────────────────────┘

        /// Enter raw mode
        ///
        /// __Parameters__
        /// - self: Mutable reference to RawMode instance
        ///
        /// __Return__
        /// Error if already in raw mode or system call fails, void otherwise
        pub fn enter(self: *RawMode) RawModeError!void {
            if (self.state.is_raw) {
                return RawModeError.AlreadyInRawMode;
            }

            // Register this instance as the global one for signal handling
            try self.registerGlobal();

            if (builtin.os.tag == .windows) {
                try self.enterWindows();
            } else {
                try self.enterPosix();
                // Install signal handlers after entering raw mode on POSIX
                try installSignalHandlers();
            }

            self.state.is_raw = true;
        }

        /// Exit raw mode and restore original settings
        ///
        /// __Parameters__
        /// - self: Mutable reference to RawMode instance
        ///
        /// __Return__
        /// Error if not in raw mode or system call fails, void otherwise
        pub fn exit(self: *RawMode) RawModeError!void {
            if (!self.state.is_raw) {
                return RawModeError.NotInRawMode;
            }

            if (builtin.os.tag == .windows) {
                try self.exitWindows();
            } else {
                try self.exitPosix();
            }

            self.state.is_raw = false;
            
            // Unregister from global if this was the active instance
            self.unregisterGlobal();
        }

        // ┌─────────────────────────── POSIX Implementation ─────────────────────────┐
        // └──────────────────────────────────────────────────────────────────────────┘

        fn enterPosix(self: *RawMode) RawModeError!void {
            // Get current terminal settings
            self.state.original_termios = posix.tcgetattr(self.stdin_fd) catch |err| switch (err) {
                error.NotATerminal => return RawModeError.TerminalNotAvailable,
                else => return RawModeError.SystemCallFailed,
            };

            // Create raw mode settings
            var raw = self.state.original_termios;

            // Input flags - disable break processing, CR to NL translation, 
            // parity checking, strip high bit, and flow control
            raw.iflag.IGNBRK = false;
            raw.iflag.BRKINT = false;
            raw.iflag.PARMRK = false;
            raw.iflag.ISTRIP = false;
            raw.iflag.INLCR = false;
            raw.iflag.IGNCR = false;
            raw.iflag.ICRNL = false;
            raw.iflag.IXON = false;

            // Output flags - disable output processing
            raw.oflag.OPOST = false;

            // Control flags - set 8 bit chars, disable parity
            raw.cflag.CSIZE = .CS8;
            raw.cflag.PARENB = false;

            // Local flags - disable echo, canonical mode, signals, and extended functions
            raw.lflag.ECHO = false;
            raw.lflag.ECHONL = false;
            raw.lflag.ICANON = false;
            raw.lflag.ISIG = false;
            raw.lflag.IEXTEN = false;

            // Control characters - set minimum bytes and timeout for read
            raw.cc[@intFromEnum(posix.V.MIN)] = 1;
            raw.cc[@intFromEnum(posix.V.TIME)] = 0;

            // Apply raw mode settings
            posix.tcsetattr(self.stdin_fd, .FLUSH, raw) catch |err| switch (err) {
                error.NotATerminal => return RawModeError.TerminalNotAvailable,
                else => return RawModeError.SystemCallFailed,
            };
        }

        fn exitPosix(self: *RawMode) RawModeError!void {
            // Restore original terminal settings
            posix.tcsetattr(self.stdin_fd, .FLUSH, self.state.original_termios) catch |err| switch (err) {
                error.NotATerminal => return RawModeError.TerminalNotAvailable,
                else => return RawModeError.SystemCallFailed,
            };
        }

        // ┌────────────────────────── Windows Implementation ────────────────────────┐
        // └──────────────────────────────────────────────────────────────────────────┘

        fn enterWindows(self: *RawMode) RawModeError!void {
            // Windows console API implementation
            const windows = std.os.windows;
            const kernel32 = windows.kernel32;

            // Get console handle
            const handle = kernel32.GetStdHandle(windows.STD_INPUT_HANDLE) catch {
                return RawModeError.SystemCallFailed;
            };

            // Get current console mode
            var mode: windows.DWORD = undefined;
            if (kernel32.GetConsoleMode(handle, &mode) == 0) {
                return RawModeError.SystemCallFailed;
            }

            // Store original mode
            self.state.original_mode = mode;

            // Disable line input, echo input, and enable virtual terminal processing
            const ENABLE_LINE_INPUT = 0x0002;
            const ENABLE_ECHO_INPUT = 0x0004;
            const ENABLE_PROCESSED_INPUT = 0x0001;
            const ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200;

            mode &= ~@as(u32, ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT | ENABLE_PROCESSED_INPUT);
            mode |= ENABLE_VIRTUAL_TERMINAL_INPUT;

            // Set new console mode
            if (kernel32.SetConsoleMode(handle, mode) == 0) {
                return RawModeError.SystemCallFailed;
            }

            // Install Windows console control handler
            installWindowsConsoleHandler();
        }

        fn exitWindows(self: *RawMode) RawModeError!void {
            const windows = std.os.windows;
            const kernel32 = windows.kernel32;

            // Get console handle
            const handle = kernel32.GetStdHandle(windows.STD_INPUT_HANDLE) catch {
                return RawModeError.SystemCallFailed;
            };

            // Restore original console mode
            if (kernel32.SetConsoleMode(handle, self.state.original_mode) == 0) {
                return RawModeError.SystemCallFailed;
            }
        }

        // ┌───────────────────────────── Helper Methods ─────────────────────────────┐
        // └──────────────────────────────────────────────────────────────────────────┘

        /// Check if terminal is currently in raw mode
        ///
        /// __Parameters__
        /// - self: Const reference to RawMode instance
        ///
        /// __Return__
        /// True if in raw mode, false otherwise
        pub fn isRaw(self: *const RawMode) bool {
            return self.state.is_raw;
        }

        /// Set read timeout (in deciseconds)
        ///
        /// __Parameters__
        /// - self: Mutable reference to RawMode instance
        /// - timeout_deciseconds: Timeout value in deciseconds (0-255)
        ///
        /// __Return__
        /// Error if not in raw mode or system call fails, void otherwise
        pub fn setReadTimeout(self: *RawMode, timeout_deciseconds: u8) RawModeError!void {
            if (!self.state.is_raw) {
                return RawModeError.NotInRawMode;
            }

            if (builtin.os.tag == .windows) {
                // Windows timeout handling would go here
                return RawModeError.UnsupportedPlatform;
            } else {
                var termios = posix.tcgetattr(self.stdin_fd) catch {
                    return RawModeError.SystemCallFailed;
                };

                termios.cc[@intFromEnum(posix.V.TIME)] = timeout_deciseconds;
                termios.cc[@intFromEnum(posix.V.MIN)] = 0;

                posix.tcsetattr(self.stdin_fd, .NOW, termios) catch {
                    return RawModeError.SystemCallFailed;
                };
            }
        }

        /// Set minimum characters for read
        ///
        /// __Parameters__
        /// - self: Mutable reference to RawMode instance
        /// - min_chars: Minimum number of characters for read (0-255)
        ///
        /// __Return__
        /// Error if not in raw mode or system call fails, void otherwise
        pub fn setReadMinChars(self: *RawMode, min_chars: u8) RawModeError!void {
            if (!self.state.is_raw) {
                return RawModeError.NotInRawMode;
            }

            if (builtin.os.tag == .windows) {
                // Windows min chars handling would go here
                return RawModeError.UnsupportedPlatform;
            } else {
                var termios = posix.tcgetattr(self.stdin_fd) catch {
                    return RawModeError.SystemCallFailed;
                };

                termios.cc[@intFromEnum(posix.V.MIN)] = min_chars;

                posix.tcsetattr(self.stdin_fd, .NOW, termios) catch {
                    return RawModeError.SystemCallFailed;
                };
            }
        }

        // ┌────────────────────────── Cleanup & Registration ────────────────────────┐
        // └──────────────────────────────────────────────────────────────────────────┘

        /// Register this instance as the global active raw mode
        fn registerGlobal(self: *RawMode) RawModeError!void {
            global_mutex.lock();
            defer global_mutex.unlock();

            if (global_raw_mode != null) {
                return RawModeError.AlreadyInRawMode;
            }

            global_raw_mode = self;
        }

        /// Unregister this instance from global tracking
        fn unregisterGlobal(self: *RawMode) void {
            global_mutex.lock();
            defer global_mutex.unlock();

            if (global_raw_mode == self) {
                global_raw_mode = null;
            }
        }

        /// Force cleanup - can be called from signal handlers
        ///
        /// __Parameters__
        /// - self: Mutable reference to RawMode instance
        ///
        /// __Return__
        /// Void - errors are silently ignored for signal handler safety
        pub fn forceCleanup(self: *RawMode) void {
            if (!self.state.is_raw) return;

            if (builtin.os.tag == .windows) {
                self.exitWindows() catch {};
            } else {
                self.exitPosix() catch {};
            }

            self.state.is_raw = false;
            self.unregisterGlobal();
        }
    };

    // ┌───────────────────────────── Signal Handling ────────────────────────────┐
    // └──────────────────────────────────────────────────────────────────────────┘

    /// Install signal handlers for clean exit
    fn installSignalHandlers() RawModeError!void {
        if (builtin.os.tag == .windows) {
            // Windows uses different mechanism (SetConsoleCtrlHandler)
            return;
        }

        global_mutex.lock();
        defer global_mutex.unlock();

        if (signal_handlers_installed) return;

        // Set up signal handlers for common termination signals
        const signals_to_handle = [_]u6{
            posix.SIG.INT,  // Ctrl+C
            posix.SIG.TERM, // Termination request
            posix.SIG.HUP,  // Terminal hangup
            posix.SIG.QUIT, // Quit request
        };

        for (signals_to_handle) |sig| {
            const handler = posix.Sigaction{
                .handler = .{ .handler = signalHandler },
                .mask = posix.empty_sigset,
                .flags = 0,
            };

            posix.sigaction(sig, &handler, null);
        }

        signal_handlers_installed = true;
    }

    /// Signal handler for cleanup
    fn signalHandler(sig: c_int) callconv(.C) void {
        // Perform cleanup
        cleanupGlobalRawMode();

        // Re-raise the signal with default handler to maintain expected behavior
        const default_handler = posix.Sigaction{
            .handler = .{ .handler = posix.SIG.DFL },
            .mask = posix.empty_sigset,
            .flags = 0,
        };
        const sig_u6: u6 = @intCast(@as(u32, @intCast(sig)));
        posix.sigaction(sig_u6, &default_handler, null);
        _ = posix.raise(sig_u6) catch {};
    }

    /// Global cleanup function that can be called on exit
    ///
    /// __Parameters__
    /// None
    ///
    /// __Return__
    /// Void
    pub fn cleanupGlobalRawMode() void {
        global_mutex.lock();
        defer global_mutex.unlock();

        if (global_raw_mode) |raw_mode| {
            raw_mode.forceCleanup();
        }
    }

    /// Ensures terminal is restored on program exit
    /// Call this early in main() to set up automatic cleanup
    /// On POSIX systems, this only ensures signal handlers are ready
    /// On Windows, this installs the console control handler
    ///
    /// __Parameters__
    /// None
    ///
    /// __Return__
    /// Void
    pub fn ensureCleanupOnExit() void {
        if (builtin.os.tag == .windows) {
            // Install Windows console control handler
            installWindowsConsoleHandler();
        }
        // Note: POSIX signal handlers are installed automatically when entering raw mode
        // There's no atexit in Zig's std library, so cleanup depends on signals or manual exit() calls
    }

    // ┌────────────────────────── Windows Console Handler ───────────────────────┐
    // └──────────────────────────────────────────────────────────────────────────┘

    /// Install Windows console control handler
    fn installWindowsConsoleHandler() void {
        if (builtin.os.tag == .windows) {
            const windows = std.os.windows;
            const kernel32 = windows.kernel32;

            global_mutex.lock();
            defer global_mutex.unlock();

            if (signal_handlers_installed) return;

            // Set console control handler for Windows
            _ = kernel32.SetConsoleCtrlHandler(windowsConsoleHandlerImpl, true) catch {};
            signal_handlers_installed = true;
        }
    }

    /// Windows console control handler implementation
    const windowsConsoleHandlerImpl = if (builtin.os.tag == .windows)
        struct {
            fn handler(ctrl_type: std.os.windows.DWORD) callconv(std.os.windows.WINAPI) std.os.windows.BOOL {
                // Handle various console control events
                switch (ctrl_type) {
                    0, // CTRL_C_EVENT
                    1, // CTRL_BREAK_EVENT
                    2, // CTRL_CLOSE_EVENT
                    5, // CTRL_LOGOFF_EVENT
                    6, // CTRL_SHUTDOWN_EVENT
                    => {
                        // Perform cleanup
                        cleanupGlobalRawMode();
                        // Return FALSE to let default handler terminate the process
                        return std.os.windows.FALSE;
                    },
                    else => return std.os.windows.FALSE,
                }
            }
        }.handler
    else
        undefined;

// ╚════════════════════════════════════════════════════════════════════════════════════╝