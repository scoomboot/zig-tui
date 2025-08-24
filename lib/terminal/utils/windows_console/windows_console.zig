// windows_console.zig — Windows Console API bindings for event-driven operations
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://fisty.github.io/zig-tui/terminal/windows_console
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔════════════════════════════════════ PACK ════════════════════════════════════╗

    const std = @import("std");
    const windows = std.os.windows;

// ╚════════════════════════════════════════════════════════════════════════════════╝

// ╔════════════════════════════════════ INIT ════════════════════════════════════╗

    /// Console mode flags for input handling
    pub const ConsoleMode = struct {
        /// Enable window input events in console
        pub const ENABLE_WINDOW_INPUT: windows.DWORD = 0x0008;
        
        /// Enable mouse input events
        pub const ENABLE_MOUSE_INPUT: windows.DWORD = 0x0010;
        
        /// Enable processed input (Ctrl+C, etc.)
        pub const ENABLE_PROCESSED_INPUT: windows.DWORD = 0x0001;
        
        /// Enable line input mode
        pub const ENABLE_LINE_INPUT: windows.DWORD = 0x0002;
        
        /// Enable echo input mode
        pub const ENABLE_ECHO_INPUT: windows.DWORD = 0x0004;
        
        /// Enable extended flags
        pub const ENABLE_EXTENDED_FLAGS: windows.DWORD = 0x0080;
        
        /// Enable quick edit mode
        pub const ENABLE_QUICK_EDIT_MODE: windows.DWORD = 0x0040;
    };

    /// Event types for console input records
    pub const EventType = enum(windows.WORD) {
        KEY_EVENT = 0x0001,
        MOUSE_EVENT = 0x0002,
        WINDOW_BUFFER_SIZE_EVENT = 0x0004,
        MENU_EVENT = 0x0008,
        FOCUS_EVENT = 0x0010,
    };

    /// Coordinate structure for console positions
    pub const COORD = extern struct {
        X: windows.SHORT,
        Y: windows.SHORT,
        
        /// Create a new coordinate.
        ///
        /// __Parameters__
        ///
        /// - `x`: X coordinate (column)
        /// - `y`: Y coordinate (row)
        ///
        /// __Return__
        ///
        /// - `COORD`: New coordinate instance
        pub fn init(x: i16, y: i16) COORD {
            return COORD{ .X = x, .Y = y };
        }
    };

    /// Window buffer size event structure
    pub const WINDOW_BUFFER_SIZE_RECORD = extern struct {
        dwSize: COORD,
        
        /// Get the width of the buffer.
        ///
        /// __Parameters__
        ///
        /// - `self`: Window buffer size record
        ///
        /// __Return__
        ///
        /// - `u16`: Buffer width in columns
        pub fn getWidth(self: WINDOW_BUFFER_SIZE_RECORD) u16 {
            return @intCast(self.dwSize.X);
        }
        
        /// Get the height of the buffer.
        ///
        /// __Parameters__
        ///
        /// - `self`: Window buffer size record
        ///
        /// __Return__
        ///
        /// - `u16`: Buffer height in rows
        pub fn getHeight(self: WINDOW_BUFFER_SIZE_RECORD) u16 {
            return @intCast(self.dwSize.Y);
        }
    };

    /// Key event record structure
    pub const KEY_EVENT_RECORD = extern struct {
        bKeyDown: windows.BOOL,
        wRepeatCount: windows.WORD,
        wVirtualKeyCode: windows.WORD,
        wVirtualScanCode: windows.WORD,
        uChar: extern union {
            UnicodeChar: windows.WCHAR,
            AsciiChar: windows.CHAR,
        },
        dwControlKeyState: windows.DWORD,
    };

    /// Mouse event record structure
    pub const MOUSE_EVENT_RECORD = extern struct {
        dwMousePosition: COORD,
        dwButtonState: windows.DWORD,
        dwControlKeyState: windows.DWORD,
        dwEventFlags: windows.DWORD,
    };

    /// Menu event record structure
    pub const MENU_EVENT_RECORD = extern struct {
        dwCommandId: windows.UINT,
    };

    /// Focus event record structure
    pub const FOCUS_EVENT_RECORD = extern struct {
        bSetFocus: windows.BOOL,
    };

    /// Event union for all event types
    pub const EventUnion = extern union {
        KeyEvent: KEY_EVENT_RECORD,
        MouseEvent: MOUSE_EVENT_RECORD,
        WindowBufferSizeEvent: WINDOW_BUFFER_SIZE_RECORD,
        MenuEvent: MENU_EVENT_RECORD,
        FocusEvent: FOCUS_EVENT_RECORD,
    };

    /// Input record structure for console events
    pub const INPUT_RECORD = extern struct {
        EventType: windows.WORD,
        _padding: windows.WORD = 0,
        Event: EventUnion,
        
        /// Check if this is a window resize event.
        ///
        /// __Parameters__
        ///
        /// - `self`: Input record to check
        ///
        /// __Return__
        ///
        /// - `bool`: True if this is a window buffer size event
        pub fn isResizeEvent(self: INPUT_RECORD) bool {
            return self.EventType == @intFromEnum(EventType.WINDOW_BUFFER_SIZE_EVENT);
        }
        
        /// Get the new size from a resize event.
        ///
        /// __Parameters__
        ///
        /// - `self`: Input record containing resize event
        ///
        /// __Return__
        ///
        /// - `?COORD`: New size if this is a resize event, null otherwise
        pub fn getResizeSize(self: INPUT_RECORD) ?COORD {
            if (self.isResizeEvent()) {
                return self.Event.WindowBufferSizeEvent.dwSize;
            }
            return null;
        }
    };

// ╚════════════════════════════════════════════════════════════════════════════════╝

// ╔════════════════════════════════════ CORE ════════════════════════════════════╗

    /// Windows Console API functions for event-driven operations
    pub const Console = struct {
        
        // ┌──────────────────────────── External Functions ────────────────────────────┐
        
            /// Read console input events
            pub extern "kernel32" fn ReadConsoleInputW(
                hConsoleInput: windows.HANDLE,
                lpBuffer: [*]INPUT_RECORD,
                nLength: windows.DWORD,
                lpNumberOfEventsRead: *windows.DWORD,
            ) callconv(windows.WINAPI) windows.BOOL;
            
            /// Peek at console input events without removing them
            pub extern "kernel32" fn PeekConsoleInputW(
                hConsoleInput: windows.HANDLE,
                lpBuffer: [*]INPUT_RECORD,
                nLength: windows.DWORD,
                lpNumberOfEventsRead: *windows.DWORD,
            ) callconv(windows.WINAPI) windows.BOOL;
            
            /// Get number of console input events
            pub extern "kernel32" fn GetNumberOfConsoleInputEvents(
                hConsoleInput: windows.HANDLE,
                lpNumberOfEvents: *windows.DWORD,
            ) callconv(windows.WINAPI) windows.BOOL;
            
            /// Flush console input buffer
            pub extern "kernel32" fn FlushConsoleInputBuffer(
                hConsoleInput: windows.HANDLE,
            ) callconv(windows.WINAPI) windows.BOOL;
            
        // └──────────────────────────────────────────────────────────────────────┘
        
        // ┌──────────────────────────── Helper Functions ────────────────────────────┐
        
            /// Enable window input events for a console handle.
            ///
            /// Modifies the console mode to enable window buffer size events,
            /// preserving other mode flags. Returns the original mode for restoration.
            ///
            /// __Parameters__
            ///
            /// - `handle`: Console input handle
            ///
            /// __Return__
            ///
            /// - `windows.DWORD`: Original console mode (for restoration)
            /// - `error`: If getting or setting console mode fails
            pub fn enableWindowInput(handle: windows.HANDLE) !windows.DWORD {
                var original_mode: windows.DWORD = undefined;
                
                // Get current console mode
                if (windows.kernel32.GetConsoleMode(handle, &original_mode) == 0) {
                    return error.GetConsoleModeFailed;
                }
                
                // Enable window input events
                const new_mode = original_mode | ConsoleMode.ENABLE_WINDOW_INPUT;
                if (windows.kernel32.SetConsoleMode(handle, new_mode) == 0) {
                    return error.SetConsoleModeFailed;
                }
                
                return original_mode;
            }
            
            /// Restore console mode to a previous state.
            ///
            /// __Parameters__
            ///
            /// - `handle`: Console input handle
            /// - `mode`: Console mode to restore
            ///
            /// __Return__
            ///
            /// - `void`: Success
            /// - `error`: If setting console mode fails
            pub fn restoreConsoleMode(handle: windows.HANDLE, mode: windows.DWORD) !void {
                if (windows.kernel32.SetConsoleMode(handle, mode) == 0) {
                    return error.SetConsoleModeFailed;
                }
            }
            
            /// Wait for console input with timeout.
            ///
            /// Uses WaitForSingleObject to wait for console input events
            /// with a specified timeout in milliseconds.
            ///
            /// __Parameters__
            ///
            /// - `handle`: Console input handle
            /// - `timeout_ms`: Timeout in milliseconds (use INFINITE for no timeout)
            ///
            /// __Return__
            ///
            /// - `bool`: True if input is available, false on timeout
            /// - `error`: If wait operation fails
            pub fn waitForInput(handle: windows.HANDLE, timeout_ms: windows.DWORD) !bool {
                const result = windows.kernel32.WaitForSingleObject(handle, timeout_ms);
                
                switch (result) {
                    windows.WAIT_OBJECT_0 => return true,
                    windows.WAIT_TIMEOUT => return false,
                    windows.WAIT_FAILED => return error.WaitFailed,
                    else => return error.UnexpectedWaitResult,
                }
            }
            
            /// Read and filter resize events from console input.
            ///
            /// Reads console input events and filters for window buffer size events,
            /// discarding other event types. Non-blocking if no events are available.
            ///
            /// __Parameters__
            ///
            /// - `handle`: Console input handle
            ///
            /// __Return__
            ///
            /// - `?COORD`: New buffer size if resize event found, null otherwise
            /// - `error`: If reading console input fails
            pub fn readResizeEvent(handle: windows.HANDLE) !?COORD {
                var buffer: [16]INPUT_RECORD = undefined;
                var events_read: windows.DWORD = 0;
                
                // Check if events are available
                var event_count: windows.DWORD = 0;
                if (GetNumberOfConsoleInputEvents(handle, &event_count) == 0) {
                    return error.GetEventCountFailed;
                }
                
                if (event_count == 0) {
                    return null;
                }
                
                // Read available events
                const read_count = @min(event_count, buffer.len);
                if (ReadConsoleInputW(handle, &buffer, read_count, &events_read) == 0) {
                    return error.ReadConsoleInputFailed;
                }
                
                // Search for resize events
                for (buffer[0..events_read]) |event| {
                    if (event.isResizeEvent()) {
                        return event.getResizeSize();
                    }
                }
                
                return null;
            }
            
            /// Clear all pending console input events.
            ///
            /// __Parameters__
            ///
            /// - `handle`: Console input handle
            ///
            /// __Return__
            ///
            /// - `void`: Success
            /// - `error`: If flush operation fails
            pub fn clearInputBuffer(handle: windows.HANDLE) !void {
                if (FlushConsoleInputBuffer(handle) == 0) {
                    return error.FlushBufferFailed;
                }
            }
            
        // └──────────────────────────────────────────────────────────────────────┘
        
    };

// ╚════════════════════════════════════════════════════════════════════════════════╝