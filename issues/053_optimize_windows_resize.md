<!--------------------------------- SUMMARY --------------------------------->  

# Issue #053: Optimize Windows resize detection for efficiency

Replace the current CPU-intensive polling approach for Windows console resize detection with an event-driven mechanism to improve performance and reduce system resource usage.

<!--------------------------------------------------------------------------->  

<!-------------------------------- DESCRIPTION -------------------------------->  

Issue #007 implemented comprehensive terminal resize detection, but the Windows implementation uses a polling thread that continuously checks for console buffer size changes. This approach, while functional, consumes unnecessary CPU cycles and system resources. Windows provides event-driven mechanisms that would be more efficient.

<!--------------------------------------------------------------------------->  

<!---------------------------- CURRENT PROBLEM ------------------------------>

## Current Implementation Problem

<!--------------------------------------------------------------------------->  

<!--------------------------- ACCEPTANCE CRITERIA --------------------------->  

## Acceptance Criteria
```zig
// Current polling approach in terminal.zig
fn monitorWindowsResize(self: *Terminal) void {
    while (self.resize_monitoring) {
        const current_size = self.querySizeSystem() catch continue;
        if (!current_size.eql(self.size)) {
            self.handleResize(current_size);
        }
        std.time.sleep(100 * std.time.ns_per_ms); // 100ms polling interval
    }
}
```

**Problems:**
- CPU usage even when no resize occurs
- 100ms delay between resize and detection
- Unnecessary wake-ups and system calls
- Poor battery life impact on laptops

## Acceptance Criteria
- [ ] Replace polling thread with event-driven approach
- [ ] Use Windows Console API events (INPUT_RECORD with WINDOW_BUFFER_SIZE_EVENT)
- [ ] Maintain existing resize callback API compatibility
- [ ] Reduce CPU usage to near-zero when no resize occurs
- [ ] Improve resize detection latency (< 10ms vs current 100ms)
- [ ] Add proper error handling for Windows API calls
- [ ] Maintain thread safety for resize event handling
- [ ] Add configuration option to fall back to polling if needed
- [ ] Follow MCS style guidelines
- [ ] Performance: < 1% CPU usage during idle periods

## Dependencies
- Issue #007 (Add terminal size detection) - COMPLETED (provides base implementation)

## Implementation Notes
```zig
// terminal.zig optimization — Event-driven Windows resize detection
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    pub const WindowsResizeMode = enum {
        event_driven,  // Use console events (recommended)
        polling,       // Fall back to polling if events fail
        hybrid,        // Try events, fall back to polling
    };

    pub const WindowsResizeConfig = struct {
        mode: WindowsResizeMode = .hybrid,
        polling_interval_ms: u32 = 100,
        event_timeout_ms: u32 = 1000,
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    // Windows-specific implementation
    fn monitorWindowsResizeEvents(self: *Terminal, config: WindowsResizeConfig) void {
        const stdin_handle = std.io.getStdIn().handle;
        
        // Try event-driven approach first
        if (config.mode == .event_driven or config.mode == .hybrid) {
            if (self.tryEventDrivenResize(stdin_handle, config)) {
                return; // Success with event-driven approach
            }
            
            if (config.mode == .event_driven) {
                std.log.warn("Event-driven resize failed, resize monitoring disabled");
                return;
            }
        }
        
        // Fall back to polling approach
        std.log.info("Using polling approach for Windows resize detection");
        self.monitorWindowsResizePolling(config.polling_interval_ms);
    }

    /// Event-driven Windows resize monitoring
    fn tryEventDrivenResize(self: *Terminal, stdin_handle: windows.HANDLE, config: WindowsResizeConfig) bool {
        // Set console mode to enable window input events
        var mode: windows.DWORD = undefined;
        if (windows.GetConsoleMode(stdin_handle, &mode) == 0) {
            return false;
        }
        
        const new_mode = mode | windows.ENABLE_WINDOW_INPUT;
        if (windows.SetConsoleMode(stdin_handle, new_mode) == 0) {
            return false;
        }
        defer _ = windows.SetConsoleMode(stdin_handle, mode); // Restore on exit
        
        // Event monitoring loop
        var input_buffer: [1]windows.INPUT_RECORD = undefined;
        var events_read: windows.DWORD = undefined;
        
        while (self.resize_monitoring) {
            // Wait for console events with timeout
            const wait_result = windows.WaitForSingleObject(stdin_handle, config.event_timeout_ms);
            
            switch (wait_result) {
                windows.WAIT_OBJECT_0 => {
                    // Events available, read them
                    if (windows.ReadConsoleInputW(stdin_handle, &input_buffer, 1, &events_read) == 0) {
                        continue;
                    }
                    
                    if (events_read > 0 and input_buffer[0].EventType == windows.WINDOW_BUFFER_SIZE_EVENT) {
                        const size_event = input_buffer[0].Event.WindowBufferSizeEvent;
                        const new_size = Size{
                            .cols = @intCast(u16, size_event.dwSize.X),
                            .rows = @intCast(u16, size_event.dwSize.Y),
                        };
                        
                        self.handleResize(new_size);
                    }
                },
                windows.WAIT_TIMEOUT => {
                    // Timeout - check if we should continue monitoring
                    continue;
                },
                else => {
                    // Error occurred
                    std.log.warn("Windows console event wait failed");
                    return false;
                },
            }
        }
        
        return true;
    }

    /// Fallback polling implementation (optimized)
    fn monitorWindowsResizePolling(self: *Terminal, interval_ms: u32) void {
        var last_size = self.size;
        const sleep_ns = interval_ms * std.time.ns_per_ms;
        
        while (self.resize_monitoring) {
            const current_size = self.querySizeSystem() catch {
                std.time.sleep(sleep_ns);
                continue;
            };
            
            if (current_size != null and !current_size.?.eql(last_size)) {
                self.handleResize(current_size.?);
                last_size = current_size.?;
            }
            
            std.time.sleep(sleep_ns);
        }
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝
```

## Windows API Research
**Key Windows APIs to use:**
- `SetConsoleMode()` with `ENABLE_WINDOW_INPUT` flag
- `WaitForSingleObject()` for event waiting
- `ReadConsoleInputW()` to read console input records
- `INPUT_RECORD.WINDOW_BUFFER_SIZE_EVENT` for resize events

**Benefits:**
- Near-zero CPU usage when idle
- Immediate resize detection (< 10ms latency)
- Better integration with Windows event system
- Reduced power consumption

## Testing Requirements
- Test event-driven approach on various Windows versions
- Test fallback to polling when events are not available
- Verify CPU usage reduction (should be < 1% during idle)
- Test resize detection latency (should be < 10ms)
- Test compatibility with different console hosts (cmd, PowerShell, Windows Terminal)
- Stress test with rapid resize operations
- Test error handling for Windows API failures

## Estimated Time
2 hours

## Priority
🟡 High - Performance optimization that improves user experience

## Category
Platform Optimization

## Added
2025-08-24 - Identified during session review after Issue #007 completion

## Notes
This optimization is particularly important for:
- Battery life on laptops
- System responsiveness during heavy TUI usage
- Better integration with Windows event system
- Professional-grade performance expectations

The hybrid approach ensures backward compatibility while providing optimal performance when possible.