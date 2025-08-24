// keyboard.zig — Keyboard input handling and key mapping
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══ PACK ══╗

    const std = @import("std");

// ╚══════════╝

// ╔══ CORE ══╗

    /// Key codes
    pub const KeyCode = union(enum) {
        char: u21,          // Unicode character
        function: u8,       // F1-F12
        enter,
        escape,
        backspace,
        tab,
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
        
        /// Parse key code from string
        pub fn from_name(name: []const u8) ?KeyCode {
            if (std.mem.eql(u8, name, "enter")) return .enter;
            if (std.mem.eql(u8, name, "escape")) return .escape;
            if (std.mem.eql(u8, name, "backspace")) return .backspace;
            if (std.mem.eql(u8, name, "tab")) return .tab;
            if (std.mem.eql(u8, name, "space")) return .space;
            if (std.mem.eql(u8, name, "delete")) return .delete;
            if (std.mem.eql(u8, name, "insert")) return .insert;
            if (std.mem.eql(u8, name, "home")) return .home;
            if (std.mem.eql(u8, name, "end")) return .end;
            if (std.mem.eql(u8, name, "page_up")) return .page_up;
            if (std.mem.eql(u8, name, "page_down")) return .page_down;
            if (std.mem.eql(u8, name, "up")) return .arrow_up;
            if (std.mem.eql(u8, name, "down")) return .arrow_down;
            if (std.mem.eql(u8, name, "left")) return .arrow_left;
            if (std.mem.eql(u8, name, "right")) return .arrow_right;
            
            // Check for function keys
            if (name.len == 2 and name[0] == 'f') {
                const num = name[1] - '0';
                if (num >= 1 and num <= 9) {
                    return KeyCode{ .function = num };
                }
            } else if (name.len == 3 and name[0] == 'f' and name[1] == '1') {
                const num = 10 + (name[2] - '0');
                if (num >= 10 and num <= 12) {
                    return KeyCode{ .function = num };
                }
            }
            
            return null;
        }
    };
    
    /// Key modifiers
    pub const Modifiers = packed struct {
        ctrl: bool = false,
        alt: bool = false,
        shift: bool = false,
        meta: bool = false,
        
        /// Check if no modifiers are pressed
        pub fn none(self: Modifiers) bool {
            return !self.ctrl and !self.alt and !self.shift and !self.meta;
        }
        
        /// Check if only ctrl is pressed
        pub fn only_ctrl(self: Modifiers) bool {
            return self.ctrl and !self.alt and !self.shift and !self.meta;
        }
        
        /// Check if only alt is pressed
        pub fn only_alt(self: Modifiers) bool {
            return !self.ctrl and self.alt and !self.shift and !self.meta;
        }
        
        /// Check if only shift is pressed
        pub fn only_shift(self: Modifiers) bool {
            return !self.ctrl and !self.alt and self.shift and !self.meta;
        }
    };
    
    /// Key event
    pub const KeyEvent = struct {
        code: KeyCode,
        modifiers: Modifiers,
        
        /// Create key event
        pub fn new(code: KeyCode, modifiers: Modifiers) KeyEvent {
            return KeyEvent{
                .code = code,
                .modifiers = modifiers,
            };
        }
        
        /// Create key event with character
        pub fn char(c: u21) KeyEvent {
            return KeyEvent{
                .code = KeyCode{ .char = c },
                .modifiers = Modifiers{},
            };
        }
        
        /// Create key event with ctrl modifier
        pub fn ctrl(code: KeyCode) KeyEvent {
            return KeyEvent{
                .code = code,
                .modifiers = Modifiers{ .ctrl = true },
            };
        }
        
        /// Create key event with alt modifier
        pub fn alt(code: KeyCode) KeyEvent {
            return KeyEvent{
                .code = code,
                .modifiers = Modifiers{ .alt = true },
            };
        }
        
        /// Check if key matches
        pub fn matches(self: KeyEvent, other: KeyEvent) bool {
            const codes_match = switch (self.code) {
                .char => |c1| switch (other.code) {
                    .char => |c2| c1 == c2,
                    else => false,
                },
                .function => |f1| switch (other.code) {
                    .function => |f2| f1 == f2,
                    else => false,
                },
                else => |tag1| switch (other.code) {
                    else => |tag2| tag1 == tag2,
                },
            };
            
            return codes_match and 
                   @as(u4, @bitCast(self.modifiers)) == @as(u4, @bitCast(other.modifiers));
        }
    };
    
    /// Key sequence parser
    pub const KeyParser = struct {
        buffer: [32]u8,
        pos: usize,
        
        /// Initialize parser
        pub fn init() KeyParser {
            return KeyParser{
                .buffer = undefined,
                .pos = 0,
            };
        }
        
        /// Reset parser
        pub fn reset(self: *KeyParser) void {
            self.pos = 0;
        }
        
        /// Feed byte to parser
        pub fn feed(self: *KeyParser, byte: u8) void {
            if (self.pos < self.buffer.len) {
                self.buffer[self.pos] = byte;
                self.pos += 1;
            }
        }
        
        /// Try to parse key event
        pub fn parse(self: *KeyParser) ?KeyEvent {
            if (self.pos == 0) return null;
            
            // ESC sequences
            if (self.buffer[0] == 0x1B) {
                if (self.pos == 1) {
                    // Just ESC
                    self.reset();
                    return KeyEvent.char(0x1B);
                }
                
                // Parse escape sequence
                return self.parse_escape_sequence();
            }
            
            // Control characters
            if (self.buffer[0] < 0x20) {
                const result = self.parse_control_char(self.buffer[0]);
                self.reset();
                return result;
            }
            
            // Regular ASCII character
            if (self.buffer[0] < 0x80) {
                const result = KeyEvent.char(self.buffer[0]);
                self.reset();
                return result;
            }
            
            // UTF-8 sequence
            return self.parse_utf8();
        }
        
        fn parse_escape_sequence(self: *KeyParser) ?KeyEvent {
            if (self.pos < 3) return null;
            
            // CSI sequences
            if (self.buffer[1] == '[') {
                return self.parse_csi_sequence();
            }
            
            // Alt + key
            if (self.pos == 2) {
                const key = KeyEvent.char(self.buffer[1]);
                var result = key;
                result.modifiers.alt = true;
                self.reset();
                return result;
            }
            
            return null;
        }
        
        fn parse_csi_sequence(self: *KeyParser) ?KeyEvent {
            // Simple arrow keys
            if (self.pos == 3) {
                const result = switch (self.buffer[2]) {
                    'A' => KeyEvent.new(.arrow_up, Modifiers{}),
                    'B' => KeyEvent.new(.arrow_down, Modifiers{}),
                    'C' => KeyEvent.new(.arrow_right, Modifiers{}),
                    'D' => KeyEvent.new(.arrow_left, Modifiers{}),
                    'H' => KeyEvent.new(.home, Modifiers{}),
                    'F' => KeyEvent.new(.end, Modifiers{}),
                    else => null,
                };
                
                if (result) |r| {
                    self.reset();
                    return r;
                }
            }
            
            // Extended sequences (placeholder)
            // Would need more complex parsing for modified keys, mouse events, etc.
            
            return null;
        }
        
        fn parse_control_char(_: *KeyParser, byte: u8) KeyEvent {
            return switch (byte) {
                0x00 => KeyEvent.ctrl(KeyCode{ .char = ' ' }),  // Ctrl+Space
                0x01...0x1A => blk: {  // Ctrl+A through Ctrl+Z
                    const c = byte + 'a' - 1;
                    break :blk KeyEvent.ctrl(KeyCode{ .char = c });
                },
                0x08, 0x7F => KeyEvent.new(.backspace, Modifiers{}),
                0x09 => KeyEvent.new(.tab, Modifiers{}),
                0x0A, 0x0D => KeyEvent.new(.enter, Modifiers{}),
                0x1B => KeyEvent.new(.escape, Modifiers{}),
                else => KeyEvent.char(byte),
            };
        }
        
        fn parse_utf8(self: *KeyParser) ?KeyEvent {
            // Determine UTF-8 sequence length
            const len = if ((self.buffer[0] & 0xE0) == 0xC0)
                2
            else if ((self.buffer[0] & 0xF0) == 0xE0)
                3
            else if ((self.buffer[0] & 0xF8) == 0xF0)
                4
            else
                1;
            
            if (self.pos < len) return null;
            
            // Decode UTF-8
            var codepoint: u21 = undefined;
            
            if (len == 1) {
                codepoint = self.buffer[0];
            } else if (len == 2) {
                codepoint = (@as(u21, self.buffer[0] & 0x1F) << 6) |
                           (@as(u21, self.buffer[1] & 0x3F));
            } else if (len == 3) {
                codepoint = (@as(u21, self.buffer[0] & 0x0F) << 12) |
                           (@as(u21, self.buffer[1] & 0x3F) << 6) |
                           (@as(u21, self.buffer[2] & 0x3F));
            } else {
                codepoint = (@as(u21, self.buffer[0] & 0x07) << 18) |
                           (@as(u21, self.buffer[1] & 0x3F) << 12) |
                           (@as(u21, self.buffer[2] & 0x3F) << 6) |
                           (@as(u21, self.buffer[3] & 0x3F));
            }
            
            self.reset();
            return KeyEvent.char(codepoint);
        }
    };

// ╚══════════╝