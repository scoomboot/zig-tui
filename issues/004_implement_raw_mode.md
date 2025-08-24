# Issue #004: Implement raw mode

## Summary
Implement terminal raw mode handling for direct keyboard input and terminal control.

## Description
Create a cross-platform raw mode implementation that allows the TUI library to take full control of terminal input and output. This includes disabling line buffering, echo, and special key processing while preserving the ability to restore original terminal settings.

## Acceptance Criteria
- [ ] Create `lib/terminal/utils/raw_mode/raw_mode.zig`
- [ ] Implement `enterRawMode()` function
- [ ] Implement `exitRawMode()` function
- [ ] Store original terminal settings for restoration
- [ ] Handle POSIX terminals (Linux/macOS)
- [ ] Handle Windows terminals (Windows Terminal, CMD)
- [ ] Implement signal handling for clean exit
- [ ] Add safety mechanisms to ensure terminal restoration
- [ ] Create comprehensive tests
- [ ] Follow MCS style guidelines

## Dependencies
- Issue #003 (Create main entry point)

## Implementation Notes
```zig
// raw_mode.zig — Terminal raw mode handling
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const builtin = @import("builtin");
    const os = std.os;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    const RawModeError = error{
        TerminalNotTTY,
        GetAttrFailed,
        SetAttrFailed,
        WindowsConsoleFailed,
    };

    const TerminalState = switch (builtin.os.tag) {
        .linux, .macos => struct {
            original_termios: os.termios,
            is_raw: bool = false,
        },
        .windows => struct {
            original_mode: u32,
            is_raw: bool = false,
        },
        else => @compileError("Unsupported OS"),
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    pub const RawMode = struct {
        state: TerminalState,
        stdin_fd: os.fd_t,

        // ┌──────────────────────────── Public API ────────────────────────────┐

            /// Initialize raw mode handler
            pub fn init() !RawMode {
                const stdin_fd = os.STDIN_FILENO;
                
                // Check if stdin is a terminal
                if (!os.isatty(stdin_fd)) {
                    return RawModeError.TerminalNotTTY;
                }

                return RawMode{
                    .state = TerminalState{},
                    .stdin_fd = stdin_fd,
                };
            }

            /// Enter raw mode
            pub fn enter(self: *RawMode) !void {
                if (self.state.is_raw) return;

                switch (builtin.os.tag) {
                    .linux, .macos => try self.enterPosix(),
                    .windows => try self.enterWindows(),
                    else => unreachable,
                }

                self.state.is_raw = true;
            }

            /// Exit raw mode and restore original settings
            pub fn exit(self: *RawMode) !void {
                if (!self.state.is_raw) return;

                switch (builtin.os.tag) {
                    .linux, .macos => try self.exitPosix(),
                    .windows => try self.exitWindows(),
                    else => unreachable,
                }

                self.state.is_raw = false;
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Platform Specific ────────────────────────────┐

            fn enterPosix(self: *RawMode) !void {
                // Save original settings
                self.state.original_termios = try os.tcgetattr(self.stdin_fd);

                // Configure raw mode
                var raw = self.state.original_termios;
                
                // Input flags
                raw.iflag &= ~(os.system.BRKINT | os.system.ICRNL | 
                              os.system.INPCK | os.system.ISTRIP | os.system.IXON);
                
                // Output flags
                raw.oflag &= ~(os.system.OPOST);
                
                // Control flags
                raw.cflag |= (os.system.CS8);
                
                // Local flags
                raw.lflag &= ~(os.system.ECHO | os.system.ICANON | 
                              os.system.IEXTEN | os.system.ISIG);
                
                // Control characters
                raw.cc[os.system.VMIN] = 0;
                raw.cc[os.system.VTIME] = 1;

                try os.tcsetattr(self.stdin_fd, .FLUSH, raw);
            }

            fn exitPosix(self: *RawMode) !void {
                try os.tcsetattr(self.stdin_fd, .FLUSH, self.state.original_termios);
            }

            fn enterWindows(self: *RawMode) !void {
                // Windows implementation
                // GetConsoleMode / SetConsoleMode
            }

            fn exitWindows(self: *RawMode) !void {
                // Windows implementation
            }

        // └──────────────────────────────────────────────────────────────────┘

    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Test entering and exiting raw mode
- Verify terminal settings are properly restored
- Test signal handling (Ctrl+C, etc.)
- Test on multiple platforms
- Verify no terminal corruption on crash
- Performance: < 1ms to enter/exit raw mode

## Estimated Time
4 hours

## Priority
🔴 Critical - Required for terminal control

## Category
Terminal Core