# Issue #012: Implement keyboard input

## Summary
Create a non-blocking keyboard input system that parses raw terminal input into structured key events.

## Description
Implement a keyboard input handler that reads from stdin in raw mode, parses ANSI escape sequences, and generates structured key events. The system should handle special keys, modifiers, and Unicode input while maintaining responsiveness.

## Acceptance Criteria
- [ ] Create `lib/event/utils/keyboard/keyboard.zig`
- [ ] Implement non-blocking input reading
- [ ] Parse single-byte ASCII keys
- [ ] Parse multi-byte escape sequences
- [ ] Handle special keys (arrows, function keys, etc.)
- [ ] Detect modifier keys (Ctrl, Alt, Shift)
- [ ] Support Unicode character input
- [ ] Handle paste mode detection
- [ ] Create key event structure
- [ ] Add input buffering for efficiency
- [ ] Follow MCS style guidelines

## Dependencies
- Issue #004 (Implement raw mode)

## Implementation Notes
```zig
// keyboard.zig — Keyboard input handling
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    const os = std.os;

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    pub const KeyCode = union(enum) {
        char: u21,           // Unicode character
        function: u8,        // F1-F12
        special: SpecialKey,
        
        pub const SpecialKey = enum {
            enter,
            tab,
            backspace,
            escape,
            space,
            delete,
            insert,
            home,
            end,
            page_up,
            page_down,
            arrow_up,
            arrow_down,
            arrow_left,
            arrow_right,
        };
    };

    pub const KeyModifiers = packed struct {
        ctrl: bool = false,
        alt: bool = false,
        shift: bool = false,
        meta: bool = false,
        
        pub fn none() KeyModifiers {
            return .{};
        }
        
        pub fn hasAny(self: KeyModifiers) bool {
            return self.ctrl or self.alt or self.shift or self.meta;
        }
    };

    pub const KeyEvent = struct {
        code: KeyCode,
        modifiers: KeyModifiers,
        timestamp: i64,
        
        pub fn isChar(self: KeyEvent, ch: u21) bool {
            return switch (self.code) {
                .char => |c| c == ch,
                else => false,
            };
        }
        
        pub fn isCtrl(self: KeyEvent, ch: u8) bool {
            return self.modifiers.ctrl and switch (self.code) {
                .char => |c| c == ch,
                else => false,
            };
        }
    };

    const ParseState = enum {
        normal,
        escape,
        csi,
        ss3,
        osc,
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    pub const KeyboardReader = struct {
        stdin: std.fs.File,
        buffer: [256]u8,
        buffer_len: usize,
        buffer_pos: usize,
        parse_state: ParseState,
        escape_buffer: [32]u8,
        escape_len: usize,
        
        // ┌──────────────────────────── Initialization ────────────────────────────┐

            pub fn init() KeyboardReader {
                return .{
                    .stdin = std.io.getStdIn(),
                    .buffer = undefined,
                    .buffer_len = 0,
                    .buffer_pos = 0,
                    .parse_state = .normal,
                    .escape_buffer = undefined,
                    .escape_len = 0,
                };
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Input Reading ────────────────────────────┐

            /// Read next key event (non-blocking)
            pub fn readKey(self: *KeyboardReader) !?KeyEvent {
                // Fill buffer if empty
                if (self.buffer_pos >= self.buffer_len) {
                    self.buffer_len = try self.readNonBlocking();
                    self.buffer_pos = 0;
                    
                    if (self.buffer_len == 0) {
                        return null; // No input available
                    }
                }
                
                // Parse next key from buffer
                return try self.parseNext();
            }

            /// Read multiple keys at once
            pub fn readKeys(self: *KeyboardReader, keys: []KeyEvent) !usize {
                var count: usize = 0;
                
                while (count < keys.len) {
                    const key = try self.readKey();
                    if (key == null) break;
                    
                    keys[count] = key.?;
                    count += 1;
                }
                
                return count;
            }

            fn readNonBlocking(self: *KeyboardReader) !usize {
                // Set non-blocking mode temporarily
                const flags = try os.fcntl(self.stdin.handle, os.F.GETFL, 0);
                _ = try os.fcntl(self.stdin.handle, os.F.SETFL, flags | os.O.NONBLOCK);
                defer _ = os.fcntl(self.stdin.handle, os.F.SETFL, flags) catch {};
                
                // Read available data
                return self.stdin.read(&self.buffer) catch |err| switch (err) {
                    error.WouldBlock => return 0,
                    else => return err,
                };
            }

        // └──────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────── Parsing ────────────────────────────┐

            fn parseNext(self: *KeyboardReader) !?KeyEvent {
                const timestamp = std.time.milliTimestamp();
                
                while (self.buffer_pos < self.buffer_len) {
                    const byte = self.buffer[self.buffer_pos];
                    self.buffer_pos += 1;
                    
                    switch (self.parse_state) {
                        .normal => {
                            // Check for escape sequence start
                            if (byte == 0x1B) {
                                self.parse_state = .escape;
                                self.escape_len = 0;
                                continue;
                            }
                            
                            // Parse as regular key
                            return try self.parseNormalKey(byte, timestamp);
                        },
                        
                        .escape => {
                            if (byte == '[') {
                                self.parse_state = .csi;
                            } else if (byte == 'O') {
                                self.parse_state = .ss3;
                            } else if (byte == ']') {
                                self.parse_state = .osc;
                            } else {
                                // Alt+key combination
                                self.parse_state = .normal;
                                return KeyEvent{
                                    .code = .{ .char = byte },
                                    .modifiers = .{ .alt = true },
                                    .timestamp = timestamp,
                                };
                            }
                        },
                        
                        .csi => {
                            self.escape_buffer[self.escape_len] = byte;
                            self.escape_len += 1;
                            
                            // Check if sequence is complete
                            if (byte >= 0x40 and byte <= 0x7E) {
                                const seq = self.escape_buffer[0..self.escape_len];
                                self.parse_state = .normal;
                                return try self.parseCSI(seq, timestamp);
                            }
                            
                            // Prevent buffer overflow
                            if (self.escape_len >= self.escape_buffer.len) {
                                self.parse_state = .normal;
                            }
                        },
                        
                        .ss3 => {
                            // Parse SS3 sequences (F1-F4 on some terminals)
                            self.parse_state = .normal;
                            return try self.parseSS3(byte, timestamp);
                        },
                        
                        .osc => {
                            // Skip OSC sequences (not key events)
                            if (byte == 0x07 or byte == '\\') {
                                self.parse_state = .normal;
                            }
                        },
                    }
                }
                
                return null;
            }

            fn parseNormalKey(self: *KeyboardReader, byte: u8, timestamp: i64) !KeyEvent {
                _ = self;
                
                // Control characters
                if (byte < 0x20) {
                    if (byte == 0x0D) { // Enter
                        return KeyEvent{
                            .code = .{ .special = .enter },
                            .modifiers = .{},
                            .timestamp = timestamp,
                        };
                    } else if (byte == 0x09) { // Tab
                        return KeyEvent{
                            .code = .{ .special = .tab },
                            .modifiers = .{},
                            .timestamp = timestamp,
                        };
                    } else if (byte == 0x08 or byte == 0x7F) { // Backspace
                        return KeyEvent{
                            .code = .{ .special = .backspace },
                            .modifiers = .{},
                            .timestamp = timestamp,
                        };
                    } else if (byte == 0x1B) { // Escape
                        return KeyEvent{
                            .code = .{ .special = .escape },
                            .modifiers = .{},
                            .timestamp = timestamp,
                        };
                    } else {
                        // Ctrl+letter
                        return KeyEvent{
                            .code = .{ .char = byte + 0x60 }, // Convert to letter
                            .modifiers = .{ .ctrl = true },
                            .timestamp = timestamp,
                        };
                    }
                }
                
                // Regular ASCII
                if (byte < 0x80) {
                    return KeyEvent{
                        .code = .{ .char = byte },
                        .modifiers = .{},
                        .timestamp = timestamp,
                    };
                }
                
                // UTF-8 handling
                return try self.parseUTF8(byte, timestamp);
            }

            fn parseCSI(self: *KeyboardReader, seq: []const u8, timestamp: i64) !KeyEvent {
                _ = self;
                
                // Parse arrow keys
                if (seq.len == 1) {
                    return switch (seq[0]) {
                        'A' => KeyEvent{ .code = .{ .special = .arrow_up }, .modifiers = .{}, .timestamp = timestamp },
                        'B' => KeyEvent{ .code = .{ .special = .arrow_down }, .modifiers = .{}, .timestamp = timestamp },
                        'C' => KeyEvent{ .code = .{ .special = .arrow_right }, .modifiers = .{}, .timestamp = timestamp },
                        'D' => KeyEvent{ .code = .{ .special = .arrow_left }, .modifiers = .{}, .timestamp = timestamp },
                        'H' => KeyEvent{ .code = .{ .special = .home }, .modifiers = .{}, .timestamp = timestamp },
                        'F' => KeyEvent{ .code = .{ .special = .end }, .modifiers = .{}, .timestamp = timestamp },
                        else => KeyEvent{ .code = .{ .char = '?' }, .modifiers = .{}, .timestamp = timestamp },
                    };
                }
                
                // Parse modified arrow keys (e.g., "1;5A" for Ctrl+Up)
                if (seq.len >= 3 and seq[0] == '1' and seq[1] == ';') {
                    const modifier_code = seq[2] - '1';
                    const key_code = seq[seq.len - 1];
                    
                    var modifiers = KeyModifiers{};
                    if (modifier_code & 1 != 0) modifiers.shift = true;
                    if (modifier_code & 2 != 0) modifiers.alt = true;
                    if (modifier_code & 4 != 0) modifiers.ctrl = true;
                    
                    const special = switch (key_code) {
                        'A' => KeyCode.SpecialKey.arrow_up,
                        'B' => KeyCode.SpecialKey.arrow_down,
                        'C' => KeyCode.SpecialKey.arrow_right,
                        'D' => KeyCode.SpecialKey.arrow_left,
                        else => return KeyEvent{ .code = .{ .char = '?' }, .modifiers = .{}, .timestamp = timestamp },
                    };
                    
                    return KeyEvent{
                        .code = .{ .special = special },
                        .modifiers = modifiers,
                        .timestamp = timestamp,
                    };
                }
                
                // Parse function keys and other special keys
                if (seq[seq.len - 1] == '~') {
                    const num_end = std.mem.indexOfScalar(u8, seq, '~') orelse seq.len - 1;
                    const num = std.fmt.parseInt(u8, seq[0..num_end], 10) catch return KeyEvent{
                        .code = .{ .char = '?' },
                        .modifiers = .{},
                        .timestamp = timestamp,
                    };
                    
                    return switch (num) {
                        1, 7 => KeyEvent{ .code = .{ .special = .home }, .modifiers = .{}, .timestamp = timestamp },
                        2 => KeyEvent{ .code = .{ .special = .insert }, .modifiers = .{}, .timestamp = timestamp },
                        3 => KeyEvent{ .code = .{ .special = .delete }, .modifiers = .{}, .timestamp = timestamp },
                        4, 8 => KeyEvent{ .code = .{ .special = .end }, .modifiers = .{}, .timestamp = timestamp },
                        5 => KeyEvent{ .code = .{ .special = .page_up }, .modifiers = .{}, .timestamp = timestamp },
                        6 => KeyEvent{ .code = .{ .special = .page_down }, .modifiers = .{}, .timestamp = timestamp },
                        11...22 => KeyEvent{ .code = .{ .function = num - 10 }, .modifiers = .{}, .timestamp = timestamp },
                        else => KeyEvent{ .code = .{ .char = '?' }, .modifiers = .{}, .timestamp = timestamp },
                    };
                }
                
                return KeyEvent{
                    .code = .{ .char = '?' },
                    .modifiers = .{},
                    .timestamp = timestamp,
                };
            }

            fn parseSS3(self: *KeyboardReader, byte: u8, timestamp: i64) !KeyEvent {
                _ = self;
                
                // F1-F4 keys on some terminals
                return switch (byte) {
                    'P' => KeyEvent{ .code = .{ .function = 1 }, .modifiers = .{}, .timestamp = timestamp },
                    'Q' => KeyEvent{ .code = .{ .function = 2 }, .modifiers = .{}, .timestamp = timestamp },
                    'R' => KeyEvent{ .code = .{ .function = 3 }, .modifiers = .{}, .timestamp = timestamp },
                    'S' => KeyEvent{ .code = .{ .function = 4 }, .modifiers = .{}, .timestamp = timestamp },
                    else => KeyEvent{ .code = .{ .char = '?' }, .modifiers = .{}, .timestamp = timestamp },
                };
            }

            fn parseUTF8(self: *KeyboardReader, first_byte: u8, timestamp: i64) !KeyEvent {
                // Determine UTF-8 sequence length
                const len = std.unicode.utf8ByteSequenceLength(first_byte) catch return KeyEvent{
                    .code = .{ .char = '?' },
                    .modifiers = .{},
                    .timestamp = timestamp,
                };
                
                if (len == 1) {
                    return KeyEvent{
                        .code = .{ .char = first_byte },
                        .modifiers = .{},
                        .timestamp = timestamp,
                    };
                }
                
                // Read remaining bytes
                var utf8_buf: [4]u8 = undefined;
                utf8_buf[0] = first_byte;
                
                var i: usize = 1;
                while (i < len and self.buffer_pos < self.buffer_len) : (i += 1) {
                    utf8_buf[i] = self.buffer[self.buffer_pos];
                    self.buffer_pos += 1;
                }
                
                // Decode UTF-8
                const ch = std.unicode.utf8Decode(utf8_buf[0..len]) catch return KeyEvent{
                    .code = .{ .char = '?' },
                    .modifiers = .{},
                    .timestamp = timestamp,
                };
                
                return KeyEvent{
                    .code = .{ .char = ch },
                    .modifiers = .{},
                    .timestamp = timestamp,
                };
            }

        // └──────────────────────────────────────────────────────────────────┘

    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Testing Requirements
- Test ASCII key detection
- Test special key parsing
- Test modifier combinations
- Test escape sequence parsing
- Test Unicode input
- Test non-blocking behavior
- Test buffer management
- Performance: < 100μs per key parse

## Estimated Time
4 hours

## Priority
🟡 High - Required for interactivity

## Category
Event System