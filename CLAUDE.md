# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the library and executable
zig build

# Run unit tests for both library and executable
zig build test

# Run the application
zig build run

# Build with specific optimization level
zig build -Doptimize=ReleaseFast
zig build -Doptimize=ReleaseSmall
zig build -Doptimize=ReleaseSafe
zig build -Doptimize=Debug

# Run a specific test file
zig test lib/tui.test.zig
zig test lib/terminal/terminal.test.zig
zig test lib/screen/screen.test.zig
zig test lib/event/event.test.zig
```

## Architecture Overview

This is a Zig TUI (Terminal User Interface) library that provides comprehensive terminal control capabilities. The library is organized into modular components with clear separation of concerns.

### Core Components

1. **Terminal Module** (`lib/terminal/`)
   - Manages terminal state and raw mode operations
   - Provides ANSI escape sequence handling via `utils/ansi/`
   - Controls terminal input/output modes via `utils/raw_mode/`

2. **Screen Module** (`lib/screen/`)
   - Handles screen buffer management and rendering
   - Cell-based drawing system via `utils/cell/`
   - Rectangle/region management via `utils/rect/`
   - Implements efficient buffer diffing for optimized rendering

3. **Event Module** (`lib/event/`)
   - Event loop and event queue management
   - Keyboard input handling via `utils/keyboard/`
   - Mouse input handling via `utils/mouse/`
   - Event dispatcher and handler system

4. **Widget Module** (`lib/widget/`)
   - Base widget framework for UI components
   - Component lifecycle management

5. **Layout Module** (`lib/layout/`)
   - Layout management and constraint solving
   - Container and positioning system

### Code Style

The project follows the Maysara Code Style (MCS) defined in `docs/MCS.md`, which emphasizes:
- Visual code organization with section demarcation boxes
- Comprehensive inline documentation
- Performance-optimized implementations with clear comments
- Test files alongside implementation files (`.test.zig` pattern)

### Testing Strategy

Each module has corresponding test files following the naming convention `{module}.test.zig`. Tests are categorized as:
- `unit`: Individual function tests
- `integration`: Component interaction tests
- `e2e`: Full workflow tests
- `scenario`: Real-world usage tests
- `performance`: Benchmark tests

Reference `docs/TESTING_CONVENTIONS.md` for detailed testing guidelines.

### Entry Points

- **Library**: `lib/tui.zig` - Main library interface exporting all public APIs
- **Executable**: `src/main.zig` - Example application using the library (imports as `zig_tui_lib`)

### Key Design Patterns

1. **Modular Architecture**: Each component is self-contained with its own utilities
2. **Performance Focus**: Inline functions, packed structs, and optimized algorithms throughout
3. **Error Handling**: Comprehensive error types and proper error propagation
4. **Memory Safety**: Careful allocator usage and lifetime management