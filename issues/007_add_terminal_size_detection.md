# Issue #007: Add terminal size detection

## Summary
Implement robust terminal size detection with resize event handling across platforms.

## Description
Enhance the terminal module with comprehensive size detection capabilities, including initial size query, resize event handling, and callback mechanisms for size changes. This should work reliably across different terminal emulators and operating systems.

## Acceptance Criteria
- [ ] Implement initial size detection on all platforms
- [ ] Add SIGWINCH signal handler for Unix systems
- [ ] Add Windows console resize detection
- [ ] Create resize event callback system
- [ ] Handle edge cases (SSH, tmux, screen)
- [ ] Add size caching with invalidation
- [ ] Implement fallback mechanisms
- [ ] Add size constraint validation
- [ ] Create comprehensive tests
- [ ] Follow MCS style guidelines

## Dependencies
- Issue #006 (Implement terminal core)

## Implementation Notes
```zig
// terminal.zig additions — Terminal size detection and resize handling
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    pub const SizeConstraints = struct {
        min_rows: u16 = 1,
        min_cols: u16 = 1,
        max_rows: u16 = 9999,
        max_cols: u16 = 9999,
    };

    pub const ResizeEvent = struct {
        old_size: Size,
        new_size: Size,
        timestamp: i64,
    };

    pub const ResizeCallback = *const fn (event: ResizeEvent) void;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    // Extension to Terminal struct
    pub const Terminal = struct {
        // ... existing fields ...
        size_cache: ?Size,
        size_constraints: SizeConstraints,
        resize_callbacks: std.ArrayList(ResizeCallback),
        resize_thread: ?std.Thread,
        
        // ┌──────────────────────────── Size Detection ────────────────────────────┐

            /// Query terminal size with multiple methods
            pub fn querySize(self: *Terminal) !Size {
                // Try multiple methods in order of preference
                
                // Method 1: ioctl/Windows API
                if (try self.querySizeSystem()) |size| {
                    return self.validateSize(size);
                }
                
                // Method 2: ANSI escape sequence query
                if (try self.querySizeANSI()) |size| {
                    return self.validateSize(size);
                }
                
                // Method 3: Environment variables
                if (try self.querySizeEnv()) |size| {
                    return self.validateSize(size);
                }
                
                // Method 4: Default fallback
                return Size{ .rows = 24, .cols = 80 };
            }

            /// System-specific size query
            fn querySizeSystem(self: *Terminal) !?Size {
                switch (builtin.os.tag) {
                    .linux, .macos => {
                        var ws: os.system.winsize = undefined;
                        const fd = self.stdout.handle;
                        
                        if (os.system.ioctl(fd, os.system.TIOCGWINSZ, @ptrToInt(&ws)) == 0) {
                            return Size{
                                .rows = ws.ws_row,
                                .cols = ws.ws_col,
                            };
                        }
                    },
                    .windows => {
                        var csbi: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
                        
                        if (windows.GetConsoleScreenBufferInfo(self.stdout.handle, &csbi)) {
                            return Size{
                                .rows = csbi.srWindow.Bottom - csbi.srWindow.Top + 1,
                                .cols = csbi.srWindow.Right - csbi.srWindow.Left + 1,
                            };
                        }
                    },
                    else => {},
                }
                return null;
            }

            /// ANSI escape sequence size query
            fn querySizeANSI(self: *Terminal) !?Size {
                // Save cursor position
                try self.writeSequence(ansi.CSI ++ "s");
                
                // Move to bottom-right corner
                try self.writeSequence(ansi.CSI ++ "999;999H");
                
                // Query cursor position
                try self.writeSequence(ansi.CSI ++ "6n");
                
                // Read response (format: ESC[row;colR)
                var buf: [32]u8 = undefined;
                const n = try self.stdin.read(&buf);
                
                if (n > 0) {
                    // Parse response
                    var rows: u16 = 0;
                    var cols: u16 = 0;
                    
                    if (try parseDeviceStatusReport(buf[0..n], &rows, &cols)) {
                        // Restore cursor position
                        try self.writeSequence(ansi.CSI ++ "u");
                        
                        return Size{ .rows = rows, .cols = cols };
                    }
                }
                
                // Restore cursor position
                try self.writeSequence(ansi.CSI ++ "u");
                
                return null;
            }

            /// Environment variable size query
            fn querySizeEnv(self: *Terminal) !?Size {
                const rows_str = os.getenv("LINES");
                const cols_str = os.getenv("COLUMNS");
                
                if (rows_str != null and cols_str != null) {
                    const rows = try std.fmt.parseInt(u16, rows_str.?, 10);
                    const cols = try std.fmt.parseInt(u16, cols_str.?, 10);
                    
                    return Size{ .rows = rows, .cols = cols };
                }
                
                return null;
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Resize Handling ────────────────────────────┐

            /// Start monitoring for terminal resize events
            pub fn startResizeMonitoring(self: *Terminal) !void {
                if (self.resize_thread != null) return;
                
                switch (builtin.os.tag) {
                    .linux, .macos => {
                        // Install SIGWINCH handler
                        var act = os.Sigaction{
                            .handler = .{ .handler = handleSigwinch },
                            .mask = os.empty_sigset,
                            .flags = 0,
                        };
                        try os.sigaction(os.SIG.WINCH, &act, null);
                    },
                    .windows => {
                        // Start thread to monitor console events
                        self.resize_thread = try std.Thread.spawn(
                            .{},
                            monitorWindowsResize,
                            .{self},
                        );
                    },
                    else => {},
                }
            }

            /// Stop monitoring for resize events
            pub fn stopResizeMonitoring(self: *Terminal) void {
                if (self.resize_thread) |thread| {
                    thread.join();
                    self.resize_thread = null;
                }
            }

            /// Register a callback for resize events
            pub fn onResize(self: *Terminal, callback: ResizeCallback) !void {
                try self.resize_callbacks.append(callback);
            }

            /// Handle resize event
            fn handleResize(self: *Terminal) void {
                const old_size = self.size;
                self.size = self.querySize() catch return;
                
                if (old_size.rows != self.size.rows or old_size.cols != self.size.cols) {
                    const event = ResizeEvent{
                        .old_size = old_size,
                        .new_size = self.size,
                        .timestamp = std.time.milliTimestamp(),
                    };
                    
                    for (self.resize_callbacks.items) |callback| {
                        callback(event);
                    }
                }
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Validation ────────────────────────────┐

            /// Validate and constrain terminal size
            fn validateSize(self: *Terminal, size: Size) Size {
                return Size{
                    .rows = std.math.clamp(
                        size.rows,
                        self.size_constraints.min_rows,
                        self.size_constraints.max_rows,
                    ),
                    .cols = std.math.clamp(
                        size.cols,
                        self.size_constraints.min_cols,
                        self.size_constraints.max_cols,
                    ),
                };
            }

        // └──────────────────────────────────────────────────────────────────┘

    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Test size detection on various terminals
- Test resize event handling
- Test callback mechanisms
- Test edge cases (SSH, tmux, very small/large sizes)
- Test constraint validation
- Verify cross-platform behavior
- Performance: < 10ms for size query

## Estimated Time
2 hours

## Priority
🔴 Critical - Required for responsive layouts

## Category
Terminal Core