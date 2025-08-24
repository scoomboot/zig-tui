# Terminal-CallbackRegistry Integration

## Overview
The Terminal module has been successfully updated to integrate with the CallbackRegistry system, providing a foundation for advanced screen-terminal callback associations while maintaining backward compatibility with the existing ResizeCallback system.

## Changes Made

### 1. Import Added
- Added import for `CallbackRegistry` from `utils/callback_registry/callback_registry.zig`

### 2. Terminal Struct Updates
- Added field: `callback_registry: CallbackRegistry` to store the registry instance
- Registry is initialized in `Terminal.init()` with the provided allocator
- Registry is properly cleaned up in `Terminal.deinit()`

### 3. New Public API
- Added `getCallbackRegistry(self: *Terminal) *CallbackRegistry` method
  - Returns a pointer to the terminal's callback registry
  - Allows screens to register themselves for resize notifications

### 4. Resize Event Handling
- Updated `handleResize()` to maintain backward compatibility
- Existing ResizeCallback system continues to work unchanged
- Added TODO comment for future Screen module integration
- When Screen module is updated, it will use the registry for automatic resize notifications

### 5. Backward Compatibility
- All existing resize callbacks continue to function
- No breaking changes to the public API
- Existing tests pass without modification

## Usage Example

```zig
// For screens to register with the terminal
var terminal = try Terminal.init(allocator);
defer terminal.deinit();

const registry = terminal.getCallbackRegistry();
const registration_id = try registry.register(
    @as(*anyopaque, @ptrCast(&terminal)),
    @as(*anyopaque, @ptrCast(&screen))
);

// Later, to unregister
try registry.unregister(registration_id);
```

## Testing
- Created `callback_integration.test.zig` with 6 comprehensive tests
- All tests pass successfully
- Verified:
  - Registry field exists and is initialized
  - Registry is accessible via getter
  - Can register/unregister entries
  - Proper cleanup in deinit
  - Backward compatibility with ResizeCallback
  - Support for multiple screen registrations

## Next Steps
When the Screen module is updated:
1. Import the Screen type in Terminal
2. Uncomment the `handleResize` call to the registry in Terminal's `handleResize()` method
3. Pass the actual Screen type instead of the placeholder struct
4. Screen module should implement a `handleResize` method that the registry can call

## Files Modified
- `/home/fisty/code/zig-tui/lib/terminal/terminal.zig` - Main integration changes
- `/home/fisty/code/zig-tui/lib/terminal/callback_integration.test.zig` - New test file (created)

## Build Status
✅ All builds successful
✅ All tests passing
✅ No breaking changes