# mulle-make version - Version Information

## Quick Start
Display mulle-make version information.

## All Available Options

### Basic Usage
```bash
mulle-make version [options]
```

**Arguments:**
- None required

### Visible Options
- `--help`: Show usage information
- `--verbose`: Enable verbose output
- `--quiet`: Suppress output

### Hidden Options
- `--full`: Show full version information
- `--components`: Show component versions
- `--check`: Check for updates

## Command Behavior

### Core Functionality
- **Version Display**: Shows mulle-make version number
- **Component Information**: Displays version of related components
- **Update Checking**: Checks for available updates

### Conditional Behaviors

**Version Format:**
- Standard version format: major.minor.patch
- Development versions include build information
- Release versions are tagged

**Output Formatting:**
- Single line output by default
- Detailed output with --verbose
- Structured output for scripting

## Practical Examples

### Basic Version Display
```bash
# Show version
mulle-make version

# Verbose version information
mulle-make version --verbose

# Full version details
mulle-make version --full
```

### Component Versions
```bash
# Show component versions
mulle-make version --components

# Check for updates
mulle-make version --check

# Use in scripts
VERSION=$(mulle-make version)
```

### Integration with Builds
```bash
# Log version information
echo "Building with mulle-make $(mulle-make version)" > build.log

# Version-specific builds
if [ "$(mulle-make version | cut -d. -f1)" -ge 2 ]; then
    mulle-make definition set NEW_FEATURE enabled
fi
```

## Troubleshooting

### Version Not Displayed
```bash
# No version output
mulle-make version
# Empty output

# Solution: Check installation
which mulle-make
ls -la $(which mulle-make)
```

### Incorrect Version
```bash
# Wrong version displayed
mulle-make version
# Shows old version

# Solution: Update installation
# Check PATH
echo $PATH
which mulle-make
```

### Update Check Fails
```bash
# Update check fails
mulle-make version --check
# Network error

# Solution: Check network connectivity
ping github.com
```

## Integration with Other Commands

### Build Logging
```bash
# Include version in build logs
mulle-make version > version.log
mulle-make project 2>&1 | tee build.log
cat version.log build.log > full.log
```

### Environment Setup
```bash
# Set version-specific environment
MULLE_MAKE_VERSION=$(mulle-make version)
export MULLE_MAKE_VERSION

# Use in build scripts
case "$MULLE_MAKE_VERSION" in
    2.*)
        echo "Using mulle-make v2 features"
        ;;
    1.*)
        echo "Using legacy mulle-make v1"
        ;;
esac
```

### CI/CD Integration
```bash
# Report version in CI
echo "mulle-make version: $(mulle-make version)" >> $GITHUB_STEP_SUMMARY

# Version checks in pipelines
if mulle-make version --check | grep -q "update available"; then
    echo "Update available, consider upgrading"
fi
```

## Technical Details

### Version Number Format
- **Major.Minor.Patch**: Semantic versioning
- **Build Information**: Development builds include git hash
- **Pre-release**: Alpha, beta, rc suffixes

### Component Versions
- **mulle-make core**: Main executable version
- **mulle-bashfunctions**: Library version
- **mulle-bash**: Shell version
- **Dependencies**: Related tool versions

### Update Checking
- Queries GitHub releases API
- Compares current version with latest
- Shows available updates
- Respects rate limits

## Related Commands

- **[`uname`](uname.md)** - Show system information
- **[`show`](show.md)** - Show available build tools
- **[`log`](log.md)** - Show build log