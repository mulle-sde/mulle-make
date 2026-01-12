# mulle-make uname - System Information

## Quick Start
Display mulle-make's simplified system information.

## All Available Options

### Basic Usage
```bash
mulle-make uname [options]
```

**Arguments:**
- None required

### Visible Options
- `--help`: Show usage information
- `--verbose`: Enable verbose output
- `--quiet`: Suppress output

### Hidden Options
- `--full`: Show full uname information
- `--kernel`: Show only kernel information
- `--machine`: Show only machine information

## Command Behavior

### Core Functionality
- **System Detection**: Identifies host operating system
- **Architecture Detection**: Determines CPU architecture
- **Simplified Output**: Provides consistent naming across platforms

### Conditional Behaviors

**Platform Mapping:**
- Maps OS-specific names to mulle-make conventions
- Handles cross-platform compatibility
- Provides fallback for unknown systems

**Output Formatting:**
- Single line output by default
- Structured output for scripting
- Human-readable format

## Practical Examples

### Basic System Information
```bash
# Show system information
mulle-make uname

# Verbose system information
mulle-make uname --verbose

# Full uname information
mulle-make uname --full
```

### Specific Information
```bash
# Show only kernel
mulle-make uname --kernel

# Show only machine
mulle-make uname --machine

# Use in scripts
SYSTEM=$(mulle-make uname)
```

### Integration with Builds
```bash
# Check system before building
mulle-make uname

# Conditional builds
if [ "$(mulle-make uname)" = "linux" ]; then
    mulle-make definition set CMAKE_CXX_FLAGS "-std=c++11"
fi
```

## Troubleshooting

### Incorrect Detection
```bash
# System not detected correctly
mulle-make uname
# Shows wrong OS

# Solution: Check environment
echo $OSTYPE
uname -a
```

### Missing Information
```bash
# No output from uname
mulle-make uname
# Empty output

# Solution: Check system
uname --help
```

### Cross-Platform Issues
```bash
# Inconsistent naming across platforms
mulle-make uname
# Different output on different systems

# Solution: Use --full for detailed info
mulle-make uname --full
```

## Integration with Other Commands

### Build Configuration
```bash
# Set platform-specific definitions
PLATFORM=$(mulle-make uname)
mulle-make definition set PLATFORM "${PLATFORM}"

# Use in build scripts
mulle-make uname --quiet > /tmp/platform
PLATFORM=$(cat /tmp/platform)
```

### Tool Selection
```bash
# Choose tools based on platform
if [ "$(mulle-make uname)" = "darwin" ]; then
    mulle-make -f clang
else
    mulle-make -f gcc
fi
```

### Environment Setup
```bash
# Configure environment based on system
case "$(mulle-make uname)" in
    linux)
        export CC=gcc
        ;;
    darwin)
        export CC=clang
        ;;
    *)
        echo "Unsupported platform"
        exit 1
        ;;
esac
```

## Technical Details

### Platform Detection Algorithm
1. **Environment Check**: Examines `$OSTYPE` and related variables
2. **uname Command**: Uses system uname for detailed information
3. **Mapping**: Converts system names to mulle-make conventions
4. **Fallback**: Provides generic names for unknown systems

### Supported Platforms
- **Linux**: linux
- **macOS**: darwin
- **Windows**: windows (under WSL/cygwin)
- **BSD variants**: bsd
- **Solaris**: solaris
- **Unknown**: generic

### Architecture Mapping
- **x86_64**: amd64
- **i386/i686**: 386
- **arm64/aarch64**: arm64
- **arm**: arm
- **Other**: as reported by uname

## Related Commands

- **[`version`](version.md)** - Show version information
- **[`show`](show.md)** - Show available build tools
- **[`definition`](definition.md)** - Manage build definitions