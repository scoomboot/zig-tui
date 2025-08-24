# Testing Conventions

This document defines the testing conventions and guidelines for the Zig NFL Clock library, following the Maysara Code Style (MCS) principles.

## Test Categories

The testing framework organizes tests into distinct categories, each serving a specific purpose in validating the codebase:

### `unit`: Unit Tests
Tests for individual functions or small components in isolation. These tests verify that each piece of functionality works correctly on its own, without dependencies on other components.

**Purpose**: Validate core logic, algorithms, and data transformations at the smallest testable level.

**Example Scenarios**:
- Testing a single function's output for various inputs
- Validating error handling for invalid parameters
- Checking edge cases and boundary conditions

### `integration`: Integration Tests
Tests that verify interactions between multiple components. These tests ensure that different parts of the system work together correctly.

**Purpose**: Validate component interactions, data flow between modules, and API contracts.

**Example Scenarios**:
- Testing GameClock with RulesEngine interaction
- Validating PlayHandler updates to GameClock state
- Verifying TimeFormatter output with GameClock data

### `e2e`: End-to-End Tests
End-to-end tests that validate complete workflows from start to finish. These tests simulate real user scenarios and verify the entire system behavior.

**Purpose**: Ensure the system works correctly as a whole for real-world use cases.

**Example Scenarios**:
- Complete game simulation from kickoff to final whistle
- Full overtime period workflow
- Complete two-minute warning sequence

### `scenario`: Scenario Tests
Real-world usage scenarios specific to NFL game situations. These tests validate that the library correctly handles actual game rules and edge cases.

**Purpose**: Ensure compliance with NFL timing rules and validate real game situations.

**Example Scenarios**:
- Two-minute warning clock behavior
- Timeout management in different quarters
- Clock runoff situations
- Injury timeout handling

### `performance`: Performance Tests
Tests that measure and validate performance characteristics. These tests ensure the library meets performance requirements and doesn't regress.

**Purpose**: Validate performance metrics, benchmark critical paths, and prevent performance regressions.

**Example Scenarios**:
- Clock tick performance under normal conditions
- Memory allocation patterns during game simulation
- Time formatting performance for various displays

### `stress`: Stress Tests
Tests that verify behavior under extreme conditions. These tests push the system beyond normal operating parameters to ensure robustness.

**Purpose**: Validate system stability, memory safety, and error handling under extreme load.

**Example Scenarios**:
- Rapid clock state changes
- Maximum overtime periods
- Concurrent clock operations
- Memory pressure scenarios

## Test Naming Convention

All tests must follow the standardized naming format to ensure consistency and enable automated test analysis:

```zig
test "<category>: <component>: <description>" {
    // Test implementation
}
```

### Format Components

- **`<category>`**: One of the defined test categories (unit, integration, e2e, scenario, performance, stress)
- **`<component>`**: The component or module being tested (e.g., GameClock, RulesEngine, PlayHandler)
- **`<description>`**: Clear, concise description of what the test validates

### Examples by Category

```zig
// Unit test example
test "unit: GameClock: initializes with default values" {
    const allocator = testing.allocator;
    const clock = try GameClock.init(allocator);
    defer clock.deinit();
    
    try testing.expectEqual(@as(u32, QUARTER_LENGTH_SECONDS), clock.time_remaining);
    try testing.expectEqual(Quarter.first, clock.quarter);
}

// Integration test example
test "integration: GameClock with RulesEngine: applies two-minute warning rules" {
    const allocator = testing.allocator;
    var clock = try GameClock.init(allocator);
    defer clock.deinit();
    
    // Test interaction between components
    try clock.setTimeRemaining(121); // 2:01
    try clock.tick();
    // Verify RulesEngine applied two-minute warning
}

// End-to-end test example
test "e2e: complete regulation game: flows through all four quarters" {
    const allocator = testing.allocator;
    var game = try simulateCompleteGame(allocator);
    defer game.deinit();
    
    try testing.expectEqual(Quarter.fourth, game.final_quarter);
    try testing.expectEqual(@as(u32, 0), game.time_remaining);
}

// Scenario test example
test "scenario: NFL timeout rules: correct timeout allocation per half" {
    const allocator = testing.allocator;
    var clock = try GameClock.init(allocator);
    defer clock.deinit();
    
    // Verify NFL-specific timeout rules
    try testing.expectEqual(@as(u8, 3), clock.home_timeouts);
    try testing.expectEqual(@as(u8, 3), clock.away_timeouts);
}

// Performance test example
test "performance: clock tick: processes 1000 ticks under 1ms" {
    const allocator = testing.allocator;
    var clock = try GameClock.init(allocator);
    defer clock.deinit();
    
    const start = std.time.milliTimestamp();
    for (0..1000) |_| {
        try clock.tick();
    }
    const elapsed = std.time.milliTimestamp() - start;
    try testing.expect(elapsed < 1);
}

// Stress test example
test "stress: GameClock: handles rapid state changes without memory leaks" {
    const allocator = testing.allocator;
    
    for (0..10000) |_| {
        var clock = try GameClock.init(allocator);
        try clock.start();
        try clock.stop();
        try clock.reset();
        clock.deinit();
    }
}
```

## Test Organization

Tests should be organized following a consistent structure within test files:

### File Structure

```zig
// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    // Test helpers and data structures
    const TestHelper = struct { ... };
    const createTestClock = ...;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ TEST ══════════════════════════════════════╗

    // ┌──────────────────────────── Unit Tests ────────────────────────────┐
    
        test "unit: Component: test case 1" { ... }
        test "unit: Component: test case 2" { ... }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Integration Tests ────────────────────────────┐
    
        test "integration: Components: test case 1" { ... }
        test "integration: Components: test case 2" { ... }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── E2E Tests ────────────────────────────┐
    
        test "e2e: workflow: complete scenario" { ... }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Scenario Tests ────────────────────────────┐
    
        test "scenario: NFL rule: specific situation" { ... }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Performance Tests ────────────────────────────┐
    
        test "performance: operation: meets requirements" { ... }
    
    // └──────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────── Stress Tests ────────────────────────────┐
    
        test "stress: component: handles extreme conditions" { ... }
    
    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

### Ordering Guidelines

1. **Test helpers** and factories go in the INIT section at the beginning
2. **Test categories** appear in this order:
   - Unit tests (most granular)
   - Integration tests
   - End-to-end tests
   - Scenario tests (domain-specific)
   - Performance tests
   - Stress tests (most extreme)
3. **Related tests** within a category should be grouped with comments
4. **Test data** should be defined near the tests that use it

## Test Coverage Guidelines

### Expected Coverage by Category

#### Unit Tests
- **Target**: 100% coverage of public functions
- **Requirements**:
  - All public API functions must have tests
  - Each function should have tests for:
    - Normal inputs (happy path)
    - Edge cases (boundary values)
    - Error conditions (invalid inputs)
    - Special values (null, empty, zero)

#### Integration Tests
- **Target**: 80% coverage of component interactions
- **Requirements**:
  - Critical component interactions must be tested
  - Data flow between modules verified
  - State consistency across components validated

#### E2E Tests
- **Target**: Core user workflows covered
- **Requirements**:
  - Primary use cases must have e2e tests
  - Complete workflow from initialization to completion
  - Error recovery scenarios included

#### Scenario Tests
- **Target**: All NFL timing rules covered
- **Requirements**:
  - Each timing rule must have corresponding tests
  - Edge cases in game situations covered
  - Rule interactions validated

### Test Case Requirements

#### Positive Test Cases
Every function should have tests that verify correct behavior with valid inputs:

```zig
test "unit: GameClock: starts clock successfully" {
    const allocator = testing.allocator;
    var clock = try GameClock.init(allocator);
    defer clock.deinit();
    
    try clock.start();
    try testing.expect(clock.is_running);
}
```

#### Negative Test Cases
Functions should have tests for error conditions and invalid inputs:

```zig
test "unit: GameClock: returns error when starting already running clock" {
    const allocator = testing.allocator;
    var clock = try GameClock.init(allocator);
    defer clock.deinit();
    
    try clock.start();
    const result = clock.start();
    try testing.expectError(GameClockError.AlreadyRunning, result);
}
```

#### Edge Case Testing
Boundary conditions and special values must be tested:

```zig
test "unit: GameClock: handles zero time remaining correctly" {
    const allocator = testing.allocator;
    var clock = try GameClock.init(allocator);
    defer clock.deinit();
    
    try clock.setTimeRemaining(0);
    try clock.tick();
    try testing.expectEqual(@as(u32, 0), clock.time_remaining);
}
```

### Memory Safety Requirements

All tests must use `std.testing.allocator` to ensure memory safety:

```zig
test "unit: Component: allocates and frees memory correctly" {
    const allocator = testing.allocator;
    
    // Allocate resources
    var component = try Component.init(allocator);
    defer component.deinit(); // Ensure cleanup
    
    // Test operations
    try component.operation();
    
    // allocator will detect leaks automatically
}
```

## Test Execution

### Running All Tests

Execute the complete test suite:

```bash
# Run all tests
zig build test

# Run tests with specific optimization mode
zig build test -Doptimize=Debug
zig build test -Doptimize=ReleaseSafe
zig build test -Doptimize=ReleaseFast
```

### Running Specific Test Files

Execute tests from a specific file:

```bash
# Run tests for a specific module
zig test lib/game_clock/game_clock.test.zig

# Run with test filter (Zig 0.11.0+)
zig test lib/game_clock/game_clock.test.zig --test-filter "unit:"

# Run with specific allocator settings
zig test lib/game_clock/game_clock.test.zig --test-filter "stress:" --test-allocator
```

### Test Filtering

Filter tests by category or component:

```bash
# Run only unit tests
zig build test --test-filter "unit:"

# Run only integration tests for GameClock
zig build test --test-filter "integration: GameClock:"

# Run specific scenario tests
zig build test --test-filter "scenario: NFL timeout"
```

## Test Helper Functions

Common test helper functions should be defined in the INIT section of test files:

### Factory Functions

Create test objects with default or specific configurations:

```zig
/// Creates a test GameClock with default settings
fn createTestClock(allocator: std.mem.Allocator) !*GameClock {
    var clock = try allocator.create(GameClock);
    clock.* = try GameClock.init(allocator);
    return clock;
}

/// Creates a test GameClock in a specific state
fn createClockInState(
    allocator: std.mem.Allocator,
    quarter: Quarter,
    time_remaining: u32,
    is_running: bool,
) !*GameClock {
    var clock = try createTestClock(allocator);
    clock.quarter = quarter;
    clock.time_remaining = time_remaining;
    clock.is_running = is_running;
    return clock;
}
```

### Custom Assertions

Define domain-specific assertion helpers:

```zig
/// Asserts that two time values are equal
fn assertTimeEquals(expected: u32, actual: u32) !void {
    if (expected != actual) {
        std.debug.print("Time mismatch: expected {d}s, got {d}s\n", .{ expected, actual });
        return error.TestAssertionFailed;
    }
}

/// Asserts that clock is in expected state
fn assertClockState(
    clock: *const GameClock,
    expected_quarter: Quarter,
    expected_running: bool,
) !void {
    try testing.expectEqual(expected_quarter, clock.quarter);
    try testing.expectEqual(expected_running, clock.is_running);
}
```

### Complex Operation Helpers

Helpers for multi-step test operations:

```zig
/// Simulates a complete play from snap to whistle
fn simulatePlay(
    clock: *GameClock,
    play_duration: u32,
    outcome: PlayOutcome,
) !void {
    try clock.start();
    for (0..play_duration) |_| {
        try clock.tick();
    }
    try clock.stop();
    try clock.processPlayOutcome(outcome);
}

/// Advances clock to specific game time
fn advanceToTime(
    clock: *GameClock,
    target_quarter: Quarter,
    target_time: u32,
) !void {
    while (clock.quarter != target_quarter or clock.time_remaining > target_time) {
        try clock.tick();
    }
}
```

### Test Data Factories

Generate test data consistently:

```zig
/// Test data for various game situations
const TestScenarios = struct {
    /// Two-minute warning scenario
    pub fn twoMinuteWarning(allocator: std.mem.Allocator) !TestScenario {
        return TestScenario{
            .name = "Two-minute warning",
            .initial_time = 121, // 2:01
            .quarter = Quarter.second,
            .expected_behavior = .automatic_timeout,
        };
    }
    
    /// End of quarter scenario
    pub fn endOfQuarter(allocator: std.mem.Allocator) !TestScenario {
        return TestScenario{
            .name = "End of quarter",
            .initial_time = 1,
            .quarter = Quarter.first,
            .expected_behavior = .quarter_transition,
        };
    }
};
```

## Best Practices

### Memory Safety with std.testing.allocator

Always use `std.testing.allocator` for memory-safe tests:

```zig
test "unit: Component: manages memory correctly" {
    const allocator = testing.allocator;
    
    // Create resources
    var list = std.ArrayList(u32).init(allocator);
    defer list.deinit(); // Always defer cleanup
    
    // Perform operations
    try list.append(42);
    try list.append(84);
    
    // Verify behavior
    try testing.expectEqual(@as(usize, 2), list.items.len);
    
    // allocator automatically detects leaks on test completion
}
```

### Proper Cleanup in Tests

Ensure all resources are properly cleaned up:

```zig
test "integration: MultiComponent: cleans up all resources" {
    const allocator = testing.allocator;
    
    // Setup phase
    var component_a = try ComponentA.init(allocator);
    defer component_a.deinit();
    
    var component_b = try ComponentB.init(allocator);
    defer component_b.deinit();
    
    // Connect components
    try component_a.connect(&component_b);
    defer component_a.disconnect();
    
    // Test operations
    try component_a.processWithB();
    
    // Cleanup happens automatically via defer
}
```

### Test Isolation Principles

Each test should be independent and not affect others:

```zig
test "unit: GameClock: test 1 - isolated state" {
    const allocator = testing.allocator;
    
    // Create fresh instance for this test
    var clock = try GameClock.init(allocator);
    defer clock.deinit();
    
    // Test operates on isolated instance
    try clock.start();
    try testing.expect(clock.is_running);
    
    // State is cleaned up, doesn't affect next test
}

test "unit: GameClock: test 2 - fresh state" {
    const allocator = testing.allocator;
    
    // New instance, unaffected by test 1
    var clock = try GameClock.init(allocator);
    defer clock.deinit();
    
    // Clock starts in default state
    try testing.expect(!clock.is_running);
}
```

### Performance Test Guidelines

Performance tests should be deterministic and meaningful:

```zig
test "performance: GameClock.tick: maintains sub-microsecond performance" {
    const allocator = testing.allocator;
    var clock = try GameClock.init(allocator);
    defer clock.deinit();
    
    // Warm up to avoid cold cache effects
    for (0..100) |_| {
        try clock.tick();
    }
    
    // Measure actual performance
    const iterations = 10000;
    const start = std.time.nanoTimestamp();
    
    for (0..iterations) |_| {
        try clock.tick();
    }
    
    const elapsed = std.time.nanoTimestamp() - start;
    const avg_ns = @divFloor(elapsed, iterations);
    
    // Verify performance requirement
    try testing.expect(avg_ns < 1000); // < 1 microsecond
    
    // Optional: Print performance metrics
    if (@import("builtin").mode == .Debug) {
        std.debug.print("Average tick time: {d}ns\n", .{avg_ns});
    }
}
```

### Stress Test Patterns

Stress tests should push boundaries safely:

```zig
test "stress: GameClock: survives 1 million rapid operations" {
    const allocator = testing.allocator;
    var clock = try GameClock.init(allocator);
    defer clock.deinit();
    
    const operations = 1_000_000;
    var rng = std.rand.DefaultPrng.init(12345); // Deterministic seed
    const random = rng.random();
    
    for (0..operations) |i| {
        // Random operation selection
        const op = random.intRangeAtMost(u8, 0, 4);
        
        switch (op) {
            0 => clock.start() catch {},  // Ignore expected errors
            1 => clock.stop() catch {},
            2 => try clock.tick(),
            3 => try clock.resetPlayClock(),
            4 => {
                const new_time = random.intRangeAtMost(u32, 0, 900);
                clock.setTimeRemaining(new_time) catch {};
            },
            else => unreachable,
        }
        
        // Verify invariants hold
        try testing.expect(clock.time_remaining <= QUARTER_LENGTH_SECONDS);
        try testing.expect(clock.play_clock <= PLAY_CLOCK_SECONDS);
    }
}
```

## Testing Anti-Patterns to Avoid

### Don't Share State Between Tests

```zig
// BAD: Shared mutable state
var shared_clock: ?*GameClock = null;

test "unit: Test 1" {
    shared_clock = try GameClock.init(allocator);
    // Test modifies shared_clock
}

test "unit: Test 2" {
    // This test depends on state from Test 1 - BAD!
    try shared_clock.?.start();
}

// GOOD: Each test creates its own state
test "unit: Test 1" {
    var clock = try GameClock.init(allocator);
    defer clock.deinit();
    // Test uses local clock
}

test "unit: Test 2" {
    var clock = try GameClock.init(allocator);
    defer clock.deinit();
    // Test uses its own clock
}
```

### Don't Skip Cleanup

```zig
// BAD: Missing cleanup
test "unit: Component: leaks memory" {
    const allocator = testing.allocator;
    var component = try Component.init(allocator);
    
    try component.operation();
    // Missing deinit - will leak memory!
}

// GOOD: Always cleanup
test "unit: Component: properly managed" {
    const allocator = testing.allocator;
    var component = try Component.init(allocator);
    defer component.deinit(); // Always cleanup
    
    try component.operation();
}
```

### Don't Use Fixed Time Delays

```zig
// BAD: Uses actual time delays
test "unit: Timer: waits real time" {
    std.time.sleep(1_000_000_000); // Sleeps 1 second - BAD!
    // Makes tests slow and non-deterministic
}

// GOOD: Mock or simulate time
test "unit: Timer: simulates time passage" {
    var timer = Timer.init();
    timer.simulateElapsed(1_000_000_000); // Instant simulation
    try testing.expectEqual(@as(u64, 1_000_000_000), timer.elapsed);
}
```

## Continuous Integration Considerations

### CI Test Configuration

Tests should be configured for CI environments:

```zig
// Detect CI environment and adjust accordingly
const is_ci = std.process.getEnvVarOwned(allocator, "CI") catch null;

test "performance: adjusted for CI" {
    const iterations = if (is_ci != null) 1000 else 10000;
    
    // Run fewer iterations in CI for speed
    for (0..iterations) |_| {
        // Test logic
    }
}
```

### Test Output for CI

Provide clear output for CI systems:

```zig
test "unit: Component: provides clear failure messages" {
    const result = component.operation() catch |err| {
        std.debug.print("Failed at line {d}: {s}\n", .{ 
            @src().line, 
            @errorName(err) 
        });
        return err;
    };
    
    try testing.expectEqual(expected, result);
}
```

## Summary

Following these testing conventions ensures:

1. **Consistency**: All tests follow the same patterns and naming
2. **Maintainability**: Tests are easy to understand and modify
3. **Reliability**: Tests are isolated and deterministic
4. **Coverage**: All aspects of the code are thoroughly tested
5. **Performance**: Tests run efficiently in development and CI
6. **Safety**: Memory leaks and errors are caught early

By adhering to these guidelines and the MCS principles, the test suite becomes a robust safety net that enables confident development and refactoring while maintaining code quality and performance standards.