# mulle-make libexec-dir - Libexec Path

## Quick Start
Display the path to mulle-make's libexec directory.

## All Available Options

### Basic Usage
```bash
mulle-make libexec-dir [options]
```

**Arguments:**
- None required

### Visible Options
- `--help`: Show usage information
- `--verbose`: Enable verbose output
- `--quiet`: Suppress output

### Hidden Options
- `--absolute`: Show absolute path (default)
- `--relative`: Show relative path
- `--exists`: Check if directory exists

## Command Behavior

### Core Functionality
- **Path Display**: Shows libexec directory location
- **Path Resolution**: Resolves to absolute path
- **Existence Check**: Verifies directory accessibility

### Conditional Behaviors

**Path Format:**
- Absolute path by default
- Relative path when requested
- Normalized path format

**Directory Validation:**
- Checks if directory exists
- Verifies read permissions
- Reports accessibility status

## Practical Examples

### Basic Path Display
```bash
# Show libexec directory path
mulle-make libexec-dir

# Verbose path information
mulle-make libexec-dir --verbose

# Check if directory exists
mulle-make libexec-dir --exists
```

### Path Usage
```bash
# Use in scripts
LIBEXEC_DIR=$(mulle-make libexec-dir)
echo "Libexec directory: $LIBEXEC_DIR"

# List contents
ls -la $(mulle-make libexec-dir)
```

### Integration with Builds
```bash
# Set environment variable
export MULLE_MAKE_LIBEXEC_DIR=$(mulle-make libexec-dir)

# Use in build scripts
LIBEXEC=$(mulle-make libexec-dir)
if [ -d "$LIBEXEC" ]; then
    echo "Libexec directory is accessible"
fi
```

## Troubleshooting

### Path Not Found
```bash
# Libexec directory not found
mulle-make libexec-dir
# Error: libexec directory not found

# Solution: Check installation
which mulle-make
ls -la $(dirname $(which mulle-make))
```

### Permission Issues
```bash
# Cannot access libexec directory
mulle-make libexec-dir
# Permission denied

# Solution: Check permissions
LIBEXEC=$(mulle-make libexec-dir)
ls -ld "$LIBEXEC"
```

### Incorrect Path
```bash
# Wrong path displayed
mulle-make libexec-dir
# Shows incorrect path

# Solution: Reinstall or check environment
echo $MULLE_MAKE_LIBEXEC_DIR
```

## Integration with Other Commands

### Script Development
```bash
# Source libexec scripts
LIBEXEC_DIR=$(mulle-make libexec-dir)
. "$LIBEXEC_DIR/mulle-make-build.sh"

# Use libexec functions
mulle_make_build_main "$@"
```

### Environment Setup
```bash
# Set up development environment
export PATH="$(mulle-make libexec-dir):$PATH"

# Configure build environment
LIBEXEC=$(mulle-make libexec-dir)
export MULLE_MAKE_LIBEXEC_DIR="$LIBEXEC"
```

### Tool Integration
```bash
# Use with other mulle tools
MULLE_SDE_LIBEXEC=$(mulle-sde libexec-dir)
MULLE_MAKE_LIBEXEC=$(mulle-make libexec-dir)

# Compare libexec locations
echo "SDE libexec: $MULLE_SDE_LIBEXEC"
echo "Make libexec: $MULLE_MAKE_LIBEXEC"
```

## Technical Details

### Directory Structure
```
libexec/
├── mulle-make-build.sh      # Build functionality
├── mulle-make-definition.sh # Definition management
├── mulle-make-log.sh        # Log handling
├── mulle-make-show.sh       # Tool detection
└── ...                      # Other support scripts
```

### Path Resolution Algorithm
1. **Environment Check**: Uses `$MULLE_MAKE_LIBEXEC_DIR` if set
2. **Relative Path**: Calculates from executable location
3. **Absolute Path**: Converts to full path
4. **Validation**: Ensures directory exists and is accessible

### Security Considerations
- **Path Sanitization**: Prevents path traversal attacks
- **Permission Checks**: Validates directory accessibility
- **Environment Isolation**: Uses secure path resolution

## Related Commands

- **[`version`](version.md)** - Show version information
- **[`uname`](uname.md)** - Show system information
- **[`show`](show.md)** - Show available build tools