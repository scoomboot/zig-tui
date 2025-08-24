# CallbackRegistry Implementation Notes

## Issue #056 Solution

This module provides a thread-safe registry pattern to solve the problem where resize callbacks couldn't access screen instances.

## Architecture

### Core Components

1. **Entry Structure**
   - Unique ID for safe reference management
   - Terminal pointer (as `*anyopaque` to avoid circular dependencies)
   - Screen pointer (as `*anyopaque` to avoid circular dependencies)
   - Registration timestamp for debugging

2. **CallbackRegistry Structure**
   - Thread-safe with mutex protection
   - Dynamic entry list using `ArrayList`
   - Statistics tracking for monitoring
   - Support for multiple screens per terminal

3. **Global Singleton** (Optional)
   - `getGlobalRegistry()` for shared access
   - `deinitGlobalRegistry()` for cleanup

## Key Features

### Thread Safety
- All public methods are protected by mutex locks
- Safe for concurrent access from multiple threads

### Memory Safety
- Uses unique IDs instead of direct pointer storage
- Prevents dangling pointer issues
- Proper cleanup on deinit

### Performance Characteristics
- **Register**: O(n) scan to prevent duplicates
- **Unregister**: O(n) search and swap-remove
- **HandleResize**: O(n) iteration over entries
- **FindEntries**: O(n) scan with allocation

For typical use cases (n < 10 screens), linear operations are optimal for cache locality.

## Integration Guide

### Terminal Module Integration

```zig
// In terminal.zig
const registry = @import("utils/callback_registry/callback_registry.zig");

fn notifyResizeCallbacks(self: *Terminal, event: ResizeEvent) void {
    const global_registry = registry.getGlobalRegistry(self.allocator);
    global_registry.handleResize(self, event.new_size.cols, event.new_size.rows, Screen);
}
```

### Screen Module Integration

```zig
// In screen.zig
const registry = @import("../terminal/utils/callback_registry/callback_registry.zig");

pub const Screen = struct {
    // ... existing fields ...
    registry_id: ?u64 = null,
    
    pub fn initWithTerminal(allocator: std.mem.Allocator, terminal: *Terminal) !Screen {
        var screen = try init_with_size(allocator, size.cols, size.rows);
        
        // Register with callback registry
        const global_registry = registry.getGlobalRegistry(allocator);
        screen.registry_id = try global_registry.register(terminal, &screen);
        
        return screen;
    }
    
    pub fn deinit(self: *Screen) void {
        // Unregister from callback registry
        if (self.registry_id) |id| {
            const global_registry = registry.getGlobalRegistry(self.allocator);
            global_registry.unregister(id) catch {};
        }
        
        // ... existing cleanup ...
    }
};
```

## Testing

The module includes comprehensive test coverage:

- **Unit Tests**: Core functionality of registry operations
- **Integration Tests**: Multi-screen scenarios and resize dispatching
- **Scenario Tests**: Complete lifecycle workflows
- **Performance Tests**: Stress testing with many entries

Run tests with:
```bash
zig test lib/terminal/utils/callback_registry/callback_registry_simple.test.zig
```

## Future Enhancements

1. **Weak References**: Consider using weak references to automatically clean up destroyed screens
2. **Event Priority**: Add priority levels for resize callbacks
3. **Batch Operations**: Support batch registration/unregistration for efficiency
4. **Async Support**: Add async-safe operations for event loops
5. **Metrics**: Enhanced statistics and performance monitoring

## Design Decisions

### Why `*anyopaque` instead of concrete types?

To avoid circular dependencies between terminal, screen, and callback_registry modules. The registry acts as a decoupled mediator pattern.

### Why global singleton option?

Provides convenient access across modules while maintaining thread safety. The non-singleton API is still available for testing and special use cases.

### Why unique IDs?

IDs prevent issues with pointer invalidation and make the API safer. They also enable future features like persistent state or network transparency.

## Performance Notes

- Mutex contention is minimal due to short critical sections
- Linear scans are cache-friendly for small collections
- Consider index structures if n > 100 entries (unlikely in TUI apps)
- Statistics have negligible overhead

## MCS Compliance

The implementation follows Maysara Code Style guidelines:
- Section demarcation boxes for organization
- Comprehensive inline documentation
- Performance optimization comments
- Proper test categorization
- Visual code structure with indentation