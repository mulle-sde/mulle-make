# mulle-make list - List Definitions

## Quick Start
Display current build definitions and their values at build time.

## All Available Options

### Basic Usage
```bash
mulle-make list [options]
```

**Arguments:**
- None required

### Visible Options
- `--help`: Show usage information
- `--verbose`: Enable verbose output
- `--quiet`: Suppress output

### Hidden Options
- `--all`: List all definitions including environment
- `--format <format>`: Output format (text, json, etc.)
- `--filter <pattern>`: Filter definitions by pattern

## Command Behavior

### Core Functionality
- **Definition Display**: Shows all active build definitions
- **Value Resolution**: Displays actual values used during build
- **Source Tracking**: Indicates where each definition comes from

### Conditional Behaviors

**Definition Sources:**
- Command-line arguments
- Project definitions
- Global definitions
- Environment variables
- Build system defaults

**Output Formatting:**
- Human-readable format by default
- Structured output for scripting
- Filtered output for specific definitions

## Practical Examples

### Basic Listing
```bash
# List all current definitions
mulle-make list

# Verbose listing with sources
mulle-make list --verbose

# List with specific format
mulle-make list --format json
```

### Filtered Listing
```bash
# List CMAKE definitions only
mulle-make list --filter CMAKE_*

# List all definitions including environment
mulle-make list --all

# List specific definition
mulle-make list --filter CMAKE_BUILD_TYPE
```

### Integration with Other Commands
```bash
# Check definitions before building
mulle-make list
mulle-make project

# Verify definition changes
mulle-make definition set CMAKE_BUILD_TYPE Debug
mulle-make list
```

## Troubleshooting

### No Definitions Found
```bash
# No definitions to list
mulle-make list
# No output or empty list

# Solution: Set some definitions first
mulle-make definition set CMAKE_BUILD_TYPE Release
mulle-make list
```

### Incorrect Values
```bash
# Definition shows wrong value
mulle-make list
# CMAKE_BUILD_TYPE=Debug (expected Release)

# Solution: Clean and rebuild
mulle-make clean
mulle-make list
```

### Permission Issues
```bash
# Cannot access definition files
mulle-make list
# Error: Permission denied

# Solution: Check file permissions
ls -la .mulle/var/
```

## Integration with Other Commands

### Definition Management
```bash
# Set and verify definitions
mulle-make definition set CMAKE_BUILD_TYPE Debug
mulle-make list

# Remove and verify
mulle-make definition remove CMAKE_BUILD_TYPE
mulle-make list
```

### Build Integration
```bash
# Check definitions used in build
mulle-make list
mulle-make project

# Verify build configuration
mulle-make list --verbose
```

### Definition Persistence
```bash
# Definitions persist across sessions
mulle-make definition set MY_VAR value
mulle-make list  # Shows MY_VAR=value
# In new shell
mulle-make list  # Still shows MY_VAR=value
```

## Technical Details

### Definition Resolution Order
1. **Command-line arguments** (highest priority)
2. **Project definitions** (.mulle/var/project/definition/)
3. **Global definitions** (.mulle/var/global/definition/)
4. **Environment variables**
5. **Build system defaults** (lowest priority)

### Output Format Structure
```
DEFINITION_NAME=VALUE [SOURCE]
CMAKE_BUILD_TYPE=Debug [project]
CC=gcc [environment]
```

### Definition Categories
- **CMAKE_***: CMake-specific variables
- **C/CXXFLAGS**: Compiler flags
- **LDFLAGS**: Linker flags
- **Environment**: System environment variables
- **Custom**: User-defined variables

## Related Commands

- **[`definition`](definition.md)** - Manage build definitions
- **[`project`](project.md)** - Build with current definitions
- **[`show`](show.md)** - Show available build tools