# Issue #010: Implement buffer diffing

## Summary
Create an efficient diffing algorithm to detect changes between screen buffers for minimal terminal updates.

## Description
Implement a sophisticated diffing system that compares the front and back buffers to identify changed regions. The algorithm should minimize the number of terminal write operations by detecting contiguous changes, identifying moved content, and optimizing update sequences.

## Acceptance Criteria
- [ ] Implement basic cell-by-cell comparison
- [ ] Detect contiguous changed regions
- [ ] Optimize for common patterns:
  - [ ] Horizontal spans of changes
  - [ ] Vertical scrolling
  - [ ] Block moves
  - [ ] Clear operations
- [ ] Generate minimal update sequences
- [ ] Support incremental updates
- [ ] Handle style-only changes efficiently
- [ ] Add diff compression strategies
- [ ] Create performance benchmarks
- [ ] Follow MCS style guidelines

## Dependencies
- Issue #009 (Implement screen buffer)

## Implementation Notes
```zig
// Part of screen.zig — Buffer diffing algorithm
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    pub const DiffOp = union(enum) {
        set_cell: struct {
            x: u16,
            y: u16,
            cell: Cell,
        },
        set_span: struct {
            x: u16,
            y: u16,
            cells: []const Cell,
        },
        copy_region: struct {
            src_x: u16,
            src_y: u16,
            dst_x: u16,
            dst_y: u16,
            width: u16,
            height: u16,
        },
        clear_region: struct {
            x: u16,
            y: u16,
            width: u16,
            height: u16,
        },
        scroll: struct {
            region: Rect,
            lines: i16,  // Negative for up, positive for down
        },
    };

    pub const DiffResult = struct {
        ops: std.ArrayList(DiffOp),
        estimated_cost: u32,  // Estimated terminal write operations
        
        pub fn deinit(self: *DiffResult) void {
            self.ops.deinit();
        }
    };

    pub const DiffOptions = struct {
        optimize_level: OptimizeLevel = .balanced,
        detect_scrolling: bool = true,
        detect_moves: bool = true,
        merge_threshold: u16 = 3,  // Merge spans shorter than this
        
        pub const OptimizeLevel = enum {
            none,      // Simple cell-by-cell diff
            basic,     // Merge contiguous changes
            balanced,  // Detect patterns, reasonable CPU usage
            aggressive,// Maximum optimization, higher CPU usage
        };
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    // Extension to Screen struct
    pub const Screen = struct {
        // ... existing fields ...
        
        // ┌──────────────────────────── Diff Generation ────────────────────────────┐

            /// Generate diff between front and back buffers
            pub fn generateDiff(self: *Screen, options: DiffOptions) !DiffResult {
                var result = DiffResult{
                    .ops = std.ArrayList(DiffOp).init(self.allocator),
                    .estimated_cost = 0,
                };

                switch (options.optimize_level) {
                    .none => try self.simpleDiff(&result),
                    .basic => try self.basicDiff(&result, options),
                    .balanced => try self.balancedDiff(&result, options),
                    .aggressive => try self.aggressiveDiff(&result, options),
                }

                return result;
            }

            /// Simple cell-by-cell diff
            fn simpleDiff(self: *Screen, result: *DiffResult) !void {
                const size = self.width * self.height;
                
                var i: usize = 0;
                while (i < size) : (i += 1) {
                    if (!self.front_buffer[i].equals(self.back_buffer[i])) {
                        const x = @intCast(u16, i % self.width);
                        const y = @intCast(u16, i / self.width);
                        
                        try result.ops.append(.{
                            .set_cell = .{
                                .x = x,
                                .y = y,
                                .cell = self.back_buffer[i],
                            },
                        });
                        result.estimated_cost += 1;
                    }
                }
            }

            /// Basic diff with span merging
            fn basicDiff(self: *Screen, result: *DiffResult, options: DiffOptions) !void {
                var y: u16 = 0;
                while (y < self.height) : (y += 1) {
                    try self.diffRow(y, result, options);
                }
            }

            /// Balanced diff with pattern detection
            fn balancedDiff(self: *Screen, result: *DiffResult, options: DiffOptions) !void {
                // Check for scrolling first
                if (options.detect_scrolling) {
                    if (try self.detectScroll(result)) {
                        // Apply scroll, then diff remaining changes
                        try self.diffAfterScroll(result, options);
                        return;
                    }
                }

                // Check for large moves
                if (options.detect_moves) {
                    try self.detectBlockMoves(result);
                }

                // Diff remaining changes
                try self.diffResidual(result, options);
            }

            /// Aggressive diff with maximum optimization
            fn aggressiveDiff(self: *Screen, result: *DiffResult, options: DiffOptions) !void {
                // Build change map
                var change_map = try self.buildChangeMap();
                defer self.allocator.free(change_map);

                // Find optimal update strategy
                try self.findOptimalStrategy(change_map, result, options);
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Row Diffing ────────────────────────────┐

            fn diffRow(self: *Screen, y: u16, result: *DiffResult, options: DiffOptions) !void {
                const row_start = y * self.width;
                const row_end = row_start + self.width;
                
                var x: u16 = 0;
                while (x < self.width) {
                    const idx = row_start + x;
                    
                    // Find start of change
                    if (self.front_buffer[idx].equals(self.back_buffer[idx])) {
                        x += 1;
                        continue;
                    }
                    
                    // Find end of change
                    const change_start = x;
                    while (x < self.width) : (x += 1) {
                        const i = row_start + x;
                        if (i >= row_end or self.front_buffer[i].equals(self.back_buffer[i])) {
                            break;
                        }
                    }
                    
                    const change_len = x - change_start;
                    
                    // Decide whether to use span or individual cells
                    if (change_len >= options.merge_threshold) {
                        try result.ops.append(.{
                            .set_span = .{
                                .x = change_start,
                                .y = y,
                                .cells = self.back_buffer[row_start + change_start..row_start + x],
                            },
                        });
                        result.estimated_cost += 1;
                    } else {
                        var i = change_start;
                        while (i < x) : (i += 1) {
                            try result.ops.append(.{
                                .set_cell = .{
                                    .x = i,
                                    .y = y,
                                    .cell = self.back_buffer[row_start + i],
                                },
                            });
                            result.estimated_cost += 1;
                        }
                    }
                }
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Pattern Detection ────────────────────────────┐

            fn detectScroll(self: *Screen, result: *DiffResult) !bool {
                // Detect vertical scrolling by comparing row hashes
                const max_scroll = @min(self.height / 4, 10);
                
                var scroll_offset: i16 = -@intCast(i16, max_scroll);
                while (scroll_offset <= @intCast(i16, max_scroll)) : (scroll_offset += 1) {
                    if (scroll_offset == 0) continue;
                    
                    var matches: u16 = 0;
                    var y: u16 = 0;
                    
                    while (y < self.height) : (y += 1) {
                        const src_y = @intCast(i32, y) + scroll_offset;
                        if (src_y < 0 or src_y >= self.height) continue;
                        
                        if (self.rowsEqual(y, @intCast(u16, src_y))) {
                            matches += 1;
                        }
                    }
                    
                    // If >70% of rows match with offset, it's likely a scroll
                    if (matches > (self.height * 7) / 10) {
                        try result.ops.append(.{
                            .scroll = .{
                                .region = Rect{
                                    .x = 0,
                                    .y = 0,
                                    .width = self.width,
                                    .height = self.height,
                                },
                                .lines = scroll_offset,
                            },
                        });
                        result.estimated_cost += 1;
                        return true;
                    }
                }
                
                return false;
            }

            fn detectBlockMoves(self: *Screen, result: *DiffResult) !void {
                // Detect moved rectangular regions
                // This is computationally expensive, so limit search space
                
                const min_block_size = 3;
                const max_block_size = @min(self.width / 2, self.height / 2);
                
                // Build signature map for blocks in back buffer
                // Compare with front buffer to find matches
                // Generate copy_region operations for matches
            }

            fn rowsEqual(self: *Screen, y1: u16, y2: u16) bool {
                const start1 = y1 * self.width;
                const start2 = y2 * self.width;
                
                var x: u16 = 0;
                while (x < self.width) : (x += 1) {
                    if (!self.front_buffer[start1 + x].equals(self.back_buffer[start2 + x])) {
                        return false;
                    }
                }
                
                return true;
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Optimization ────────────────────────────┐

            fn buildChangeMap(self: *Screen) ![]bool {
                const size = self.width * self.height;
                const map = try self.allocator.alloc(bool, size);
                
                var i: usize = 0;
                while (i < size) : (i += 1) {
                    map[i] = !self.front_buffer[i].equals(self.back_buffer[i]);
                }
                
                return map;
            }

            fn findOptimalStrategy(self: *Screen, change_map: []bool, result: *DiffResult, options: DiffOptions) !void {
                // Analyze change patterns and choose optimal update strategy
                // Consider factors like:
                // - Contiguity of changes
                // - Density of changes
                // - Patterns (scrolls, clears, moves)
                // - Terminal capabilities
                
                _ = change_map;
                _ = options;
                
                // Placeholder for sophisticated optimization
                try self.basicDiff(result, options);
            }

        // └──────────────────────────────────────────────────────────────────┘

    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Test simple cell changes
- Test span detection and merging
- Test scroll detection
- Test block move detection
- Test edge cases (empty buffers, full changes)
- Benchmark different optimization levels
- Performance targets:
  - Simple diff: < 1ms for 80×24 screen
  - Balanced diff: < 5ms for 80×24 screen
  - Aggressive diff: < 10ms for 80×24 screen

## Estimated Time
3 hours

## Priority
🟡 High - Critical for performance

## Category
Screen Management