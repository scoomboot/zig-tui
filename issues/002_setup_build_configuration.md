# Issue #002: Setup build configuration

## Summary
Configure build.zig for the TUI library with proper module exports, test targets, and example builds.

## Description
Set up a comprehensive build configuration that supports library development, testing, benchmarking, and example applications. The build system should follow Zig best practices and make it easy for users to integrate the TUI library into their projects.

## Acceptance Criteria
- [ ] Create/update `build.zig` with library module configuration
- [ ] Define main library module export
- [ ] Add test step for running all tests
- [ ] Add test filters for specific test categories:
  - [ ] Unit tests (`--test-filter "unit:"`)
  - [ ] Integration tests (`--test-filter "integration:"`)
  - [ ] Performance tests (`--test-filter "performance:"`)
- [ ] Add benchmark step for performance testing
- [ ] Add examples step for building all examples
- [ ] Configure optimization modes (Debug, ReleaseSafe, ReleaseFast, ReleaseSmall)
- [ ] Add installation step for library artifacts
- [ ] Create `build.zig.zon` for package management

## Dependencies
- Issue #001 (Create directory structure)

## Implementation Notes
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main library module
    const tui_module = b.addModule("tui", .{
        .root_source_file = b.path("lib/tui.zig"),
    });

    // Library compilation (for testing)
    const lib = b.addStaticLibrary(.{
        .name = "zig-tui",
        .root_source_file = b.path("lib/tui.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    // Test configuration
    const test_step = b.step("test", "Run all tests");
    
    // Add test targets for each module
    const test_modules = [_][]const u8{
        "lib/terminal/terminal.test.zig",
        "lib/screen/screen.test.zig",
        "lib/event/event.test.zig",
        // Add more as implemented
    };

    for (test_modules) |test_file| {
        const tests = b.addTest(.{
            .root_source_file = b.path(test_file),
            .target = target,
            .optimize = optimize,
        });
        const run_tests = b.addRunArtifact(tests);
        test_step.dependOn(&run_tests.step);
    }

    // Benchmark configuration
    const bench_step = b.step("bench", "Run performance benchmarks");
    
    // Examples configuration
    const examples_step = b.step("examples", "Build all examples");
}
```

## Testing Requirements
- Build system compiles without errors
- All test commands work correctly
- Module can be imported in external projects
- Examples build successfully

## Estimated Time
2 hours

## Priority
🔴 Critical - Required for development workflow

## Category
Project Setup