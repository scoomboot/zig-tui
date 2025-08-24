<!--------------------------------- SUMMARY --------------------------------->

# Issue #058: Fix CallbackRegistry Type Parameter Issue

Fixed critical compilation error where Terminal was calling handleResize without the required comptime ScreenType parameter.

<!--------------------------------------------------------------------------->

<!-------------------------------- DESCRIPTION -------------------------------->

During implementation of Issue #056 (callback registry), a method signature mismatch was introduced. The CallbackRegistry.handleResize method required a comptime ScreenType parameter, but Terminal was calling it without providing this parameter, which would cause a compilation error.

This issue was discovered during session review and immediately fixed to prevent build failures.

<!--------------------------------------------------------------------------->

<!---------------------------- PROBLEM FIXED ------------------------------>

## Original Problem

**Method signature mismatch** (`lib/terminal/utils/callback_registry/callback_registry.zig:277`):
```zig
// Expected signature:
pub fn handleResize(self: *CallbackRegistry, terminal: *anyopaque, new_cols: u16, new_rows: u16, comptime ScreenType: type) void

// Terminal was calling:
self.callback_registry.handleResize(
    @as(*anyopaque, @ptrCast(self)),
    constrained_size.cols,
    constrained_size.rows
    // Missing ScreenType parameter!
);
```

## Solution Implemented

Created two versions of handleResize:

1. **handleResize** - Runtime version that imports Screen type internally
2. **handleResizeTyped** - Compile-time version with explicit type parameter

This allows Terminal to call handleResize without creating circular dependencies while maintaining type safety where needed.

<!--------------------------------------------------------------------------->

<!---------------------------- CHANGES MADE -------------------------------->

## Files Modified

1. **`lib/terminal/utils/callback_registry/callback_registry.zig`**
   - Renamed original `handleResize` to `handleResizeTyped`
   - Created new `handleResize` without comptime parameter
   - New version imports Screen type locally to avoid circular dependency

2. **`lib/terminal/utils/callback_registry/callback_registry.test.zig`**
   - Updated all test calls to use `handleResizeTyped` for type safety
   - All 23 tests continue to pass

## Code Changes

```zig
// New runtime version (used by Terminal)
pub fn handleResize(self: *CallbackRegistry, terminal: *anyopaque, new_cols: u16, new_rows: u16) void {
    const Screen = @import("../../../screen/screen.zig").Screen;
    // ... handle resize with runtime type
}

// Type-safe version (used in tests)
pub fn handleResizeTyped(self: *CallbackRegistry, terminal: *anyopaque, new_cols: u16, new_rows: u16, comptime ScreenType: type) void {
    // ... handle resize with compile-time type
}
```

<!--------------------------------------------------------------------------->

<!--------------------------- VERIFICATION ---------------------------------->

## Verification

✅ All 23 callback registry tests pass
✅ Main project builds successfully (`zig build`)
✅ Full test suite passes (`zig build test`)
✅ No circular dependencies introduced
✅ Type safety maintained where possible

<!--------------------------------------------------------------------------->

<!------------------------------- METADATA ----------------------------------->

**Status:** ✅ RESOLVED  
**Discovered:** 2025-08-24 during session review  
**Fixed:** 2025-08-24 immediately after discovery  
**Category:** Bug Fix  
**Priority:** 🔴 Critical - Prevented compilation  

<!--------------------------------------------------------------------------->

<!--------------------------------- NOTES ------------------------------------->

This issue highlights the importance of:
1. Testing the full build after significant changes
2. Carefully managing type parameters in generic code
3. Avoiding circular dependencies in modular architectures

The fix maintains the benefits of the callback registry system while ensuring compilation success and avoiding circular dependencies.

<!--------------------------------------------------------------------------->