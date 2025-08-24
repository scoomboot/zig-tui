# Issue #051: Clean Test Output

## Summary
Implement output redirection or mocking for tests to prevent ANSI escape sequences from appearing in test output.

## Description
Currently, terminal tests emit ANSI escape sequences directly to stdout during test execution, creating visual noise in test output. While tests pass successfully, the output contains sequences like `[?25l[?25h` (cursor hide/show), `[2J[1;1H` (clear screen), and other terminal control codes. This makes test output harder to read and debug.

## Problem Example
```
6/21 terminal.test.test.unit: Terminal: manages cursor visibility...[?25l[?25h[?25l[?25hOK
7/21 terminal.test.test.unit: Terminal: sets cursor styles...[0 q[2 q[4 q[6 q[1 q[3 q[5 qOK
```

## Acceptance Criteria
- [ ] Implement MockTerminal or output capture mechanism
- [ ] Redirect ANSI sequences during test execution
- [ ] Maintain test coverage and functionality
- [ ] Clean test output showing only test names and results
- [ ] Optional: Add flag to enable/disable output redirection for debugging
- [ ] Document the test output handling approach

## Dependencies
- Issue #016 (Create terminal tests) - Tests are already implemented

## Implementation Notes
Several approaches could work:

### Option 1: MockTerminal with Buffer
```zig
pub const MockTerminal = struct {
    output_buffer: std.ArrayList(u8),
    input_buffer: std.ArrayList(u8),
    size: Size,
    is_raw: bool,
    cursor_visible: bool,
    
    pub fn writeSequence(self: *MockTerminal, seq: []const u8) !void {
        try self.output_buffer.appendSlice(seq);
    }
    
    pub fn getOutput(self: *MockTerminal) []const u8 {
        return self.output_buffer.items;
    }
};
```

### Option 2: Test-Mode Flag
```zig
// In terminal.zig
pub fn writeSequence(self: *Terminal, seq: []const u8) !void {
    if (@import("builtin").is_test and !self.debug_output) {
        // Silently discard in test mode unless debugging
        return;
    }
    _ = try self.stdout.write(seq);
}
```

### Option 3: Output Interceptor
```zig
// In test file
const OutputInterceptor = struct {
    real_stdout: std.fs.File,
    buffer: std.ArrayList(u8),
    
    pub fn intercept(self: *OutputInterceptor) void {
        // Replace stdout with buffer writer
    }
    
    pub fn restore(self: *OutputInterceptor) void {
        // Restore original stdout
    }
};
```

## Testing Requirements
- Verify tests still pass with output redirection
- Ensure output capture doesn't affect test behavior
- Test that debug mode can show real output when needed
- Verify performance impact is minimal

## Estimated Time
2 hours

## Priority
🔵 Low - Quality of life improvement, not blocking functionality

## Category
Testing Infrastructure

## Added
2025-08-24 - Identified during Issue #006 implementation