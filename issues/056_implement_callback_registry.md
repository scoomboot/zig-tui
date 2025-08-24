<!--------------------------------- SUMMARY --------------------------------->

# Issue #056: Implement Screen-Terminal Callback Registry

Implement a proper callback registry system to connect screen instances with terminal resize events, fixing the critical limitation that prevents resize events from actually reaching screen buffers.

<!--------------------------------------------------------------------------->

<!-------------------------------- DESCRIPTION -------------------------------->

Issue #052 implemented the screen resize infrastructure but left a critical gap: the `screenResizeCallback` function is a placeholder that cannot access screen instances. This means terminal resize events never trigger screen buffer reallocation, breaking the entire resize functionality.

The current callback signature `fn(event: ResizeEvent) void` has no way to access the screen instance that needs to be resized. This architectural limitation must be resolved for the resize system to function.

<!--------------------------------------------------------------------------->

<!---------------------------- CURRENT PROBLEM ------------------------------>

## Current Implementation Gap

**Placeholder Callback** (`lib/screen/screen.zig:338-345`):
```zig
fn screenResizeCallback(event: terminal_mod.ResizeEvent) void {
    // This is a placeholder implementation
    // In a complete implementation, this would need to:
    // 1. Find the screen instance associated with the terminal
    // 2. Call screen.handleResize(event.new_size, .preserve_content)
    // 3. Handle multiple screens per terminal if needed
    _ = event; // Suppress unused parameter warning
}
```

**Registration Without Context** (`lib/screen/screen.zig:71`):
```zig
// Register for resize events
try terminal.onResize(screenResizeCallback);
```

## Impact
- **Resize events are lost** - Terminal detects resizes but screens don't update
- **Buffer reallocation never happens** - Screen stays at initial size
- **Content preservation doesn't work** - No resize means no content handling
- **User experience broken** - Terminal resizing appears to do nothing

<!--------------------------------------------------------------------------->

<!--------------------------- ACCEPTANCE CRITERIA -------------------------->

## Acceptance Criteria
- [ ] Screen instances can register for resize events with proper context
- [ ] Resize events trigger actual screen buffer reallocation
- [ ] Each screen maintains its own resize callback connection
- [ ] Callback registration is memory-safe (no dangling pointers)
- [ ] Callback unregistration works properly on screen deinit
- [ ] Support for at least single screen per terminal (multi-screen is Issue #057)
- [ ] Thread-safe callback invocation
- [ ] No memory leaks in callback management
- [ ] Follow MCS style guidelines
- [ ] Comprehensive test coverage for callback system

<!--------------------------------------------------------------------------->

<!-------------------------------- DEPENDENCIES -------------------------------->

## Dependencies
- Issue #052 (Integrate resize detection with screen buffer) - Provides base infrastructure
- Issue #007 (Add terminal size detection) - Provides resize event system

<!--------------------------------------------------------------------------->

<!-------------------------- IMPLEMENTATION NOTES --------------------------->

## Implementation Options

### Option 1: Context Pointer Pattern (C-style)
```zig
pub const ResizeCallbackWithContext = struct {
    callback: *const fn (context: *anyopaque, event: ResizeEvent) void,
    context: *anyopaque,
};

// In Screen
pub fn initWithTerminal(allocator: Allocator, terminal: *Terminal) !Screen {
    var screen = try init_with_size(...);
    const callback = ResizeCallbackWithContext{
        .callback = screenResizeHandler,
        .context = &screen,
    };
    try terminal.onResizeWithContext(callback);
    return screen;
}

fn screenResizeHandler(context: *anyopaque, event: ResizeEvent) void {
    const screen = @ptrCast(*Screen, @alignCast(@alignOf(Screen), context));
    screen.handleResize(event.new_size, .preserve_content) catch {};
}
```

### Option 2: Closure Pattern (Allocator-based)
```zig
// Create a closure that captures the screen reference
pub fn createResizeCallback(screen: *Screen, allocator: Allocator) !ResizeCallback {
    const Closure = struct {
        screen: *Screen,
        
        pub fn callback(event: ResizeEvent) void {
            const self = @fieldParentPtr(@This(), "callback", @src());
            self.screen.handleResize(event.new_size, .preserve_content) catch {};
        }
    };
    
    const closure = try allocator.create(Closure);
    closure.screen = screen;
    return closure.callback;
}
```

### Option 3: Registry Pattern (RECOMMENDED)
```zig
// Global or Terminal-owned registry
const CallbackRegistry = struct {
    const Entry = struct {
        screen: *Screen,
        terminal: *Terminal,
    };
    
    entries: std.ArrayList(Entry),
    mutex: std.Thread.Mutex,
    
    pub fn register(self: *CallbackRegistry, screen: *Screen, terminal: *Terminal) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.entries.append(.{ .screen = screen, .terminal = terminal });
    }
    
    pub fn unregister(self: *CallbackRegistry, screen: *Screen) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        // Remove entry for this screen
    }
    
    pub fn handleResize(self: *CallbackRegistry, terminal: *Terminal, event: ResizeEvent) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        for (self.entries.items) |entry| {
            if (entry.terminal == terminal) {
                entry.screen.handleResize(event.new_size, .preserve_content) catch {};
            }
        }
    }
};
```

## Recommended Approach: Option 3 (Registry Pattern)

**Rationale:**
- Clean separation of concerns
- Supports future multi-screen per terminal (Issue #057)
- Thread-safe by design
- No complex pointer casting
- Easy to debug and maintain
- Extensible for future requirements

<!--------------------------------------------------------------------------->

<!--------------------------- TESTING REQUIREMENTS --------------------------->

## Testing Requirements
- Test callback registration and invocation
- Test callback unregistration on screen deinit
- Test resize event propagation from terminal to screen
- Test thread safety with concurrent resize events
- Test memory safety (no leaks, no dangling pointers)
- Test error handling in callback execution
- Integration test: Full resize flow from terminal to screen buffer
- Performance test: Callback overhead < 1ms

<!--------------------------------------------------------------------------->

<!--------------------------- INTEGRATION POINTS ----------------------------->

## Integration Points
- **Terminal Module**: Modify resize callback system to support context
- **Screen Module**: Update initWithTerminal and deinit methods
- **TUI System**: Ensure proper lifecycle management
- **Future Issue #057**: Design with multi-screen support in mind

<!--------------------------------------------------------------------------->

<!------------------------------- METADATA ----------------------------------->

**Estimated Time:** 3 hours  
**Priority:** 🔴 Critical - Resize functionality is broken without this  
**Category:** Core Infrastructure  
**Added:** 2025-08-24 - Discovered during Issue #052 implementation session  

<!--------------------------------------------------------------------------->

<!--------------------------------- NOTES ------------------------------------->

This issue was discovered during the implementation of Issue #052. While all the resize infrastructure was built (buffer reallocation, content preservation, thread safety), the actual connection between terminal resize events and screen updates is missing due to the callback architecture limitation.

Without fixing this issue, the entire resize feature is non-functional despite appearing complete. This is a critical architectural gap that must be addressed immediately.

The recommended registry pattern will also enable Issue #057 (multiple screens per terminal) without major refactoring.

<!--------------------------------------------------------------------------->