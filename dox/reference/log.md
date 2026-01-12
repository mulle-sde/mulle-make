# mulle-make log - Show Build Log

## Quick Start
Display the build log from the last build operation.

## All Available Options

### Basic Usage
```bash
mulle-make log [options] [arguments]
```

**Arguments:**
- `arguments`: Arguments passed to log display command

### Visible Options
- `--help`: Show usage information
- `--verbose`: Enable verbose output
- `--quiet`: Suppress output

### Hidden Options
- `--follow`: Follow log output in real-time
- `--tail <n>`: Show last n lines of log
- `--grep <pattern>`: Filter log with pattern

## Command Behavior

### Core Functionality
- **Log Retrieval**: Finds and displays build log files
- **Log Parsing**: Formats log output for readability
- **Error Highlighting**: Highlights errors and warnings

### Conditional Behaviors

**Log File Detection:**
- Searches for build system log files
- Handles different build tool log formats
- Falls back to standard output if no log file found

**Output Processing:**
- Filters irrelevant output
- Highlights important messages
- Provides context for errors

## Practical Examples

### Basic Log Display
```bash
# Show build log
mulle-make log

# Show verbose log
mulle-make log --verbose

# Show last 50 lines
mulle-make log --tail 50
```

### Log Filtering
```bash
# Show only errors
mulle-make log --grep "error"

# Show warnings
mulle-make log --grep "warning"

# Show specific component
mulle-make log --grep "cmake"
```

### Real-time Monitoring
```bash
# Follow log during build
mulle-make log --follow &
mulle-make project
```

## Troubleshooting

### No Log Found
```bash
# No build log available
mulle-make log
# No log file found

# Solution: Build first
mulle-make project
mulle-make log
```

### Log File Issues
```bash
# Log file corrupted or inaccessible
mulle-make log
# Error reading log file

# Solution: Clean and rebuild
mulle-make clean
mulle-make project
mulle-make log
```

### Large Log Files
```bash
# Log file too large
mulle-make log
# File too big to display

# Solution: Use tail
mulle-make log --tail 100
```

## Integration with Other Commands

### Build Debugging
```bash
# Build and check log
mulle-make project
mulle-make log

# Clean build with logging
mulle-make clean
mulle-make project
mulle-make log --grep "error"
```

### Error Analysis
```bash
# Find specific errors
mulle-make log --grep "undefined reference"

# Check compiler warnings
mulle-make log --grep "warning"

# Monitor build progress
mulle-make log --follow
```

### Definition Debugging
```bash
# Check if definitions are used
mulle-make definition set CMAKE_BUILD_TYPE Debug
mulle-make project
mulle-make log --grep "CMAKE_BUILD_TYPE"
```

## Technical Details

### Log File Locations
- **CMake**: `CMakeFiles/CMakeOutput.log`, `CMakeFiles/CMakeError.log`
- **Make**: Redirected stdout/stderr from make command
- **Autotools**: `config.log`, make output
- **Meson**: `meson-log.txt`

### Log Format Processing
- Removes ANSI escape sequences
- Normalizes line endings
- Adds timestamps if missing
- Groups related messages

### Error Detection Patterns
- **Compiler errors**: "error:", "Error:"
- **Linker errors**: "undefined reference", "ld: "
- **Warnings**: "warning:", "Warning:"
- **CMake errors**: "CMake Error"

## Related Commands

- **[`project`](project.md)** - Build project
- **[`clean`](clean.md)** - Clean build artifacts
- **[`show`](show.md)** - Show available tools