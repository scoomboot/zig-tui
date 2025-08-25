<!--------------------------------- SUMMARY --------------------------------->  

# Issue #060: Unix Platform Portability (Linux vs macOS/BSD)

Fix Linux-specific API usage in signal handling implementation to enable compilation and proper functionality on all Unix platforms including macOS, FreeBSD, OpenBSD, and other POSIX-compliant systems.

<!--------------------------------------------------------------------------->  

<!-------------------------------- DESCRIPTION -------------------------------->  

The current signal safety implementation (Issue #054) uses Linux-specific APIs that prevent the library from compiling on other Unix platforms. The code assumes all non-Windows systems are Linux, which excludes macOS and BSD systems that many developers use.

This is a fundamental compilation issue, not a speculative improvement. The library will fail to build on macOS or any BSD variant with the current implementation.

<!--------------------------------------------------------------------------->  

<!---------------------------- CURRENT PROBLEM ------------------------------>

## Current Implementation Problems

The signal handling code in `lib/terminal/terminal.zig` uses Linux-specific APIs:

```zig
// Line 1044 - Linux-specific file flag
const new_flags = os.linux.O{ .NONBLOCK = true };

// Line 1158 - Linux-specific signal set manipulation
os.linux.sigaddset(&new_set, posix.SIG.WINCH);

// Line 1160 - Linux-specific signal masking
if (os.linux.sigprocmask(posix.SIG.BLOCK, &new_set, &old_set) != 0) {
    return SignalHandlerError.SignalMaskFailed;
}

// Line 1182 - Linux-specific signal mask restoration
_ = os.linux.sigprocmask(posix.SIG.SETMASK, &old_mask, null);
```

**Platform Detection Issues:**
- Code only checks `@import("builtin").os.tag == .windows`
- Assumes everything else is Linux
- No handling for macOS (`.macos`), FreeBSD (`.freebsd`), etc.

## Acceptance Criteria
- [ ] Abstract platform-specific signal APIs behind cross-platform interface
- [ ] Support macOS signal handling using POSIX APIs
- [ ] Support BSD variants (FreeBSD, OpenBSD, NetBSD)
- [ ] Maintain Linux optimizations where beneficial
- [ ] Add compile-time platform detection for Unix variants
- [ ] Ensure no regression in signal safety guarantees
- [ ] Add platform-specific tests
- [ ] Follow MCS style guidelines

## Dependencies
- Issue #054 (Signal Handler Safety) - COMPLETED (introduces the Linux-specific code)

## Implementation Notes
```zig
// terminal.zig — Platform-portable signal handling
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Platform detection for Unix variants
    const builtin = @import("builtin");
    const is_linux = builtin.os.tag == .linux;
    const is_macos = builtin.os.tag == .macos;
    const is_bsd = switch (builtin.os.tag) {
        .freebsd, .openbsd, .netbsd, .dragonfly => true,
        else => false,
    };
    const is_unix = !builtin.os.tag.isDarwin() and !builtin.os.tag.isWindows();

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    // ┌──────────────────────────── Platform Abstraction ────────────────────────────┐

        /// Get appropriate non-blocking flag for platform
        fn getNonBlockingFlag() u32 {
            if (is_linux) {
                const flags = os.linux.O{ .NONBLOCK = true };
                return @bitCast(flags);
            } else {
                // Use POSIX O_NONBLOCK for other Unix systems
                return posix.O_NONBLOCK;
            }
        }

        /// Platform-portable signal set operations
        const SignalOps = struct {
            /// Initialize empty signal set
            pub fn sigemptyset(set: *posix.sigset_t) void {
                if (is_linux) {
                    set.* = posix.empty_sigset;
                } else {
                    // Use POSIX sigemptyset for other Unix
                    _ = std.c.sigemptyset(set);
                }
            }
            
            /// Add signal to set
            pub fn sigaddset(set: *posix.sigset_t, sig: u6) !void {
                if (is_linux) {
                    os.linux.sigaddset(set, sig);
                } else {
                    // Use POSIX sigaddset
                    if (std.c.sigaddset(set, sig) != 0) {
                        return error.SignalAddFailed;
                    }
                }
            }
            
            /// Block/unblock signals
            pub fn sigprocmask(how: i32, set: ?*const posix.sigset_t, oldset: ?*posix.sigset_t) !void {
                const result = if (is_linux)
                    os.linux.sigprocmask(how, set, oldset)
                else
                    std.c.sigprocmask(how, set, oldset);
                    
                if (result != 0) {
                    return error.SignalMaskFailed;
                }
            }
        };

    // └──────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Updated Implementation ────────────────────────────┐

        fn startUnixResizeMonitoring(self: *Terminal) !void {
            // Create self-pipe for signal communication
            if (!signal_pipe_initialized) {
                signal_pipe = posix.pipe() catch {
                    return SignalHandlerError.PipeCreationFailed;
                };
                signal_pipe_initialized = true;
                
                // Make pipe non-blocking (platform-portable)
                const flags = posix.fcntl(signal_pipe[0], posix.F.GETFL, 0) catch 0;
                const nonblock_flag = getNonBlockingFlag();
                _ = posix.fcntl(signal_pipe[0], posix.F.SETFL, flags | nonblock_flag) catch {};
            }
            
            // ... rest of implementation using SignalOps
        }

        pub fn blockResizeSignals(self: *Terminal) !posix.sigset_t {
            _ = self;
            
            var new_set: posix.sigset_t = undefined;
            var old_set: posix.sigset_t = undefined;
            
            SignalOps.sigemptyset(&new_set);
            try SignalOps.sigaddset(&new_set, posix.SIG.WINCH);
            try SignalOps.sigprocmask(posix.SIG.BLOCK, &new_set, &old_set);
            
            return old_set;
        }

    // └──────────────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Alternative Approaches
1. **Use only POSIX APIs** - Most portable but may miss platform optimizations
2. **Platform-specific modules** - Separate files for each platform
3. **Conditional compilation** - Use comptime branches for each platform
4. **External C library** - Link against a portable signal handling library

## Testing Requirements
- Test compilation on Linux (Ubuntu, Fedora, Alpine)
- Test compilation on macOS (Intel and ARM)
- Test compilation on FreeBSD
- Test signal handling behavior on each platform
- Verify no performance regression on Linux
- Test signal masking on all platforms

## Platform Support Matrix
| Platform | Current Status | Target Status | APIs Used |
|----------|---------------|---------------|-----------|
| Linux | ✅ Works | ✅ Maintained | os.linux.* |
| macOS | ❌ Won't compile | ✅ Full support | POSIX/Darwin |
| FreeBSD | ❌ Won't compile | ✅ Full support | POSIX |
| OpenBSD | ❌ Won't compile | ✅ Full support | POSIX |
| NetBSD | ❌ Won't compile | ✅ Full support | POSIX |
| Windows | ✅ Separate path | ✅ Maintained | Windows API |

## Estimated Time
3-4 hours (including testing on multiple platforms)

## Priority
🟡 High - Blocks library usage on macOS and BSD systems

## Category
Platform Support / Portability

## Added
2025-08-24 - Identified during Issue #054 session review

## Notes
This is a critical portability issue that affects a significant portion of potential users. Many developers use macOS for development, and BSD systems are common in server environments. The fix is straightforward - abstract the Linux-specific calls behind a platform-agnostic interface using standard POSIX APIs where available.

The implementation should maintain the signal safety guarantees established in Issue #054 while expanding platform support. Performance optimizations specific to Linux can be preserved through conditional compilation.