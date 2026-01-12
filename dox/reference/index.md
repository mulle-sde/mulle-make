# mulle-make Command Reference

## Overview

**mulle-make** is a cross-platform build tool that automatically detects and invokes appropriate build systems (cmake, configure, make, etc.) for your project. This reference documents all available commands organized by category.

## Command Categories

### Build Operations
- **[`project`](project.md)** - Build project (default command)
- **[`install`](install.md)** - Build project and install
- **[`clean`](clean.md)** - Clean build artifacts

### Configuration
- **[`definition`](definition.md)** - Manage build definitions and flags

### Information & Diagnostics
- **[`list`](list.md)** - List definitions values at build time
- **[`show`](show.md)** - Show available buildtools
- **[`log`](log.md)** - Show build log (if run standalone)
- **[`uname`](uname.md)** - mulle-make's simplified uname(1)
- **[`version`](version.md)** - Print mulle-make version
- **[`libexec-dir`](libexec-dir.md)** - Print path to mulle-make libexec

## Quick Start Examples

### Basic Project Build
```bash
# Build project with auto-detected build system
mulle-make

# Build with specific command
mulle-make project

# Clean and rebuild
mulle-make clean
mulle-make
```

### Build with Custom Definitions
```bash
# Set build flags
mulle-make definition set CMAKE_BUILD_TYPE Debug

# Build with custom flags
mulle-make -DCMAKE_BUILD_TYPE=Release

# List current definitions
mulle-make list
```

### Installation
```bash
# Build and install
mulle-make install

# Install to custom location
mulle-make install -DCMAKE_INSTALL_PREFIX=/usr/local
```

## Command Reference Table

| Command | Category | Description |
|---------|----------|-------------|
| `project` | Build | Build project (default) |
| `install` | Build | Build and install project |
| `clean` | Build | Clean build artifacts |
| `definition` | Configuration | Manage build definitions |
| `list` | Information | List definitions at build time |
| `show` | Information | Show available buildtools |
| `log` | Information | Show build log |
| `uname` | Information | System information |
| `version` | Information | Version information |
| `libexec-dir` | Information | Libexec path |

## Getting Help

### Command Help
```bash
# Get help for specific command
mulle-make <command> --help

# Get detailed help
mulle-make <command> --help --verbose

# List all commands
mulle-make --help
```

### Documentation
- Each command has a dedicated documentation file in this reference
- Use `--help` for quick command usage
- Check `mulle-make show` for available build tools

## Common Workflows

### Standard Development Cycle
1. **Configure** build: `mulle-make definition set <flags>`
2. **Build** project: `mulle-make project`
3. **Check** results: `mulle-make list`
4. **Install** if needed: `mulle-make install`

### Debugging Build Issues
1. **Check** build tools: `mulle-make show`
2. **View** build log: `mulle-make log`
3. **List** definitions: `mulle-make list`
4. **Clean** and retry: `mulle-make clean && mulle-make`

### Custom Build Configuration
1. **Set** definitions: `mulle-make definition set <key> <value>`
2. **Verify** settings: `mulle-make list`
3. **Build** with custom config: `mulle-make`

## Advanced Usage

### Build Definitions Management
```bash
# Set multiple definitions
mulle-make definition set CMAKE_BUILD_TYPE Debug
mulle-make definition set CMAKE_INSTALL_PREFIX /usr/local

# Remove definition
mulle-make definition remove CMAKE_BUILD_TYPE

# Clear all definitions
mulle-make definition clear
```

### Build Tool Selection
```bash
# Force specific build tool
mulle-make -f cmake
mulle-make -f make

# Check available tools
mulle-make show
```

### Environment Integration
```bash
# Use environment variables
CC=clang CXX=clang++ mulle-make

# Pass through to build system
CFLAGS="-O2 -g" mulle-make
```

## Troubleshooting

### Build Failures
```bash
# Check build log
mulle-make log

# Verify build tools
mulle-make show

# List current definitions
mulle-make list

# Clean and retry
mulle-make clean
mulle-make
```

### Configuration Issues
```bash
# Check definitions
mulle-make list

# Reset definitions
mulle-make definition clear

# Verify system
mulle-make uname
```

### Tool Detection Problems
```bash
# List available tools
mulle-make show

# Force tool selection
mulle-make -f <tool>

# Check version
mulle-make version
```

## Integration with Other Tools

### Development Environments
```bash
# With mulle-env
mulle-env environment set CC clang
mulle-make

# With IDE build systems
mulle-make -G "Unix Makefiles"
```

### CI/CD Pipelines
```bash
# Automated builds
mulle-make clean
mulle-make definition set CMAKE_BUILD_TYPE Release
mulle-make install
```

### Cross-Platform Builds
```bash
# Platform-specific builds
mulle-make uname  # Check platform
mulle-make -DCMAKE_TOOLCHAIN_FILE=toolchain.cmake
```

## Related Documentation

- **[README.md](../../README.md)** - Project overview and installation
- **[mulle-sde](../mulle-sde/)** - Build system integration
- **[Definition Management](./definition.md)** - Advanced definition configuration
- **[Build Tools](./show.md)** - Available build tool information