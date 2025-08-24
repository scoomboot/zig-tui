# Issue #015: Implement key mapping

## Summary
Create a configurable key mapping system for translating raw key events into application actions.

## Description
Implement a flexible key mapping system that allows applications to define custom key bindings, support key chords (multi-key sequences), and handle context-specific mappings. The system should support vim-style mappings, emacs-style key sequences, and custom shortcuts.

## Acceptance Criteria
- [ ] Create key mapping registry
- [ ] Support single key mappings
- [ ] Support key chord sequences
- [ ] Implement context-aware mappings
- [ ] Add mapping conflict detection
- [ ] Support mapping descriptions
- [ ] Implement default mapping sets
- [ ] Add mapping import/export
- [ ] Create mapping validation
- [ ] Follow MCS style guidelines

## Dependencies
- Issue #012 (Implement keyboard input)

## Implementation Notes
```zig
// key_mapping.zig — Configurable key mapping system
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const KeyEvent = @import("keyboard.zig").KeyEvent;
    const KeyCode = @import("keyboard.zig").KeyCode;
    const KeyModifiers = @import("keyboard.zig").KeyModifiers;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    pub const Action = struct {
        id: []const u8,
        description: []const u8,
        category: []const u8,
        callback: ?*const fn (context: *anyopaque) void,
    };

    pub const KeySequence = struct {
        keys: []const KeyEvent,
        
        pub fn fromString(str: []const u8, allocator: std.mem.Allocator) !KeySequence {
            // Parse string like "Ctrl+X Ctrl+S" or "<C-x><C-s>"
            var keys = std.ArrayList(KeyEvent).init(allocator);
            defer keys.deinit();
            
            // Parsing implementation
            _ = str;
            
            return KeySequence{
                .keys = try keys.toOwnedSlice(),
            };
        }
        
        pub fn toString(self: KeySequence, allocator: std.mem.Allocator) ![]u8 {
            var buf = std.ArrayList(u8).init(allocator);
            
            for (self.keys, 0..) |key, i| {
                if (i > 0) try buf.append(' ');
                try self.appendKeyString(&buf, key);
            }
            
            return buf.toOwnedSlice();
        }
        
        fn appendKeyString(self: KeySequence, buf: *std.ArrayList(u8), key: KeyEvent) !void {
            _ = self;
            
            if (key.modifiers.ctrl) try buf.appendSlice("Ctrl+");
            if (key.modifiers.alt) try buf.appendSlice("Alt+");
            if (key.modifiers.shift) try buf.appendSlice("Shift+");
            if (key.modifiers.meta) try buf.appendSlice("Meta+");
            
            switch (key.code) {
                .char => |ch| {
                    var char_buf: [4]u8 = undefined;
                    const len = try std.unicode.utf8Encode(ch, &char_buf);
                    try buf.appendSlice(char_buf[0..len]);
                },
                .function => |f| {
                    try buf.writer().print("F{}", .{f});
                },
                .special => |s| {
                    const name = switch (s) {
                        .enter => "Enter",
                        .tab => "Tab",
                        .backspace => "Backspace",
                        .escape => "Escape",
                        .space => "Space",
                        .delete => "Delete",
                        .insert => "Insert",
                        .home => "Home",
                        .end => "End",
                        .page_up => "PageUp",
                        .page_down => "PageDown",
                        .arrow_up => "Up",
                        .arrow_down => "Down",
                        .arrow_left => "Left",
                        .arrow_right => "Right",
                    };
                    try buf.appendSlice(name);
                },
            }
        }
    };

    pub const MappingContext = struct {
        name: []const u8,
        parent: ?*MappingContext,
        active: bool,
    };

    pub const MappingMode = enum {
        normal,
        insert,
        visual,
        command,
        custom,
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    pub const KeyMapper = struct {
        allocator: std.mem.Allocator,
        mappings: std.ArrayList(Mapping),
        contexts: std.StringHashMap(*MappingContext),
        current_context: ?*MappingContext,
        sequence_buffer: std.ArrayList(KeyEvent),
        sequence_timeout_ms: u64,
        last_key_time: i64,
        mode: MappingMode,
        
        const Mapping = struct {
            sequence: KeySequence,
            action: Action,
            context: ?*MappingContext,
            mode: MappingMode,
            enabled: bool,
        };

        // ┌──────────────────────────── Initialization ────────────────────────────┐

            pub fn init(allocator: std.mem.Allocator) !KeyMapper {
                var mapper = KeyMapper{
                    .allocator = allocator,
                    .mappings = std.ArrayList(Mapping).init(allocator),
                    .contexts = std.StringHashMap(*MappingContext).init(allocator),
                    .current_context = null,
                    .sequence_buffer = std.ArrayList(KeyEvent).init(allocator),
                    .sequence_timeout_ms = 1000, // 1 second timeout for sequences
                    .last_key_time = 0,
                    .mode = .normal,
                };
                
                // Load default mappings
                try mapper.loadDefaults();
                
                return mapper;
            }

            pub fn deinit(self: *KeyMapper) void {
                self.mappings.deinit();
                
                var iter = self.contexts.iterator();
                while (iter.next()) |entry| {
                    self.allocator.destroy(entry.value_ptr.*);
                }
                self.contexts.deinit();
                
                self.sequence_buffer.deinit();
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Mapping Management ────────────────────────────┐

            /// Add a key mapping
            pub fn map(
                self: *KeyMapper,
                sequence_str: []const u8,
                action: Action,
                mode: MappingMode,
            ) !void {
                const sequence = try KeySequence.fromString(sequence_str, self.allocator);
                
                // Check for conflicts
                if (self.hasConflict(sequence, mode)) {
                    return error.MappingConflict;
                }
                
                try self.mappings.append(.{
                    .sequence = sequence,
                    .action = action,
                    .context = self.current_context,
                    .mode = mode,
                    .enabled = true,
                });
            }

            /// Remove a key mapping
            pub fn unmap(self: *KeyMapper, sequence_str: []const u8, mode: MappingMode) !void {
                const sequence = try KeySequence.fromString(sequence_str, self.allocator);
                
                var i: usize = 0;
                while (i < self.mappings.items.len) {
                    const mapping = self.mappings.items[i];
                    if (mapping.mode == mode and self.sequenceEquals(mapping.sequence, sequence)) {
                        _ = self.mappings.swapRemove(i);
                        return;
                    }
                    i += 1;
                }
                
                return error.MappingNotFound;
            }

            /// Check for mapping conflicts
            fn hasConflict(self: *KeyMapper, sequence: KeySequence, mode: MappingMode) bool {
                for (self.mappings.items) |mapping| {
                    if (mapping.mode != mode) continue;
                    if (!mapping.enabled) continue;
                    
                    // Check for exact match or prefix conflict
                    if (self.sequenceEquals(mapping.sequence, sequence)) {
                        return true;
                    }
                    
                    // Check if one is prefix of another
                    if (self.isPrefix(mapping.sequence, sequence) or
                        self.isPrefix(sequence, mapping.sequence)) {
                        return true;
                    }
                }
                
                return false;
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Key Processing ────────────────────────────┐

            /// Process a key event and return action if matched
            pub fn processKey(self: *KeyMapper, key: KeyEvent) !?Action {
                const now = std.time.milliTimestamp();
                
                // Check for sequence timeout
                if (self.sequence_buffer.items.len > 0) {
                    if (now - self.last_key_time > self.sequence_timeout_ms) {
                        self.sequence_buffer.clearRetainingCapacity();
                    }
                }
                
                // Add key to sequence buffer
                try self.sequence_buffer.append(key);
                self.last_key_time = now;
                
                // Try to match mapping
                const result = self.findMapping();
                
                switch (result) {
                    .exact_match => |action| {
                        self.sequence_buffer.clearRetainingCapacity();
                        return action;
                    },
                    .partial_match => {
                        // Keep buffering
                        return null;
                    },
                    .no_match => {
                        // Clear buffer and try single key
                        if (self.sequence_buffer.items.len > 1) {
                            self.sequence_buffer.clearRetainingCapacity();
                            try self.sequence_buffer.append(key);
                            
                            const retry_result = self.findMapping();
                            if (retry_result == .exact_match) {
                                self.sequence_buffer.clearRetainingCapacity();
                                return retry_result.exact_match;
                            }
                        }
                        
                        self.sequence_buffer.clearRetainingCapacity();
                        return null;
                    },
                }
            }

            const MatchResult = union(enum) {
                exact_match: Action,
                partial_match: void,
                no_match: void,
            };

            fn findMapping(self: *KeyMapper) MatchResult {
                var has_partial = false;
                
                for (self.mappings.items) |mapping| {
                    // Check mode
                    if (mapping.mode != self.mode and mapping.mode != .custom) {
                        continue;
                    }
                    
                    // Check context
                    if (mapping.context != null and mapping.context != self.current_context) {
                        continue;
                    }
                    
                    if (!mapping.enabled) continue;
                    
                    // Check sequence
                    if (self.sequenceStartsWith(mapping.sequence, self.sequence_buffer.items)) {
                        if (mapping.sequence.keys.len == self.sequence_buffer.items.len) {
                            return .{ .exact_match = mapping.action };
                        } else {
                            has_partial = true;
                        }
                    }
                }
                
                return if (has_partial) .partial_match else .no_match;
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Context Management ────────────────────────────┐

            /// Create a new mapping context
            pub fn createContext(self: *KeyMapper, name: []const u8, parent: ?*MappingContext) !*MappingContext {
                const context = try self.allocator.create(MappingContext);
                context.* = .{
                    .name = name,
                    .parent = parent,
                    .active = false,
                };
                
                try self.contexts.put(name, context);
                return context;
            }

            /// Activate a context
            pub fn activateContext(self: *KeyMapper, name: []const u8) !void {
                if (self.contexts.get(name)) |context| {
                    self.current_context = context;
                    context.active = true;
                } else {
                    return error.ContextNotFound;
                }
            }

            /// Deactivate current context
            pub fn deactivateContext(self: *KeyMapper) void {
                if (self.current_context) |context| {
                    context.active = false;
                    self.current_context = context.parent;
                }
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Default Mappings ────────────────────────────┐

            fn loadDefaults(self: *KeyMapper) !void {
                // Common navigation
                try self.map("h", Action{
                    .id = "move_left",
                    .description = "Move cursor left",
                    .category = "navigation",
                    .callback = null,
                }, .normal);
                
                try self.map("j", Action{
                    .id = "move_down",
                    .description = "Move cursor down",
                    .category = "navigation",
                    .callback = null,
                }, .normal);
                
                try self.map("k", Action{
                    .id = "move_up",
                    .description = "Move cursor up",
                    .category = "navigation",
                    .callback = null,
                }, .normal);
                
                try self.map("l", Action{
                    .id = "move_right",
                    .description = "Move cursor right",
                    .category = "navigation",
                    .callback = null,
                }, .normal);
                
                // Mode switching
                try self.map("i", Action{
                    .id = "enter_insert",
                    .description = "Enter insert mode",
                    .category = "mode",
                    .callback = null,
                }, .normal);
                
                try self.map("Escape", Action{
                    .id = "enter_normal",
                    .description = "Enter normal mode",
                    .category = "mode",
                    .callback = null,
                }, .insert);
                
                // File operations
                try self.map("Ctrl+S", Action{
                    .id = "save",
                    .description = "Save file",
                    .category = "file",
                    .callback = null,
                }, .custom);
                
                try self.map("Ctrl+Q", Action{
                    .id = "quit",
                    .description = "Quit application",
                    .category = "application",
                    .callback = null,
                }, .custom);
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Helper Functions ────────────────────────────┐

            fn sequenceEquals(self: *KeyMapper, a: KeySequence, b: KeySequence) bool {
                _ = self;
                
                if (a.keys.len != b.keys.len) return false;
                
                for (a.keys, b.keys) |key_a, key_b| {
                    if (!keyEquals(key_a, key_b)) return false;
                }
                
                return true;
            }

            fn sequenceStartsWith(self: *KeyMapper, sequence: KeySequence, prefix: []const KeyEvent) bool {
                _ = self;
                
                if (prefix.len > sequence.keys.len) return false;
                
                for (prefix, 0..) |key, i| {
                    if (!keyEquals(key, sequence.keys[i])) return false;
                }
                
                return true;
            }

            fn isPrefix(self: *KeyMapper, a: KeySequence, b: KeySequence) bool {
                _ = self;
                
                if (a.keys.len >= b.keys.len) return false;
                
                for (a.keys, 0..) |key, i| {
                    if (!keyEquals(key, b.keys[i])) return false;
                }
                
                return true;
            }

            fn keyEquals(a: KeyEvent, b: KeyEvent) bool {
                if (@bitCast(u8, a.modifiers) != @bitCast(u8, b.modifiers)) return false;
                
                return switch (a.code) {
                    .char => |ch_a| switch (b.code) {
                        .char => |ch_b| ch_a == ch_b,
                        else => false,
                    },
                    .function => |f_a| switch (b.code) {
                        .function => |f_b| f_a == f_b,
                        else => false,
                    },
                    .special => |s_a| switch (b.code) {
                        .special => |s_b| s_a == s_b,
                        else => false,
                    },
                };
            }

        // └──────────────────────────────────────────────────────────────────┘

    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Test single key mappings
- Test key sequence mappings
- Test conflict detection
- Test context switching
- Test mode-specific mappings
- Test timeout behavior
- Test mapping precedence
- Performance: < 100μs per key lookup

## Estimated Time
2 hours

## Priority
🟡 High - Essential for usability

## Category
Event System