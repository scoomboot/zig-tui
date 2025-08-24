<!--------------------------------- SUMMARY --------------------------------->  

# Issue #059: Fix Circular Dependency Between Terminal and Screen Modules

Resolve the architectural circular dependency where screen module imports terminal module while terminal's callback_registry imports screen module, causing compilation errors.

<!--------------------------------------------------------------------------->  

<!-------------------------------- DESCRIPTION -------------------------------->  

The current architecture has a circular dependency that prevents proper compilation in certain contexts. The screen module imports the terminal module to access Terminal type and functionality, while the callback_registry (which is part of the terminal module) needs to import the screen module to handle resize callbacks properly.

This circular dependency manifests as compilation errors when running tests:
```
lib/terminal/utils/callback_registry/callback_registry.zig:282:36: error: import of file outside module path: '../../../screen/screen.zig'
```

<!--------------------------------------------------------------------------->  

<!---------------------------- CURRENT PROBLEM ------------------------------>

## Current Problem

### Dependency Chain
1. `screen/screen.zig` imports `../terminal/terminal.zig` (line 14)
2. `terminal/utils/callback_registry/callback_registry.zig` imports `../../../screen/screen.zig` (line 282)
3. This creates: Terminal → CallbackRegistry → Screen → Terminal (circular)

### Impact
- Compilation errors when running tests from different contexts
- Violates clean architecture principles
- Makes the codebase harder to maintain and extend
- Prevents proper module isolation

### Evidence
```zig
// In screen/screen.zig:14
const terminal_mod = @import("../terminal/terminal.zig");

// In terminal/utils/callback_registry/callback_registry.zig:282
const Screen = @import("../../../screen/screen.zig").Screen;
```

## Acceptance Criteria
- [ ] Remove circular dependency between terminal and screen modules
- [ ] All tests compile and pass without import errors
- [ ] Maintain existing functionality and API compatibility
- [ ] Document the new architecture pattern
- [ ] Follow MCS style guidelines
- [ ] Ensure type safety is preserved

## Proposed Solutions

### Option 1: Common Types Module (Recommended)
Create a shared types module that both terminal and screen can import:
```zig
// lib/common/types.zig
pub const ResizeHandler = struct {
    handler: *const fn (cols: u16, rows: u16) void,
    context: *anyopaque,
};

// lib/common/interfaces.zig  
pub const Resizable = struct {
    // Interface for resizable components
};
```

### Option 2: Interface-Based Design
Use comptime interfaces to break the dependency:
```zig
// terminal/utils/callback_registry/callback_registry.zig
pub fn handleResize(self: *CallbackRegistry, comptime ResizableType: type, ...) void {
    // Use ResizableType parameter instead of importing Screen
}
```

### Option 3: Event Bus Pattern
Implement a decoupled event system:
```zig
// lib/event_bus/event_bus.zig
pub const EventBus = struct {
    // Central event dispatcher
};
```

## Implementation Notes
```zig
// Option 1 Implementation Example - RECOMMENDED

// lib/common/resize_types.zig
pub const ResizeHandler = struct {
    handle: *const fn (self: *anyopaque, new_cols: u16, new_rows: u16) void,
    context: *anyopaque,
    
    pub fn invoke(self: ResizeHandler, cols: u16, rows: u16) void {
        self.handle(self.context, cols, rows);
    }
};

// terminal/utils/callback_registry/callback_registry.zig
const ResizeHandler = @import("../../common/resize_types.zig").ResizeHandler;

pub const CallbackRegistry = struct {
    handlers: std.ArrayList(ResizeHandler),
    
    pub fn registerHandler(self: *CallbackRegistry, handler: ResizeHandler) !void {
        try self.handlers.append(handler);
    }
    
    pub fn notifyResize(self: *CallbackRegistry, cols: u16, rows: u16) void {
        for (self.handlers.items) |handler| {
            handler.invoke(cols, rows);
        }
    }
};

// screen/screen.zig
const ResizeHandler = @import("../common/resize_types.zig").ResizeHandler;

pub const Screen = struct {
    // ... existing fields ...
    
    pub fn createResizeHandler(self: *Screen) ResizeHandler {
        return ResizeHandler{
            .handle = handleResizeStatic,
            .context = @ptrCast(self),
        };
    }
    
    fn handleResizeStatic(ctx: *anyopaque, cols: u16, rows: u16) void {
        const self: *Screen = @ptrCast(@alignCast(ctx));
        self.handleResize(cols, rows) catch |err| {
            std.log.err("Screen resize failed: {}", .{err});
        };
    }
};
```

## Dependencies
- None (this is an architectural fix)

## Testing Requirements
- Verify all existing tests pass after refactoring
- Add tests for the new common types module
- Test that resize callbacks work correctly
- Verify no performance regression
- Test compilation from different module contexts

## Estimated Time
4 hours

## Priority
🔴 Critical - Blocks proper testing and compilation

## Category
Architecture Refactoring

## Added
2025-08-24 - Discovered during Issue #053 session review

## Notes
This issue was discovered while implementing Windows resize optimization (Issue #053). The callback_registry needs to know about Screen type to properly handle resize events, but this creates a circular dependency since Screen already depends on Terminal.

The recommended solution (Option 1) creates a clean separation of concerns while maintaining type safety and performance. It also sets a pattern for future interface definitions that might be shared between modules.