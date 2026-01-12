# mulle-make clean - Clean Build Artifacts

## Quick Start
Remove build artifacts and temporary files from the project.

## All Available Options

### Basic Usage
```bash
mulle-make clean [options]
```

**Arguments:**
- None required

### Visible Options
- `--help`: Show usage information
- `--verbose`: Enable verbose output
- `--quiet`: Suppress output
- `--dry-run`: Show what would be deleted without removing

### Hidden Options
- `--force`: Force removal without confirmation
- `--cache`: Also clean build system cache files
- `--all`: Clean all build artifacts including dependencies

## Command Behavior

### Core Functionality
- **Artifact Removal**: Deletes build output files and directories
- **Cache Cleaning**: Removes build system cache and temporary files
- **Safe Operation**: Preserves source files and configuration

### Conditional Behaviors

**Build Directory Detection:**
- Locates build directories automatically
- Handles multiple build configurations
- Preserves user-specified build locations

**Selective Cleaning:**
- Removes object files, executables, and libraries
- Keeps source files and build configuration
- Optionally preserves debug information

## Practical Examples

### Basic Cleaning
```bash
# Clean current build artifacts
mulle-make clean

# Clean with verbose output
mulle-make clean --verbose

# Preview what will be cleaned
mulle-make clean --dry-run
```

### Advanced Cleaning
```bash
# Clean everything including cache
mulle-make clean --cache

# Force clean without confirmation
mulle-make clean --force

# Clean all build artifacts
mulle-make clean --all
```

### Development Workflow
```bash
# Clean and rebuild
mulle-make clean
mulle-make project

# Clean specific build type
mulle-make clean
mulle-make project -DCMAKE_BUILD_TYPE=Debug
```

## Troubleshooting

### Permission Issues
```bash
# Permission denied during clean
mulle-make clean
# Error: Permission denied

# Solution: Check file permissions
ls -la build/
chmod -R u+w build/
mulle-make clean
```

### Build Directory Not Found
```bash
# No build directory to clean
mulle-make clean
# Warning: No build artifacts found

# Solution: Build first or check location
mulle-make project
mulle-make clean
```

### Incomplete Cleaning
```bash
# Some files remain after clean
mulle-make clean
ls build/
# Still shows some files

# Solution: Use force option
mulle-make clean --force
```

## Integration with Other Commands

### Build Cycle Management
```bash
# Standard clean-build cycle
mulle-make clean
mulle-make project

# Clean before install
mulle-make clean
mulle-make install
```

### Definition Management
```bash
# Clean after changing definitions
mulle-make definition set CMAKE_BUILD_TYPE Release
mulle-make clean
mulle-make project
```

### Log Management
```bash
# Clean and check logs
mulle-make clean
mulle-make log  # Should show no previous build
```

## Technical Details

### Cleaned File Types
- **Object Files**: `*.o`, `*.obj`
- **Executables**: Binary files and scripts
- **Libraries**: `*.a`, `*.so`, `*.dylib`
- **Build Cache**: CMake cache, dependency files
- **Temporary Files**: Build system temporaries

### Directory Structure Preservation
```
Before clean:
project/
├── build/
│   ├── CMakeCache.txt
│   ├── CMakeFiles/
│   ├── Makefile
│   └── executable

After clean:
project/
├── build/          # Directory preserved
└── src/           # Source preserved
```

### Clean Process Flow
1. **Detection**: Locate build directories and artifacts
2. **Safety Check**: Verify files are safe to remove
3. **Removal**: Delete build artifacts selectively
4. **Verification**: Confirm cleaning completion

### Platform-Specific Cleaning
- **Unix/Linux**: Removes `.o`, executables, libraries
- **Windows**: Removes `.obj`, `.exe`, `.lib`, `.dll`
- **macOS**: Additional framework and bundle cleanup

## Related Commands

- **[`project`](project.md)** - Build project
- **[`install`](install.md)** - Build and install
- **[`definition`](definition.md)** - Manage definitions
- **[`log`](log.md)** - Show build log