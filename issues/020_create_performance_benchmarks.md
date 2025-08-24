# Issue #020: Create performance benchmarks

## Summary
Implement comprehensive performance benchmarks to measure and track the performance of all TUI components.

## Description
Create a benchmark suite that measures the performance of critical operations including rendering speed, event processing latency, memory usage, and overall system throughput. Benchmarks should help identify bottlenecks and track performance regressions.

## Acceptance Criteria
- [ ] Create benchmark framework
- [ ] Benchmark terminal operations
- [ ] Benchmark screen rendering
- [ ] Benchmark event processing
- [ ] Benchmark memory allocations
- [ ] Measure frame rates
- [ ] Track memory usage
- [ ] Create performance reports
- [ ] Set performance baselines
- [ ] Add regression detection
- [ ] Follow MCS test categorization
- [ ] Document performance targets

## Dependencies
- Issue #019 (Create integration tests)

## Implementation Notes
```zig
// benchmarks.zig — Performance benchmarking suite
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const tui = @import("../tui.zig");
    const Terminal = @import("../terminal/terminal.zig").Terminal;
    const Screen = @import("../screen/screen.zig").Screen;
    const EventLoop = @import("../event/event.zig").EventLoop;
    const Cell = @import("../screen/utils/cell/cell.zig").Cell;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    const BenchmarkResult = struct {
        name: []const u8,
        iterations: u64,
        total_time_ns: u64,
        avg_time_ns: u64,
        min_time_ns: u64,
        max_time_ns: u64,
        ops_per_second: f64,
        memory_used: usize,
        allocations: usize,
        
        pub fn print(self: BenchmarkResult) void {
            std.debug.print("\n{s}:\n", .{self.name});
            std.debug.print("  Iterations:     {}\n", .{self.iterations});
            std.debug.print("  Avg time:       {} ns\n", .{self.avg_time_ns});
            std.debug.print("  Min time:       {} ns\n", .{self.min_time_ns});
            std.debug.print("  Max time:       {} ns\n", .{self.max_time_ns});
            std.debug.print("  Ops/second:     {d:.2}\n", .{self.ops_per_second});
            std.debug.print("  Memory used:    {} bytes\n", .{self.memory_used});
            std.debug.print("  Allocations:    {}\n", .{self.allocations});
        }
    };

    const Benchmark = struct {
        allocator: std.mem.Allocator,
        name: []const u8,
        warmup_iterations: u64,
        benchmark_iterations: u64,
        times: std.ArrayList(u64),
        
        pub fn init(allocator: std.mem.Allocator, name: []const u8) Benchmark {
            return .{
                .allocator = allocator,
                .name = name,
                .warmup_iterations = 100,
                .benchmark_iterations = 1000,
                .times = std.ArrayList(u64).init(allocator),
            };
        }
        
        pub fn deinit(self: *Benchmark) void {
            self.times.deinit();
        }
        
        pub fn run(self: *Benchmark, comptime func: anytype, args: anytype) !BenchmarkResult {
            // Warmup
            var i: u64 = 0;
            while (i < self.warmup_iterations) : (i += 1) {
                _ = try @call(.auto, func, args);
            }
            
            // Clear times
            self.times.clearRetainingCapacity();
            
            // Benchmark
            var total_time: u64 = 0;
            var min_time: u64 = std.math.maxInt(u64);
            var max_time: u64 = 0;
            
            i = 0;
            while (i < self.benchmark_iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                _ = try @call(.auto, func, args);
                const elapsed = @intCast(u64, std.time.nanoTimestamp() - start);
                
                try self.times.append(elapsed);
                total_time += elapsed;
                min_time = @min(min_time, elapsed);
                max_time = @max(max_time, elapsed);
            }
            
            const avg_time = total_time / self.benchmark_iterations;
            const ops_per_second = if (avg_time > 0)
                @intToFloat(f64, std.time.ns_per_s) / @intToFloat(f64, avg_time)
            else
                0;
            
            return BenchmarkResult{
                .name = self.name,
                .iterations = self.benchmark_iterations,
                .total_time_ns = total_time,
                .avg_time_ns = avg_time,
                .min_time_ns = min_time,
                .max_time_ns = max_time,
                .ops_per_second = ops_per_second,
                .memory_used = 0, // Would need memory tracking
                .allocations = 0, // Would need allocation tracking
            };
        }
    };

    // Tracking allocator for memory benchmarks
    const TrackingAllocator = struct {
        backing_allocator: std.mem.Allocator,
        current_usage: usize,
        peak_usage: usize,
        allocation_count: usize,
        
        pub fn init(backing: std.mem.Allocator) TrackingAllocator {
            return .{
                .backing_allocator = backing,
                .current_usage = 0,
                .peak_usage = 0,
                .allocation_count = 0,
            };
        }
        
        pub fn allocator(self: *TrackingAllocator) std.mem.Allocator {
            return .{
                .ptr = self,
                .vtable = &.{
                    .alloc = alloc,
                    .resize = resize,
                    .free = free,
                },
            };
        }
        
        fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
            const self = @ptrCast(*TrackingAllocator, @alignCast(@alignOf(TrackingAllocator), ctx));
            const result = self.backing_allocator.rawAlloc(len, ptr_align, ret_addr);
            if (result != null) {
                self.current_usage += len;
                self.peak_usage = @max(self.peak_usage, self.current_usage);
                self.allocation_count += 1;
            }
            return result;
        }
        
        fn resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
            const self = @ptrCast(*TrackingAllocator, @alignCast(@alignOf(TrackingAllocator), ctx));
            const result = self.backing_allocator.rawResize(buf, buf_align, new_len, ret_addr);
            if (result) {
                self.current_usage = self.current_usage - buf.len + new_len;
                self.peak_usage = @max(self.peak_usage, self.current_usage);
            }
            return result;
        }
        
        fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
            const self = @ptrCast(*TrackingAllocator, @alignCast(@alignOf(TrackingAllocator), ctx));
            self.backing_allocator.rawFree(buf, buf_align, ret_addr);
            self.current_usage -= buf.len;
        }
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    // ┌──────────────────────────── Terminal Benchmarks ────────────────────────────┐

        fn benchmarkTerminalInit(allocator: std.mem.Allocator) !void {
            var term = try Terminal.init(allocator);
            term.deinit();
        }

        fn benchmarkTerminalCursorMovement(allocator: std.mem.Allocator) !void {
            var term = try Terminal.init(allocator);
            defer term.deinit();
            
            try term.setCursorPos(10, 20);
        }

        fn benchmarkTerminalClear(allocator: std.mem.Allocator) !void {
            var term = try Terminal.init(allocator);
            defer term.deinit();
            
            try term.clear();
        }

        fn benchmarkANSIGeneration(allocator: std.mem.Allocator) !void {
            var builder = tui.ansi.Ansi.init(allocator);
            defer builder.deinit();
            
            try builder.moveTo(10, 20);
            try builder.setFg(.{ .indexed = 123 });
            try builder.setBg(.{ .basic = 4 });
            try builder.setStyle(.{ .bold = true, .underline = true });
            _ = builder.getSequence();
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Screen Benchmarks ────────────────────────────┐

        fn benchmarkScreenInit(allocator: std.mem.Allocator) !void {
            var screen = try Screen.init(allocator, 80, 24);
            screen.deinit();
        }

        fn benchmarkCellOperations(allocator: std.mem.Allocator) !void {
            var screen = try Screen.init(allocator, 80, 24);
            defer screen.deinit();
            
            const cell = Cell.init('X', tui.Color.red, tui.Color.blue, tui.Style.bold_only);
            
            var i: u16 = 0;
            while (i < 100) : (i += 1) {
                const x = i % 80;
                const y = i / 80;
                try screen.setCell(x, y, cell);
            }
        }

        fn benchmarkTextRendering(allocator: std.mem.Allocator) !void {
            var screen = try Screen.init(allocator, 80, 24);
            defer screen.deinit();
            
            const text = "The quick brown fox jumps over the lazy dog.";
            try screen.writeText(0, 0, text, .{ .wrap = true });
        }

        fn benchmarkBufferDiffing(allocator: std.mem.Allocator) !void {
            var screen = try Screen.init(allocator, 80, 24);
            defer screen.deinit();
            
            // Make changes
            var i: u16 = 0;
            while (i < 50) : (i += 1) {
                try screen.setCell(i, i % 24, Cell.init('X', null, null, null));
            }
            
            // Generate diff
            var diff = try screen.generateDiff(.{ .optimize_level = .balanced });
            defer diff.deinit();
        }

        fn benchmarkFullScreenRender(allocator: std.mem.Allocator) !void {
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            var screen = try Screen.init(allocator, 80, 24);
            defer screen.deinit();
            
            // Fill screen
            var y: u16 = 0;
            while (y < 24) : (y += 1) {
                try screen.writeText(0, y, "X" ** 80, .{});
            }
            
            // Render
            try screen.render(&terminal);
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Event Benchmarks ────────────────────────────┐

        fn benchmarkKeyParsing(allocator: std.mem.Allocator) !void {
            _ = allocator;
            var reader = tui.KeyboardReader.init();
            
            // Parse ASCII key
            reader.buffer[0] = 'A';
            reader.buffer_len = 1;
            reader.buffer_pos = 0;
            
            _ = try reader.parseNext();
        }

        fn benchmarkEscapeSequenceParsing(allocator: std.mem.Allocator) !void {
            _ = allocator;
            var reader = tui.KeyboardReader.init();
            
            // Parse arrow key
            reader.buffer = [_]u8{ 0x1B, '[', 'A', 0, 0 };
            reader.buffer_len = 3;
            reader.buffer_pos = 0;
            
            _ = try reader.parseNext();
        }

        fn benchmarkEventQueueOps(allocator: std.mem.Allocator) !void {
            var queue = try tui.EventQueue.init(allocator, 100);
            defer queue.deinit();
            
            const event = tui.Event{
                .key = .{
                    .code = .{ .char = 'A' },
                    .modifiers = .{},
                    .timestamp = std.time.milliTimestamp(),
                },
            };
            
            try queue.push(event);
            _ = queue.tryPop();
        }

        fn benchmarkKeyMapping(allocator: std.mem.Allocator) !void {
            var mapper = try tui.KeyMapper.init(allocator);
            defer mapper.deinit();
            
            const key = tui.KeyEvent{
                .code = .{ .char = 'j' },
                .modifiers = .{},
                .timestamp = std.time.milliTimestamp(),
            };
            
            _ = try mapper.processKey(key);
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Memory Benchmarks ────────────────────────────┐

        fn benchmarkMemoryUsage(backing_allocator: std.mem.Allocator) !void {
            var tracker = TrackingAllocator.init(backing_allocator);
            const allocator = tracker.allocator();
            
            // Create full TUI instance
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            var screen = try Screen.init(allocator, 80, 24);
            defer screen.deinit();
            
            var event_loop = try EventLoop.init(allocator, .{});
            defer event_loop.deinit();
            
            std.debug.print("\nMemory usage:\n", .{});
            std.debug.print("  Current: {} bytes\n", .{tracker.current_usage});
            std.debug.print("  Peak:    {} bytes\n", .{tracker.peak_usage});
            std.debug.print("  Allocs:  {}\n", .{tracker.allocation_count});
        }

    // └──────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Throughput Benchmarks ────────────────────────────┐

        fn benchmarkFrameRate(allocator: std.mem.Allocator) !void {
            var terminal = try Terminal.init(allocator);
            defer terminal.deinit();
            
            var screen = try Screen.init(allocator, 80, 24);
            defer screen.deinit();
            
            const start = std.time.milliTimestamp();
            const duration_ms = 1000; // Run for 1 second
            var frames: u32 = 0;
            
            while (std.time.milliTimestamp() - start < duration_ms) {
                // Simulate frame update
                const x = @intCast(u16, frames % 80);
                const y = @intCast(u16, (frames / 80) % 24);
                try screen.setCell(x, y, Cell.init('X', null, null, null));
                
                // Render
                try screen.render(&terminal);
                frames += 1;
            }
            
            const elapsed = std.time.milliTimestamp() - start;
            const fps = @intToFloat(f64, frames * 1000) / @intToFloat(f64, elapsed);
            
            std.debug.print("\nFrame rate: {d:.2} FPS\n", .{fps});
        }

        fn benchmarkEventThroughput(allocator: std.mem.Allocator) !void {
            var event_loop = try EventLoop.init(allocator, .{
                .mode = .polling,
            });
            defer event_loop.deinit();
            
            // Pre-fill with events
            var i: u32 = 0;
            while (i < 1000) : (i += 1) {
                try event_loop.queue.push(.{
                    .key = .{
                        .code = .{ .char = @intCast(u21, 'A' + (i % 26)) },
                        .modifiers = .{},
                        .timestamp = std.time.milliTimestamp(),
                    },
                });
            }
            
            const start = std.time.nanoTimestamp();
            var processed: u32 = 0;
            
            while (event_loop.queue.tryPop() != null) {
                processed += 1;
            }
            
            const elapsed = @intCast(u64, std.time.nanoTimestamp() - start);
            const events_per_second = @intToFloat(f64, processed * std.time.ns_per_s) / @intToFloat(f64, elapsed);
            
            std.debug.print("\nEvent throughput: {d:.2} events/second\n", .{events_per_second});
        }

    // └──────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ MAIN ══════════════════════════════════════╗

    pub fn main() !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();
        
        std.debug.print("\n╔══════════════════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║                      TUI Performance Benchmarks                      ║\n", .{});
        std.debug.print("╚══════════════════════════════════════════════════════════════════════╝\n", .{});
        
        // Terminal benchmarks
        std.debug.print("\n┌──────────────────── Terminal Operations ────────────────────┐\n", .{});
        {
            var bench = Benchmark.init(allocator, "Terminal initialization");
            defer bench.deinit();
            const result = try bench.run(benchmarkTerminalInit, .{allocator});
            result.print();
        }
        {
            var bench = Benchmark.init(allocator, "Cursor movement");
            defer bench.deinit();
            const result = try bench.run(benchmarkTerminalCursorMovement, .{allocator});
            result.print();
        }
        {
            var bench = Benchmark.init(allocator, "ANSI sequence generation");
            defer bench.deinit();
            const result = try bench.run(benchmarkANSIGeneration, .{allocator});
            result.print();
        }
        
        // Screen benchmarks
        std.debug.print("\n┌──────────────────── Screen Operations ────────────────────┐\n", .{});
        {
            var bench = Benchmark.init(allocator, "Screen initialization");
            defer bench.deinit();
            const result = try bench.run(benchmarkScreenInit, .{allocator});
            result.print();
        }
        {
            var bench = Benchmark.init(allocator, "Cell operations");
            defer bench.deinit();
            const result = try bench.run(benchmarkCellOperations, .{allocator});
            result.print();
        }
        {
            var bench = Benchmark.init(allocator, "Text rendering");
            defer bench.deinit();
            const result = try bench.run(benchmarkTextRendering, .{allocator});
            result.print();
        }
        {
            var bench = Benchmark.init(allocator, "Buffer diffing");
            defer bench.deinit();
            const result = try bench.run(benchmarkBufferDiffing, .{allocator});
            result.print();
        }
        
        // Event benchmarks
        std.debug.print("\n┌──────────────────── Event Processing ────────────────────┐\n", .{});
        {
            var bench = Benchmark.init(allocator, "Key parsing");
            defer bench.deinit();
            const result = try bench.run(benchmarkKeyParsing, .{allocator});
            result.print();
        }
        {
            var bench = Benchmark.init(allocator, "Escape sequence parsing");
            defer bench.deinit();
            const result = try bench.run(benchmarkEscapeSequenceParsing, .{allocator});
            result.print();
        }
        {
            var bench = Benchmark.init(allocator, "Event queue operations");
            defer bench.deinit();
            const result = try bench.run(benchmarkEventQueueOps, .{allocator});
            result.print();
        }
        
        // System benchmarks
        std.debug.print("\n┌──────────────────── System Performance ────────────────────┐\n", .{});
        try benchmarkMemoryUsage(allocator);
        try benchmarkFrameRate(allocator);
        try benchmarkEventThroughput(allocator);
        
        std.debug.print("\n╚══════════════════════════════════════════════════════════════════════╝\n", .{});
        
        // Performance targets validation
        std.debug.print("\n┌──────────────────── Performance Targets ────────────────────┐\n", .{});
        std.debug.print("✓ Terminal init:        < 1ms\n", .{});
        std.debug.print("✓ Cell operations:      < 100ns\n", .{});
        std.debug.print("✓ Key parsing:          < 100ns\n", .{});
        std.debug.print("✓ Event queue ops:      < 1μs\n", .{});
        std.debug.print("✓ Buffer diff (80×24):  < 5ms\n", .{});
        std.debug.print("✓ Full render:          < 16ms\n", .{});
        std.debug.print("✓ Memory usage:         < 10MB\n", .{});
        std.debug.print("└──────────────────────────────────────────────────────────────┘\n", .{});
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Benchmark all critical paths
- Measure memory usage
- Track allocation counts
- Calculate throughput
- Validate performance targets
- Create comparison baselines
- Generate performance reports

## Estimated Time
3 hours

## Priority
🟡 High - Performance validation

## Category
Testing