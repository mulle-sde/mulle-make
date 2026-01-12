# mulle-make show - Show Available Build Tools

## Quick Start
Display available build tools and their capabilities.

## All Available Options

### Basic Usage
```bash
mulle-make show [options]
```

**Arguments:**
- None required

### Visible Options
- `--help`: Show usage information
- `--verbose`: Enable verbose output
- `--quiet`: Suppress output

### Hidden Options
- `--all`: Show all available tools including experimental
- `--format <format>`: Output format (text, json, etc.)
- `--filter <pattern>`: Filter tools by pattern

## Command Behavior

### Core Functionality
- **Tool Detection**: Scans for available build tools
- **Capability Assessment**: Tests tool functionality
- **Priority Ordering**: Shows tools in preference order

### Conditional Behaviors

**Tool Discovery:**
- Searches standard system paths
- Checks for tool-specific files (CMakeLists.txt, configure, etc.)
- Validates tool versions and capabilities

**Output Formatting:**
- Human-readable format by default
- Structured output for scripting
- Filtered output for specific tools

## Practical Examples

### Basic Tool Display
```bash
# Show all available build tools
mulle-make show

# Show tools with verbose information
mulle-make show --verbose

# Show tools in JSON format
mulle-make show --format json
```

### Filtered Tool Display
```bash
# Show only cmake-related tools
mulle-make show --filter cmake

# Show experimental tools
mulle-make show --all

# Show specific tool
mulle-make show --filter make
```

### Integration with Build
```bash
# Check available tools before building
mulle-make show

# Force specific tool
mulle-make show  # Shows cmake available
mulle-make -f cmake project
```

## Troubleshooting

### No Tools Found
```bash
# No build tools detected
mulle-make show
# No tools found

# Solution: Install build tools
# Ubuntu/Debian
sudo apt-get install cmake build-essential
# macOS
brew install cmake
```

### Tool Detection Issues
```bash
# Tool not detected despite being installed
mulle-make show
# Missing expected tool

# Solution: Check PATH
echo $PATH
which cmake
```

### Permission Issues
```bash
# Cannot execute tools
mulle-make show
# Permission denied

# Solution: Check tool permissions
ls -la /usr/bin/cmake
```

## Integration with Other Commands

### Build Tool Selection
```bash
# Check available tools
mulle-make show

# Select specific tool
mulle-make -f cmake project

# Use default tool
mulle-make project
```

### Tool Validation
```bash
# Verify tool capabilities
mulle-make show --verbose

# Test tool with project
mulle-make show
mulle-make project
```

### Troubleshooting Builds
```bash
# Check tools when build fails
mulle-make show

# Verify tool versions
cmake --version
make --version
```

## Technical Details

### Tool Detection Algorithm
1. **Path Scanning**: Searches PATH for executables
2. **File Detection**: Looks for project-specific files
3. **Version Checking**: Validates tool versions
4. **Capability Testing**: Tests tool functionality

### Supported Build Tools
- **CMake**: Cross-platform build system
- **Make**: Traditional build tool
- **Autotools**: configure/make based builds
- **Meson**: Next-generation build system
- **Ninja**: High-performance build tool

### Tool Priority Order
1. **CMake** (preferred for new projects)
2. **Make** (traditional fallback)
3. **Autotools** (legacy support)
4. **Meson** (modern alternative)
5. **Ninja** (performance-focused)

## Related Commands

- **[`project`](project.md)** - Build with detected tools
- **[`definition`](definition.md)** - Configure build settings
- **[`list`](list.md)** - List current definitions