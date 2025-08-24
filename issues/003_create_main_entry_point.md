# Issue #003: Create main entry point

## Summary
Implement the main library entry point (lib/tui.zig) that exports all public APIs and provides a clean interface for library users.

## Description
Create the main TUI library entry point that aggregates and re-exports all public modules, types, and functions. This file should provide a single import point for users while maintaining clean namespace organization.

## Acceptance Criteria
- [ ] Create `lib/tui.zig` with proper MCS file header
- [ ] Export Terminal module and its public APIs
- [ ] Export Screen module and its public APIs
- [ ] Export Event module and its public APIs
- [ ] Export common types and enums
- [ ] Export error types
- [ ] Add library version constant
- [ ] Add library metadata (author, license, etc.)
- [ ] Ensure clean namespace without pollution
- [ ] Follow MCS documentation standards

## Dependencies
- Issue #001 (Create directory structure)

## Implementation Notes
```zig
// tui.zig — Main entry point for Zig TUI library
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    
    // Core modules
    pub const Terminal = @import("terminal/terminal.zig").Terminal;
    pub const Screen = @import("screen/screen.zig").Screen;
    pub const Event = @import("event/event.zig").Event;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Library metadata
    pub const version = "0.1.0";
    pub const author = "Fisty";
    pub const license = "MIT";

    // Common types
    pub const Color = enum {
        black,
        red,
        green,
        yellow,
        blue,
        magenta,
        cyan,
        white,
        default,
        // Extended colors...
    };

    pub const Style = struct {
        fg: Color = .default,
        bg: Color = .default,
        bold: bool = false,
        italic: bool = false,
        underline: bool = false,
    };

    // Error types
    pub const TuiError = error{
        TerminalInitFailed,
        ScreenBufferFull,
        InvalidDimensions,
        EventQueueFull,
        // Add more as needed
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    // ┌──────────────────────────── Convenience Functions ────────────────────────────┐

        /// Initialize TUI with default settings
        pub fn init(allocator: std.mem.Allocator) !struct {
            terminal: Terminal,
            screen: Screen,
            events: Event.Handler,
        } {
            // Implementation
        }

        /// Quick setup for simple applications
        pub fn quickStart(allocator: std.mem.Allocator) !void {
            // Implementation
        }

    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Library imports successfully in test projects
- All exported symbols are accessible
- No namespace conflicts
- Version information is correct
- Convenience functions work as expected

## Estimated Time
1 hour

## Priority
🔴 Critical - Required for library usage

## Category
Project Setup