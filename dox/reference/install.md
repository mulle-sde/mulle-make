# mulle-make install - Build and Install Project

## Quick Start
Build a project and install the resulting artifacts to the system.

## All Available Options

### Basic Usage
```bash
mulle-make install [options] [install-arguments]
mulle-make craft [options] [install-arguments]
```

**Arguments:**
- `install-arguments`: Arguments passed to the underlying install system

### Visible Options
- `--help`: Show usage information
- `--verbose`: Enable verbose output
- `--quiet`: Suppress output
- `--dry-run`: Show what would be executed without running

### Hidden Options
- `--force`: Force installation even if files exist
- `--prefix <path>`: Set installation prefix
- `--destdir <path>`: Set installation destination directory
- `--strip`: Strip debug symbols during installation

## Command Behavior

### Core Functionality
- **Build First**: Automatically builds the project if not already built
- **Install Execution**: Runs the appropriate install commands for the detected build system
- **File Management**: Copies built artifacts to installation directories
- **Permission Handling**: Manages file permissions and ownership

### Conditional Behaviors

**Installation Target Detection:**
- Uses build system defaults for installation paths
- Respects CMAKE_INSTALL_PREFIX and similar variables
- Handles platform-specific installation conventions

**Dependency Installation:**
- Installs required runtime libraries and dependencies
- Creates necessary directory structures
- Updates system package databases if applicable

## Practical Examples

### Basic Installation
```bash
# Build and install project
mulle-make install

# Install with verbose output
mulle-make install --verbose

# Install to custom location
mulle-make install --prefix /usr/local
```

### Custom Installation Paths
```bash
# Install to specific directory
mulle-make install --destdir /tmp/package

# Set custom prefix
mulle-make install -DCMAKE_INSTALL_PREFIX=/opt/myapp

# Install without debug symbols
mulle-make install --strip
```

### Development Installation
```bash
# Install for development
mulle-make install --prefix ~/.local

# Install with debug symbols
mulle-make install -DCMAKE_BUILD_TYPE=Debug

# Force reinstall
mulle-make install --force
```

## Troubleshooting

### Permission Issues
```bash
# Permission denied during install
mulle-make install
# Error: Permission denied

# Solution: Use sudo or change prefix
sudo mulle-make install
# Or
mulle-make install --prefix ~/.local
```

### Missing Build
```bash
# Install without prior build
mulle-make install
# Error: No build artifacts found

# Solution: Build first
mulle-make project
mulle-make install
```

### Installation Conflicts
```bash
# Files already exist
mulle-make install
# Error: File exists

# Solution: Force install or clean first
mulle-make install --force
# Or
mulle-make clean
mulle-make install
```

## Integration with Other Commands

### Build Configuration
```bash
# Configure build before install
mulle-make definition set CMAKE_INSTALL_PREFIX /usr/local
mulle-make install

# Build with specific options
mulle-make project -DCMAKE_BUILD_TYPE=Release
mulle-make install
```

### Clean Operations
```bash
# Clean and reinstall
mulle-make clean
mulle-make install

# Or use combined workflow
mulle-make project
mulle-make install
```

### Definition Management
```bash
# Set installation definitions
mulle-make definition set CMAKE_INSTALL_PREFIX /opt/app
mulle-make definition set CMAKE_INSTALL_RPATH /opt/app/lib
mulle-make install
```

## Technical Details

### Installation Directory Structure
```
<prefix>/
├── bin/           # Executables
├── lib/           # Libraries
├── include/       # Header files
├── share/         # Data files
└── man/           # Manual pages
```

### Installation Process Flow
1. **Build Verification**: Ensure project is built and up-to-date
2. **Directory Creation**: Create installation directory structure
3. **File Copying**: Copy built artifacts to installation locations
4. **Permission Setting**: Set appropriate file permissions
5. **Path Updates**: Update dynamic library paths and symlinks

### Supported Installation Methods
- **CMake**: Uses cmake --install with DESTDIR support
- **Make**: Uses make install with prefix support
- **Autotools**: Uses make install with DESTDIR support
- **Custom**: Project-specific installation scripts

### Installation Variables
- **CMAKE_INSTALL_PREFIX**: Base installation directory
- **CMAKE_INSTALL_BINDIR**: Executable installation directory
- **CMAKE_INSTALL_LIBDIR**: Library installation directory
- **CMAKE_INSTALL_INCLUDEDIR**: Header installation directory
- **DESTDIR**: Staging directory for packaging

## Related Commands

- **[`project`](project.md)** - Build project
- **[`clean`](clean.md)** - Clean build artifacts
- **[`definition`](definition.md)** - Manage build definitions
- **[`list`](list.md)** - List current definitions