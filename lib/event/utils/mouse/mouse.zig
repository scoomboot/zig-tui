// mouse.zig — Mouse input handling and event processing
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

    /// Mouse button
    pub const MouseButton = enum {
        left,
        middle,
        right,
        scroll_up,
        scroll_down,
        button_4,
        button_5,
        none,
    };
    
    /// Mouse event type
    pub const MouseEventType = enum {
        press,
        release,
        drag,
        move,
        scroll,
    };
    
    /// Mouse event
    pub const MouseEvent = struct {
        type: MouseEventType,
        button: MouseButton,
        x: u16,
        y: u16,
        modifiers: MouseModifiers,
        
        /// Create mouse event
        pub fn new(event_type: MouseEventType, button: MouseButton, x: u16, y: u16) MouseEvent {
            return MouseEvent{
                .type = event_type,
                .button = button,
                .x = x,
                .y = y,
                .modifiers = MouseModifiers{},
            };
        }
        
        /// Create click event
        pub fn click(button: MouseButton, x: u16, y: u16) MouseEvent {
            return new(.press, button, x, y);
        }
        
        /// Create move event
        pub fn move(x: u16, y: u16) MouseEvent {
            return new(.move, .none, x, y);
        }
        
        /// Create scroll event
        pub fn scroll(direction: MouseButton, x: u16, y: u16) MouseEvent {
            return new(.scroll, direction, x, y);
        }
        
        /// Check if event is at position
        pub fn at(self: MouseEvent, px: u16, py: u16) bool {
            return self.x == px and self.y == py;
        }
        
        /// Check if event is within bounds
        pub fn in_bounds(self: MouseEvent, x: u16, y: u16, width: u16, height: u16) bool {
            return self.x >= x and self.x < x + width and
                   self.y >= y and self.y < y + height;
        }
    };
    
    /// Mouse modifiers
    pub const MouseModifiers = packed struct {
        shift: bool = false,
        ctrl: bool = false,
        alt: bool = false,
        
        /// Check if no modifiers
        pub fn none(self: MouseModifiers) bool {
            return !self.shift and !self.ctrl and !self.alt;
        }
    };
    
    /// Mouse tracking mode
    pub const MouseMode = enum {
        disabled,
        basic,          // Button events only
        drag,           // Button events + drag
        movement,       // All mouse movement
    };
    
    /// Mouse parser for terminal sequences
    pub const MouseParser = struct {
        mode: MouseMode,
        buffer: [32]u8,
        pos: usize,
        
        /// Initialize parser
        pub fn init(mode: MouseMode) MouseParser {
            return MouseParser{
                .mode = mode,
                .buffer = undefined,
                .pos = 0,
            };
        }
        
        /// Reset parser
        pub fn reset(self: *MouseParser) void {
            self.pos = 0;
        }
        
        /// Set mouse mode
        pub fn set_mode(self: *MouseParser, mode: MouseMode) void {
            self.mode = mode;
        }
        
        /// Feed byte to parser
        pub fn feed(self: *MouseParser, byte: u8) void {
            if (self.pos < self.buffer.len) {
                self.buffer[self.pos] = byte;
                self.pos += 1;
            }
        }
        
        /// Parse mouse event from buffer
        pub fn parse(self: *MouseParser) ?MouseEvent {
            if (self.mode == .disabled) return null;
            if (self.pos < 6) return null;
            
            // Check for mouse sequence start (CSI M)
            if (self.buffer[0] != 0x1B or 
                self.buffer[1] != '[' or 
                self.buffer[2] != 'M') {
                return null;
            }
            
            // X10 mouse protocol (simplest)
            if (self.pos >= 6) {
                return self.parse_x10();
            }
            
            return null;
        }
        
        fn parse_x10(self: *MouseParser) ?MouseEvent {
            const button_byte = self.buffer[3];
            const x = self.buffer[4] - 32;  // Terminal adds 32 to coordinates
            const y = self.buffer[5] - 32;
            
            // Parse button and modifiers
            const button_code = button_byte & 0x03;
            const modifiers = MouseModifiers{
                .shift = (button_byte & 0x04) != 0,
                .alt = (button_byte & 0x08) != 0,
                .ctrl = (button_byte & 0x10) != 0,
            };
            
            // Determine button
            const button = switch (button_code) {
                0 => MouseButton.left,
                1 => MouseButton.middle,
                2 => MouseButton.right,
                3 => MouseButton.none,  // Release
                else => MouseButton.none,
            };
            
            // Determine event type
            const event_type = if (button_code == 3)
                MouseEventType.release
            else if ((button_byte & 0x20) != 0)
                MouseEventType.drag
            else if ((button_byte & 0x40) != 0)
                MouseEventType.scroll
            else
                MouseEventType.press;
            
            self.reset();
            
            return MouseEvent{
                .type = event_type,
                .button = button,
                .x = x,
                .y = y,
                .modifiers = modifiers,
            };
        }
        
        /// Parse SGR mouse protocol (more advanced)
        pub fn parse_sgr(self: *MouseParser) ?MouseEvent {
            // SGR protocol: CSI < button ; x ; y M/m
            // This is a placeholder for more advanced mouse support
            _ = self;
            return null;
        }
    };
    
    /// Mouse state tracker
    pub const MouseState = struct {
        position: struct { x: u16, y: u16 },
        buttons: MouseButtons,
        last_click_time: i64,
        last_click_pos: struct { x: u16, y: u16 },
        double_click_threshold: i64,  // milliseconds
        
        /// Button states
        pub const MouseButtons = packed struct {
            left: bool = false,
            middle: bool = false,
            right: bool = false,
        };
        
        /// Initialize mouse state
        pub fn init() MouseState {
            return MouseState{
                .position = .{ .x = 0, .y = 0 },
                .buttons = MouseButtons{},
                .last_click_time = 0,
                .last_click_pos = .{ .x = 0, .y = 0 },
                .double_click_threshold = 500,  // 500ms default
            };
        }
        
        /// Update state with event
        pub fn update(self: *MouseState, event: MouseEvent) void {
            self.position.x = event.x;
            self.position.y = event.y;
            
            switch (event.type) {
                .press => {
                    switch (event.button) {
                        .left => self.buttons.left = true,
                        .middle => self.buttons.middle = true,
                        .right => self.buttons.right = true,
                        else => {},
                    }
                },
                .release => {
                    switch (event.button) {
                        .left => self.buttons.left = false,
                        .middle => self.buttons.middle = false,
                        .right => self.buttons.right = false,
                        else => {},
                    }
                },
                else => {},
            }
        }
        
        /// Check for double click
        pub fn is_double_click(self: *MouseState, event: MouseEvent, current_time: i64) bool {
            if (event.type != .press) return false;
            
            const time_diff = current_time - self.last_click_time;
            const same_pos = self.last_click_pos.x == event.x and 
                           self.last_click_pos.y == event.y;
            
            const is_double = time_diff <= self.double_click_threshold and same_pos;
            
            // Update last click info
            self.last_click_time = current_time;
            self.last_click_pos.x = event.x;
            self.last_click_pos.y = event.y;
            
            return is_double;
        }
    };

// ╚══════════╝