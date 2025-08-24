# Issue #011: Implement screen rendering

## Summary
Create the rendering pipeline that applies screen buffer diffs to the terminal using ANSI sequences.

## Description
Implement a renderer that takes diff operations from the buffer comparison and efficiently applies them to the terminal. The renderer should optimize write operations, batch updates when possible, and handle different terminal capabilities.

## Acceptance Criteria
- [ ] Create rendering pipeline in screen module
- [ ] Implement diff operation application
- [ ] Optimize ANSI sequence generation
- [ ] Batch similar operations
- [ ] Handle cursor positioning efficiently
- [ ] Implement render timing/frame limiting
- [ ] Add render statistics tracking
- [ ] Support partial updates
- [ ] Handle terminal capability detection
- [ ] Follow MCS style guidelines

## Dependencies
- Issue #006 (Implement terminal core)
- Issue #010 (Implement buffer diffing)

## Implementation Notes
```zig
// Part of screen.zig — Rendering pipeline
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    pub const RenderStats = struct {
        frames_rendered: u64 = 0,
        cells_updated: u64 = 0,
        bytes_written: u64 = 0,
        render_time_ns: u64 = 0,
        diff_time_ns: u64 = 0,
        
        pub fn reset(self: *RenderStats) void {
            self.* = RenderStats{};
        }
    };

    pub const RenderOptions = struct {
        vsync: bool = false,
        target_fps: u16 = 60,
        force_redraw: bool = false,
        use_double_buffer: bool = true,
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    // Extension to Screen struct
    pub const Screen = struct {
        // ... existing fields ...
        render_stats: RenderStats,
        last_render_time: i64,
        render_buffer: std.ArrayList(u8),
        
        // ┌──────────────────────────── Main Render ────────────────────────────┐

            /// Render the screen to the terminal
            pub fn render(self: *Screen, terminal: *Terminal) !void {
                const start_time = std.time.nanoTimestamp();
                
                // Generate diff
                const diff_start = std.time.nanoTimestamp();
                var diff_result = try self.generateDiff(.{
                    .optimize_level = .balanced,
                });
                defer diff_result.deinit();
                self.render_stats.diff_time_ns = @intCast(u64, std.time.nanoTimestamp() - diff_start);
                
                // Apply diff operations
                try self.applyDiff(&diff_result, terminal);
                
                // Update statistics
                self.render_stats.frames_rendered += 1;
                self.render_stats.render_time_ns = @intCast(u64, std.time.nanoTimestamp() - start_time);
                self.last_render_time = std.time.nanoTimestamp();
                
                // Swap buffers
                self.present();
            }

            /// Force full redraw of the screen
            pub fn forceRedraw(self: *Screen, terminal: *Terminal) !void {
                try terminal.clear();
                
                // Render all non-empty cells
                var y: u16 = 0;
                while (y < self.height) : (y += 1) {
                    var x: u16 = 0;
                    while (x < self.width) : (x += 1) {
                        const cell = self.back_buffer[y * self.width + x];
                        if (!cell.isEmpty()) {
                            try self.renderCell(terminal, x, y, cell);
                        }
                    }
                }
                
                self.present();
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Diff Application ────────────────────────────┐

            fn applyDiff(self: *Screen, diff: *DiffResult, terminal: *Terminal) !void {
                // Clear render buffer
                self.render_buffer.clearRetainingCapacity();
                
                // Process each diff operation
                for (diff.ops.items) |op| {
                    switch (op) {
                        .set_cell => |cell_op| {
                            try self.bufferCellUpdate(cell_op.x, cell_op.y, cell_op.cell);
                        },
                        .set_span => |span_op| {
                            try self.bufferSpanUpdate(span_op.x, span_op.y, span_op.cells);
                        },
                        .copy_region => |copy_op| {
                            try self.bufferRegionCopy(copy_op);
                        },
                        .clear_region => |clear_op| {
                            try self.bufferRegionClear(clear_op);
                        },
                        .scroll => |scroll_op| {
                            try self.bufferScroll(scroll_op);
                        },
                    }
                }
                
                // Flush buffer to terminal
                if (self.render_buffer.items.len > 0) {
                    _ = try terminal.stdout.write(self.render_buffer.items);
                    self.render_stats.bytes_written += self.render_buffer.items.len;
                }
            }

            fn bufferCellUpdate(self: *Screen, x: u16, y: u16, cell: Cell) !void {
                // Move cursor if needed
                try self.bufferMoveTo(x, y);
                
                // Apply cell styling
                try self.bufferCellStyle(cell);
                
                // Write character
                switch (cell.content) {
                    .empty => try self.render_buffer.append(' '),
                    .ascii => |ch| try self.render_buffer.append(ch),
                    .utf8 => |bytes| {
                        for (bytes) |b| {
                            if (b == 0) break;
                            try self.render_buffer.append(b);
                        }
                    },
                    .wide => |ch| {
                        var buf: [4]u8 = undefined;
                        const len = try std.unicode.utf8Encode(@intCast(u21, ch), &buf);
                        try self.render_buffer.appendSlice(buf[0..len]);
                    },
                }
                
                self.render_stats.cells_updated += 1;
            }

            fn bufferSpanUpdate(self: *Screen, x: u16, y: u16, cells: []const Cell) !void {
                try self.bufferMoveTo(x, y);
                
                var current_style: ?struct { fg: Color, bg: Color, style: Style } = null;
                
                for (cells) |cell| {
                    // Only update style if it changed
                    const needs_style = if (current_style) |cur| 
                        !cur.fg.equals(cell.fg) or !cur.bg.equals(cell.bg) or cur.style != cell.style
                    else 
                        true;
                    
                    if (needs_style) {
                        try self.bufferCellStyle(cell);
                        current_style = .{
                            .fg = cell.fg,
                            .bg = cell.bg,
                            .style = cell.style,
                        };
                    }
                    
                    // Write character
                    switch (cell.content) {
                        .empty => try self.render_buffer.append(' '),
                        .ascii => |ch| try self.render_buffer.append(ch),
                        .utf8 => |bytes| {
                            for (bytes) |b| {
                                if (b == 0) break;
                                try self.render_buffer.append(b);
                            }
                        },
                        .wide => |ch| {
                            var buf: [4]u8 = undefined;
                            const len = try std.unicode.utf8Encode(@intCast(u21, ch), &buf);
                            try self.render_buffer.appendSlice(buf[0..len]);
                        },
                    }
                }
                
                self.render_stats.cells_updated += cells.len;
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── ANSI Generation ────────────────────────────┐

            fn bufferMoveTo(self: *Screen, x: u16, y: u16) !void {
                // Use optimal cursor movement
                // Track current cursor position to minimize moves
                var buf: [32]u8 = undefined;
                const seq = try std.fmt.bufPrint(&buf, ansi.CSI ++ "{};{}H", .{ y + 1, x + 1 });
                try self.render_buffer.appendSlice(seq);
            }

            fn bufferCellStyle(self: *Screen, cell: Cell) !void {
                // Reset if needed
                try self.render_buffer.appendSlice(ansi.RESET);
                
                // Apply styles
                if (cell.style.bold) {
                    try self.render_buffer.appendSlice(ansi.CSI ++ "1m");
                }
                if (cell.style.italic) {
                    try self.render_buffer.appendSlice(ansi.CSI ++ "3m");
                }
                if (cell.style.underline) {
                    try self.render_buffer.appendSlice(ansi.CSI ++ "4m");
                }
                
                // Apply colors
                try self.bufferColor(cell.fg, true);
                try self.bufferColor(cell.bg, false);
            }

            fn bufferColor(self: *Screen, color: Color, is_fg: bool) !void {
                var buf: [32]u8 = undefined;
                
                const seq = switch (color.type) {
                    .default => return,
                    .basic => try std.fmt.bufPrint(&buf, ansi.CSI ++ "{}{}m", 
                        .{ if (is_fg) @as(u8, 3) else @as(u8, 4), color.value }),
                    .indexed => try std.fmt.bufPrint(&buf, ansi.CSI ++ "{};5;{}m",
                        .{ if (is_fg) @as(u8, 38) else @as(u8, 48), color.value }),
                    .rgb => {
                        // For RGB, decode from packed value
                        const r = (color.value >> 5) * 36;
                        const g = ((color.value >> 2) & 0x7) * 36;
                        const b = (color.value & 0x3) * 85;
                        return try std.fmt.bufPrint(&buf, ansi.CSI ++ "{};2;{};{};{}m",
                            .{ if (is_fg) @as(u8, 38) else @as(u8, 48), r, g, b });
                    },
                };
                
                try self.render_buffer.appendSlice(seq);
            }

            fn bufferScroll(self: *Screen, scroll_op: anytype) !void {
                // Set scroll region if needed
                if (scroll_op.region.x != 0 or scroll_op.region.width != self.width) {
                    // Use DECSTBM for partial scrolling
                    var buf: [32]u8 = undefined;
                    const seq = try std.fmt.bufPrint(&buf, ansi.CSI ++ "{};{}r",
                        .{ scroll_op.region.y + 1, scroll_op.region.y + scroll_op.region.height });
                    try self.render_buffer.appendSlice(seq);
                }
                
                // Perform scroll
                if (scroll_op.lines > 0) {
                    // Scroll down
                    var i: u16 = 0;
                    while (i < scroll_op.lines) : (i += 1) {
                        try self.render_buffer.appendSlice(ansi.CSI ++ "S");
                    }
                } else {
                    // Scroll up
                    var i: u16 = 0;
                    while (i < -scroll_op.lines) : (i += 1) {
                        try self.render_buffer.appendSlice(ansi.CSI ++ "T");
                    }
                }
                
                // Reset scroll region
                try self.render_buffer.appendSlice(ansi.CSI ++ "r");
            }

        // └──────────────────────────────────────────────────────────────────┘

    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Test basic rendering
- Test diff application
- Test ANSI sequence generation
- Test cursor optimization
- Test style batching
- Test scroll operations
- Performance targets:
  - Full screen render: < 16ms
  - Incremental update: < 5ms
  - ANSI generation: < 1ms

## Estimated Time
3 hours

## Priority
🟡 High - Required for display

## Category
Screen Management