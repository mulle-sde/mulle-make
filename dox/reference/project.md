# mulle-make project - Build Project

## Quick Start
Build a project using mulle-make's automatic build system detection.

## All Available Options

### Basic Usage
```bash
mulle-make project [options] [build-arguments]
mulle-make [options] [build-arguments]  # project is default command
```

**Arguments:**
- `build-arguments`: Arguments passed to the underlying build system (cmake, make, etc.)

### Visible Options
- `--help`: Show usage information
- `--verbose`: Enable verbose output
- `--quiet`: Suppress output
- `--dry-run`: Show what would be executed without running

### Hidden Options
- `--force`: Force rebuild even if up-to-date
- `--clean`: Clean before building
- `--parallel <n>`: Use parallel builds with n jobs
- `--tool <tool>`: Force specific build tool (cmake, make, etc.)

## Command Behavior

### Core Functionality
- **Auto-Detection**: Automatically detects available build systems (cmake, configure, make)
- **Build Execution**: Runs the appropriate build commands for the detected system
- **Dependency Handling**: Manages build dependencies and order
- **Error Reporting**: Provides clear error messages and diagnostics

### Conditional Behaviors

**Build System Detection:**
- Searches for CMakeLists.txt, configure, Makefile in order
- Validates build system requirements and dependencies
- Falls back to alternative build systems if primary fails

**Build Configuration:**
- Uses existing build directory or creates new one
- Preserves build configuration across runs
- Handles incremental builds efficiently

## Practical Examples

### Basic Project Build
```bash
# Build project with auto-detected build system
mulle-make project

# Build with verbose output
mulle-make project --verbose

# Force rebuild
mulle-make project --force
```

### Custom Build Configuration
```bash
# Build with specific generator
mulle-make project -G "Unix Makefiles"

# Set build type
mulle-make project -DCMAKE_BUILD_TYPE=Debug

# Use parallel builds
mulle-make project --parallel 4
```

### Development Workflow
```bash
# Quick build during development
mulle-make

# Clean build for release
mulle-make clean
mulle-make project -DCMAKE_BUILD_TYPE=Release

# Debug build with symbols
mulle-make project -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS="-g -O0"
```

## Troubleshooting

### Build System Not Found
```bash
# No build system detected
mulle-make project
# Error: No suitable build system found

# Solution: Check for build files
ls -la CMakeLists.txt configure Makefile

# Or specify build tool explicitly
mulle-make project --tool cmake
```

### Build Failures
```bash
# Build fails with errors
mulle-make project
# Error: Build failed

# Solution: Check build log
mulle-make log

# Clean and retry
mulle-make clean
mulle-make project
```

### Dependency Issues
```bash
# Missing build dependencies
mulle-make project
# Error: Missing required tools

# Solution: Install dependencies
sudo apt install cmake build-essential

# Or check available tools
mulle-make show
```

## Integration with Other Commands

### Definition Management
```bash
# Set build definitions
mulle-make definition set CMAKE_BUILD_TYPE Debug
mulle-make project

# List current definitions
mulle-make list
```

### Clean Operations
```bash
# Clean before building
mulle-make clean
mulle-make project

# Or use combined option
mulle-make project --clean
```

### Installation
```bash
# Build and install
mulle-make project
mulle-make install
```

## Technical Details

### Build System Priority
1. **CMake**: Preferred for complex projects with CMakeLists.txt
2. **Configure**: Used for autotools-based projects
3. **Make**: Fallback for projects with Makefile
4. **Direct**: For simple single-file projects

### Build Directory Structure
```
build/
├── CMakeCache.txt      # CMake cache
├── CMakeFiles/         # CMake temporary files
├── Makefile            # Generated makefile
└── <target>            # Built executables/libraries
```

### Build Process Flow
1. **Detection**: Identify available build systems
2. **Configuration**: Generate build files if needed
3. **Compilation**: Execute build commands
4. **Linking**: Link object files into final targets
5. **Completion**: Report build status and artifacts

### Supported Build Tools
- **CMake**: Cross-platform build system
- **Make**: Traditional build automation
- **Ninja**: High-performance build system
- **Autotools**: configure/make based builds

## Related Commands

- **[`install`](install.md)** - Build and install project
- **[`clean`](clean.md)** - Clean build artifacts
- **[`definition`](definition.md)** - Manage build definitions
- **[`show`](show.md)** - Show available build tools
- **[`log`](log.md)** - Show build log