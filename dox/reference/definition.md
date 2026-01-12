# mulle-make definition - Manage Build Definitions

## Quick Start
Manage build definitions and flags for mulle-make's build system.

## All Available Options

### Basic Usage
```bash
mulle-make definition <subcommand> [key] [value]
```

**Arguments:**
- `subcommand`: Operation to perform (set, get, remove, list, clear)
- `key`: Definition key name
- `value`: Definition value

### Visible Options
- `--help`: Show usage information
- `--verbose`: Enable verbose output
- `--quiet`: Suppress output
- `--global`: Apply to global definitions

### Hidden Options
- `--force`: Force operation without confirmation
- `--temporary`: Set temporary definition (not persisted)
- `--environment`: Include environment variables

## Command Behavior

### Core Functionality
- **Set**: Define build flags and variables
- **Get**: Retrieve definition values
- **Remove**: Delete specific definitions
- **List**: Display all current definitions
- **Clear**: Remove all definitions

### Conditional Behaviors

**Definition Storage:**
- Persists definitions across sessions
- Supports project-specific and global definitions
- Handles environment variable integration

**Definition Types:**
- Build flags (-D options)
- Compiler settings
- Linker options
- Platform-specific configurations

## Practical Examples

### Setting Definitions
```bash
# Set build type
mulle-make definition set CMAKE_BUILD_TYPE Debug

# Set compiler flags
mulle-make definition set CMAKE_CXX_FLAGS "-O2 -g"

# Set installation prefix
mulle-make definition set CMAKE_INSTALL_PREFIX /usr/local
```

### Managing Definitions
```bash
# List all definitions
mulle-make definition list

# Get specific definition
mulle-make definition get CMAKE_BUILD_TYPE

# Remove definition
mulle-make definition remove CMAKE_CXX_FLAGS

# Clear all definitions
mulle-make definition clear
```

### Advanced Configuration
```bash
# Multiple related definitions
mulle-make definition set CMAKE_BUILD_TYPE Release
mulle-make definition set CMAKE_CXX_FLAGS "-O3 -DNDEBUG"
mulle-make definition set CMAKE_INSTALL_PREFIX /opt/myapp

# Check current configuration
mulle-make definition list
```

## Troubleshooting

### Definition Not Applied
```bash
# Definition not used in build
mulle-make definition set CMAKE_BUILD_TYPE Debug
mulle-make project
# Build still uses Release

# Solution: Clean and rebuild
mulle-make clean
mulle-make project
```

### Invalid Definition
```bash
# Invalid definition syntax
mulle-make definition set INVALID_KEY
# Error: Invalid definition

# Solution: Check syntax
mulle-make definition set VALID_KEY valid_value
```

### Permission Issues
```bash
# Cannot write definitions
mulle-make definition set CMAKE_BUILD_TYPE Debug
# Error: Permission denied

# Solution: Check file permissions
ls -la .mulle/
chmod u+w .mulle/
```

## Integration with Other Commands

### Build Integration
```bash
# Set definitions before building
mulle-make definition set CMAKE_BUILD_TYPE Debug
mulle-make project

# Use with install
mulle-make definition set CMAKE_INSTALL_PREFIX /usr/local
mulle-make install
```

### Definition Inspection
```bash
# Check definitions used in build
mulle-make definition list
mulle-make list  # Shows definitions at build time
```

### Clean Operations
```bash
# Clear definitions and clean
mulle-make definition clear
mulle-make clean
```

## Technical Details

### Definition Storage Format
```
.mulle/var/<host>/<user>/env/definition/
├── DEFINITION_CMAKE_BUILD_TYPE
├── DEFINITION_CMAKE_CXX_FLAGS
└── DEFINITION_CMAKE_INSTALL_PREFIX
```

### Definition Types
- **CMAKE_***: CMake-specific variables
- **CFLAGS/CXXFLAGS**: Compiler flags
- **LDFLAGS**: Linker flags
- **PLATFORM_***: Platform-specific settings

### Definition Precedence
1. Command-line arguments (highest priority)
2. Project definitions
3. Global definitions
4. Environment variables
5. Build system defaults (lowest priority)

### Persistence Mechanism
- Definitions stored in environment files
- Survives shell sessions
- Can be version controlled
- Supports inheritance

## Related Commands

- **[`list`](list.md)** - List definitions at build time
- **[`project`](project.md)** - Build with current definitions
- **[`clean`](clean.md)** - Clean build artifacts