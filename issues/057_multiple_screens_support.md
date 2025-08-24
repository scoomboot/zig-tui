<!--------------------------------- SUMMARY --------------------------------->

# Issue #057: Support Multiple Screens Per Terminal

Extend the screen-terminal callback system to support multiple screen instances per terminal, enabling advanced TUI features like split-screen layouts, multiple viewports, and tabbed interfaces.

<!--------------------------------------------------------------------------->

<!-------------------------------- DESCRIPTION -------------------------------->

The current screen resize implementation assumes a one-to-one relationship between terminals and screens. This limitation prevents implementing advanced TUI features that require multiple independent screen buffers sharing the same terminal, such as split panes, tabs, or picture-in-picture views.

Modern TUI applications often need to manage multiple screen regions independently, each with its own buffer, content, and resize behavior. This enhancement would make the library suitable for building sophisticated terminal applications.

<!--------------------------------------------------------------------------->

<!---------------------------- CURRENT PROBLEM ------------------------------>

## Current Limitations

**Single Screen Registration** (`lib/screen/screen.zig:71`):
```zig
// Only one screen can register for resize events
try terminal.onResize(screenResizeCallback);
```

**Global Callback Issue**:
- Each terminal maintains a single list of resize callbacks
- No mechanism to associate multiple screens with one terminal
- Cannot implement split-screen or multi-viewport layouts

## Use Cases Blocked
- **Split-screen editors** (like vim splits or tmux panes)
- **Tabbed interfaces** (multiple full-screen views)
- **Modal dialogs** (overlay screens on main content)
- **Status bars/panels** (independent screen regions)
- **Picture-in-picture** views
- **Dashboard layouts** with multiple data views

<!--------------------------------------------------------------------------->

<!--------------------------- ACCEPTANCE CRITERIA -------------------------->

## Acceptance Criteria
- [ ] Multiple screens can register with the same terminal
- [ ] Each screen receives resize events independently
- [ ] Screens can have different dimensions (viewport within terminal)
- [ ] Support for screen layers/z-ordering
- [ ] Efficient event dispatching to multiple screens
- [ ] Clean lifecycle management for multi-screen setups
- [ ] No performance degradation for single-screen case
- [ ] Thread-safe multi-screen operations
- [ ] Follow MCS style guidelines
- [ ] Comprehensive test coverage for multi-screen scenarios

<!--------------------------------------------------------------------------->

<!-------------------------------- DEPENDENCIES -------------------------------->

## Dependencies
- Issue #056 (Implement Screen-Terminal Callback Registry) - Must be completed first
- Issue #052 (Integrate resize detection with screen buffer) - Base resize functionality

<!--------------------------------------------------------------------------->

<!-------------------------- IMPLEMENTATION NOTES --------------------------->

## Design Considerations

### Screen Manager Pattern
```zig
pub const ScreenManager = struct {
    terminal: *Terminal,
    screens: std.ArrayList(*Screen),
    active_screen: ?*Screen,
    layout: LayoutType,
    
    pub const LayoutType = enum {
        single,      // One screen fills terminal
        split_h,     // Horizontal split
        split_v,     // Vertical split
        grid,        // Grid layout
        tabbed,      // Multiple screens, one visible
        floating,    // Overlapping screens with z-order
    };
    
    pub fn addScreen(self: *ScreenManager, screen: *Screen, region: ?Rect) !void {
        try self.screens.append(screen);
        if (region) |r| {
            screen.setViewport(r);
        }
        try self.terminal.onResize(self.handleResize);
    }
    
    fn handleResize(self: *ScreenManager, event: ResizeEvent) void {
        // Recalculate screen regions based on layout
        self.updateLayout(event.new_size);
        
        // Notify each screen of its new dimensions
        for (self.screens.items) |screen| {
            const screen_size = self.calculateScreenSize(screen);
            screen.handleResize(screen_size, .preserve_content) catch {};
        }
    }
};
```

### Viewport System
```zig
pub const Viewport = struct {
    x: u16,
    y: u16,
    width: u16,
    height: u16,
    z_index: i32,
    visible: bool,
    
    pub fn toSize(self: Viewport) Size {
        return Size{ .cols = self.width, .rows = self.height };
    }
};

// Extension to Screen
pub const Screen = struct {
    // ... existing fields ...
    viewport: ?Viewport,
    parent_manager: ?*ScreenManager,
    
    pub fn setViewport(self: *Screen, viewport: Viewport) void {
        self.viewport = viewport;
        const size = viewport.toSize();
        self.handleResize(size, .preserve_content) catch {};
    }
};
```

### Event Routing
```zig
// Terminal needs to support multiple callback targets
pub const Terminal = struct {
    // Instead of single callback list
    resize_callbacks: std.ArrayList(ResizeCallback),
    
    // Support callback groups or managers
    resize_managers: std.ArrayList(*ScreenManager),
    
    fn notifyResize(self: *Terminal, event: ResizeEvent) void {
        // Notify all managers
        for (self.resize_managers.items) |manager| {
            manager.handleResize(event);
        }
        
        // Also support standalone callbacks
        for (self.resize_callbacks.items) |callback| {
            callback(event);
        }
    }
};
```

<!--------------------------------------------------------------------------->

<!--------------------------- TESTING REQUIREMENTS --------------------------->

## Testing Requirements
- Test multiple screens with same terminal
- Test different layout types (split, grid, tabbed)
- Test viewport calculations and boundaries
- Test z-ordering for overlapping screens
- Test resize event distribution to multiple screens
- Test screen addition/removal during runtime
- Test memory management with many screens
- Performance test: 10+ screens resize handling
- Stress test: Rapid screen creation/destruction

<!--------------------------------------------------------------------------->

<!--------------------------- INTEGRATION POINTS ----------------------------->

## Integration Points
- **Layout Module**: Will heavily use multi-screen support
- **Widget System**: Widgets may create sub-screens
- **Window Manager**: Could be built on top of this
- **Modal System**: Overlays require multiple screens
- **Status Bar**: Independent screen at bottom/top

<!--------------------------------------------------------------------------->

<!------------------------------- METADATA ----------------------------------->

**Estimated Time:** 5 hours  
**Priority:** 🟡 Medium - Enhancement for advanced features  
**Category:** Feature Enhancement  
**Added:** 2025-08-24 - Identified during Issue #052 implementation session  

<!--------------------------------------------------------------------------->

<!--------------------------------- NOTES ------------------------------------->

This enhancement was identified during Issue #052 implementation when it became clear that the current architecture only supports one screen per terminal. While not critical for basic TUI functionality, this limitation prevents building sophisticated terminal applications.

This issue should be tackled after Issue #056 (callback registry) is complete, as that will provide the foundation for managing multiple screen-terminal associations.

Consider implementing this in phases:
1. Basic multi-screen support (same size screens)
2. Viewport system (different sized regions)
3. Layout manager (automatic region calculation)
4. Advanced features (z-ordering, visibility, focus)

The design should be extensible to support future window management features.

<!--------------------------------------------------------------------------->