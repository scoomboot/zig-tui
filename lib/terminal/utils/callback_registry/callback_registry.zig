// callback_registry.zig — Thread-safe registry for terminal-screen callback associations
//
// repo   : https://github.com/fisty/zig-tui
// docs   : https://github.com/fisty/zig-tui/docs
// author : https://github.com/fisty
//
// Vibe coded by Fisty.

// ╔══════════════════════════════════════ PACK ══════════════════════════════════════╗

    const std = @import("std");
    
// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ INIT ══════════════════════════════════════╗

    /// Registry errors that can occur during callback operations.
    pub const RegistryError = error{
        AllocationFailed,
        EntryNotFound,
        DuplicateEntry,
        InvalidPointer,
        MutexLockFailed,
    };

    /// Entry in the callback registry.
    ///
    /// Each entry represents a registered association between a terminal,
    /// its screen(s), and a unique identifier for safe reference management.
    pub const Entry = struct {
        /// Unique identifier for this registry entry
        id: u64,
        
        /// Pointer to the terminal instance (using anytype for now to avoid circular deps)
        terminal: *anyopaque,
        
        /// Pointer to the associated screen instance (using anytype for now to avoid circular deps)
        screen: *anyopaque,
        
        /// Timestamp of registration (for debugging and cleanup)
        registered_at: i64,
        
        /// Check if entry matches a given terminal pointer.
        ///
        /// __Parameters__
        ///
        /// - `self`: Entry instance to check
        /// - `terminal`: Terminal pointer to match against
        ///
        /// __Return__
        ///
        /// - `bool`: True if terminal pointers match, false otherwise
        pub inline fn matchesTerminal(self: Entry, terminal: *anyopaque) bool {
            return self.terminal == terminal;
        }
        
        /// Check if entry matches a given screen pointer.
        ///
        /// __Parameters__
        ///
        /// - `self`: Entry instance to check
        /// - `screen`: Screen pointer to match against
        ///
        /// __Return__
        ///
        /// - `bool`: True if screen pointers match, false otherwise
        pub inline fn matchesScreen(self: Entry, screen: *anyopaque) bool {
            return self.screen == screen;
        }
        
        /// Check if entry matches a given ID.
        ///
        /// __Parameters__
        ///
        /// - `self`: Entry instance to check
        /// - `id`: Unique ID to match against
        ///
        /// __Return__
        ///
        /// - `bool`: True if IDs match, false otherwise
        pub inline fn matchesId(self: Entry, id: u64) bool {
            return self.id == id;
        }
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

    /// Thread-safe callback registry for terminal-screen associations.
    ///
    /// This registry provides a centralized, thread-safe mechanism for managing
    /// associations between terminal instances and their corresponding screens.
    /// It enables proper resize callback handling by maintaining a lookup table
    /// that maps terminals to screens, allowing resize events to be properly
    /// dispatched to the correct screen instances.
    ///
    /// The registry uses mutex protection for thread safety and supports
    /// multiple screens per terminal for future multi-screen scenarios.
    pub const CallbackRegistry = struct {
        /// Memory allocator for dynamic allocations
        allocator: std.mem.Allocator,
        
        /// List of registered entries
        entries: std.ArrayList(Entry),
        
        /// Mutex for thread-safe access
        mutex: std.Thread.Mutex,
        
        /// Counter for generating unique IDs
        next_id: u64,
        
        /// Statistics for monitoring registry health
        stats: struct {
            total_registered: u64,
            total_unregistered: u64,
            current_entries: u64,
            resize_events_handled: u64,
        },
        
        /// Initialize a new callback registry.
        ///
        /// Creates a new registry instance with the specified allocator.
        /// The registry starts empty and must be populated through register calls.
        ///
        /// __Parameters__
        ///
        /// - `allocator`: Memory allocator for internal data structures
        ///
        /// __Return__
        ///
        /// - `CallbackRegistry`: Initialized registry instance
        pub fn init(allocator: std.mem.Allocator) CallbackRegistry {
            return CallbackRegistry{
                .allocator = allocator,
                .entries = std.ArrayList(Entry).init(allocator),
                .mutex = .{},
                .next_id = 1,
                .stats = .{
                    .total_registered = 0,
                    .total_unregistered = 0,
                    .current_entries = 0,
                    .resize_events_handled = 0,
                },
            };
        }
        
        /// Deinitialize the registry and free resources.
        ///
        /// Cleans up all internal resources and invalidates the registry.
        /// After calling deinit, the registry should not be used.
        ///
        /// __Parameters__
        ///
        /// - `self`: Registry instance to deinitialize
        pub fn deinit(self: *CallbackRegistry) void {
            // Lock mutex for safe cleanup
            self.mutex.lock();
            defer self.mutex.unlock();
            
            // Free the entries list
            self.entries.deinit();
            
            // Reset statistics for safety
            self.stats = .{
                .total_registered = 0,
                .total_unregistered = 0,
                .current_entries = 0,
                .resize_events_handled = 0,
            };
        }
        
        /// Register a terminal-screen association.
        ///
        /// Adds a new entry to the registry linking a terminal with its screen.
        /// Returns a unique ID that can be used to unregister the association later.
        ///
        /// __Parameters__
        ///
        /// - `self`: Registry instance
        /// - `terminal`: Terminal instance to register (as anyopaque pointer)
        /// - `screen`: Screen instance to associate with the terminal (as anyopaque pointer)
        ///
        /// __Return__
        ///
        /// - `u64`: Unique ID for this registration
        /// - `RegistryError`: If registration fails
        pub fn register(self: *CallbackRegistry, terminal: *anyopaque, screen: *anyopaque) !u64 {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            // Check for duplicate entries (same terminal-screen pair)
            // Performance note: O(n) scan is acceptable for small n (typically < 10)
            for (self.entries.items) |entry| {
                if (entry.terminal == terminal and entry.screen == screen) {
                    return RegistryError.DuplicateEntry;
                }
            }
            
            // Generate unique ID
            const id = self.next_id;
            self.next_id += 1;
            
            // Create new entry
            const entry = Entry{
                .id = id,
                .terminal = terminal,
                .screen = screen,
                .registered_at = std.time.timestamp(),
            };
            
            // Add to registry
            try self.entries.append(entry);
            
            // Update statistics
            self.stats.total_registered += 1;
            self.stats.current_entries += 1;
            
            return id;
        }
        
        /// Unregister an association by ID.
        ///
        /// Removes the entry with the specified ID from the registry.
        /// This should be called when a screen is destroyed or detached from its terminal.
        ///
        /// __Parameters__
        ///
        /// - `self`: Registry instance
        /// - `id`: Unique ID of the registration to remove
        ///
        /// __Return__
        ///
        /// - `void`: On successful unregistration
        /// - `RegistryError.EntryNotFound`: If no entry with the given ID exists
        pub fn unregister(self: *CallbackRegistry, id: u64) !void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            // Find and remove entry
            // Performance note: O(n) removal is acceptable for small n
            var index: ?usize = null;
            for (self.entries.items, 0..) |entry, i| {
                if (entry.id == id) {
                    index = i;
                    break;
                }
            }
            
            if (index) |idx| {
                _ = self.entries.swapRemove(idx);
                
                // Update statistics
                self.stats.total_unregistered += 1;
                self.stats.current_entries -= 1;
            } else {
                return RegistryError.EntryNotFound;
            }
        }
        
        /// Handle resize event for a terminal.
        ///
        /// Finds all screens associated with the given terminal and calls their
        /// handleResize method with the resize event information. This version
        /// imports the Screen type internally to avoid circular dependencies.
        ///
        /// __Parameters__
        ///
        /// - `self`: Registry instance
        /// - `terminal`: Terminal that received the resize event (as anyopaque pointer)
        /// - `new_cols`: New column count
        /// - `new_rows`: New row count
        ///
        /// __Return__
        ///
        /// - `void`: Resize handled for all associated screens
        pub fn handleResize(self: *CallbackRegistry, terminal: *anyopaque, new_cols: u16, new_rows: u16) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            // Import Screen type locally to avoid circular dependency at module level
            const Screen = @import("../../../screen/screen.zig").Screen;
            
            // Find all screens for this terminal and handle resize
            // Performance note: Linear scan is optimal for cache locality with small n
            for (self.entries.items) |entry| {
                if (entry.terminal == terminal) {
                    // Cast back to proper screen type and call resize handler
                    // Using catch to handle potential resize errors gracefully
                    const screen = @as(*Screen, @ptrCast(@alignCast(entry.screen)));
                    screen.handleResize(new_cols, new_rows, .preserve_content) catch {
                        // Log error if needed, but don't propagate
                        // This ensures one screen's resize failure doesn't affect others
                        continue;
                    };
                }
            }
            
            // Update statistics
            self.stats.resize_events_handled += 1;
        }
        
        /// Handle resize event with explicit type parameter (type-safe version).
        ///
        /// This version allows callers to specify the screen type explicitly,
        /// providing compile-time type safety when the type is known.
        ///
        /// __Parameters__
        ///
        /// - `self`: Registry instance
        /// - `terminal`: Terminal that received the resize event (as anyopaque pointer)
        /// - `new_cols`: New column count
        /// - `new_rows`: New row count
        /// - `comptime ScreenType`: Type of the screen (for proper casting)
        ///
        /// __Return__
        ///
        /// - `void`: Resize handled for all associated screens
        pub fn handleResizeTyped(self: *CallbackRegistry, terminal: *anyopaque, new_cols: u16, new_rows: u16, comptime ScreenType: type) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            // Find all screens for this terminal and handle resize
            // Performance note: Linear scan is optimal for cache locality with small n
            for (self.entries.items) |entry| {
                if (entry.terminal == terminal) {
                    // Cast back to proper screen type and call resize handler
                    // Using catch to handle potential resize errors gracefully
                    const screen = @as(*ScreenType, @ptrCast(@alignCast(entry.screen)));
                    screen.handleResize(new_cols, new_rows, .preserve_content) catch {
                        // Log error if needed, but don't propagate
                        // This ensures one screen's resize failure doesn't affect others
                        continue;
                    };
                }
            }
            
            // Update statistics
            self.stats.resize_events_handled += 1;
        }
        
        /// Find all entries associated with a terminal.
        ///
        /// Returns a slice of entries that are registered for the given terminal.
        /// The returned slice is valid until the next mutation of the registry.
        ///
        /// __Parameters__
        ///
        /// - `self`: Registry instance
        /// - `terminal`: Terminal to find entries for (as anyopaque pointer)
        ///
        /// __Return__
        ///
        /// - `[]Entry`: Slice of matching entries (may be empty)
        pub fn findEntriesByTerminal(self: *CallbackRegistry, terminal: *anyopaque) []Entry {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            // Count matching entries first for efficient allocation
            var count: usize = 0;
            for (self.entries.items) |entry| {
                if (entry.terminal == terminal) {
                    count += 1;
                }
            }
            
            // Return empty slice if no matches
            if (count == 0) {
                return &[_]Entry{};
            }
            
            // Allocate temporary buffer for results
            // Note: Caller should not hold this reference across registry mutations
            var results = self.allocator.alloc(Entry, count) catch {
                return &[_]Entry{};
            };
            
            // Fill results array
            var index: usize = 0;
            for (self.entries.items) |entry| {
                if (entry.terminal == terminal) {
                    results[index] = entry;
                    index += 1;
                }
            }
            
            return results;
        }
        
        /// Get current registry statistics.
        ///
        /// Returns a copy of the current statistics for monitoring and debugging.
        ///
        /// __Parameters__
        ///
        /// - `self`: Registry instance
        ///
        /// __Return__
        ///
        /// - Statistics struct with current registry metrics
        pub fn getStats(self: *CallbackRegistry) @TypeOf(self.stats) {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            return self.stats;
        }
        
        /// Clear all entries from the registry.
        ///
        /// Removes all registered associations while maintaining the registry structure.
        /// This is useful for cleanup scenarios or testing.
        ///
        /// __Parameters__
        ///
        /// - `self`: Registry instance to clear
        pub fn clear(self: *CallbackRegistry) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            
            // Clear all entries
            self.entries.clearRetainingCapacity();
            
            // Update statistics
            self.stats.current_entries = 0;
        }
    };

// ╚══════════════════════════════════════════════════════════════════════════════════════╝

// ╔══════════════════════════════════════ SINGLETON ═════════════════════════════════════╗

    // Global singleton instance for the callback registry
    // This ensures all parts of the application use the same registry
    var global_registry: ?CallbackRegistry = null;
    var global_registry_mutex: std.Thread.Mutex = .{};
    
    /// Get or create the global callback registry singleton.
    ///
    /// This function ensures thread-safe access to a single global registry instance.
    /// The registry is lazily initialized on first access.
    ///
    /// __Parameters__
    ///
    /// - `allocator`: Allocator to use for registry initialization (only used on first call)
    ///
    /// __Return__
    ///
    /// - `*CallbackRegistry`: Pointer to the global registry instance
    pub fn getGlobalRegistry(allocator: std.mem.Allocator) *CallbackRegistry {
        global_registry_mutex.lock();
        defer global_registry_mutex.unlock();
        
        if (global_registry == null) {
            global_registry = CallbackRegistry.init(allocator);
        }
        
        return &global_registry.?;
    }
    
    /// Destroy the global registry singleton.
    ///
    /// This should be called during application shutdown to properly clean up resources.
    pub fn deinitGlobalRegistry() void {
        global_registry_mutex.lock();
        defer global_registry_mutex.unlock();
        
        if (global_registry) |*registry| {
            registry.deinit();
            global_registry = null;
        }
    }

// ╚══════════════════════════════════════════════════════════════════════════════════════╝