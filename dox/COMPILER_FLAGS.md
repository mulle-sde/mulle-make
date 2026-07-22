# Compiler Flag Detection in mulle-make

## Overview

mulle-make needs to generate appropriate compiler flags based on the compiler style (GNU vs MSVC). This document explains how compiler style detection works.

## The Problem

Different compilers use different flags for system includes:
- **GNU-style** (gcc, clang): `-isystem <path>`
- **MSVC-style** (cl, clang-cl): `-external:I <path>`

When cross-compiling (e.g., from Linux to Windows with llvm-mingw), mulle-make needs to detect the correct compiler style for the *target* toolchain, not the *host* system.

## Detection Flow

The detection happens in `src/mulle-make-common.sh` in the function `make::common::r_headerpath_preprocessor_flags()`.

### Priority Order

1. **Toolchain Name** (highest priority)
   - Checks `DEFINITION_TOOLCHAIN` (passed via `--toolchain` argument)
   - Pattern matching:
     - `*gcc*|*gnu*|*mingw*` → GNU-style (`-isystem`)
     - `*clang*|*llvm*` → GNU-style (`-isystem`)
     - `*msvc*|*cl*` → MSVC-style (`-external:I`)

2. **Compiler Detection** (fallback)
   - Calls `make::compiler::r_compiler()` to get the actual compiler
   - Strips extension: `compiler="${RVAL%.*}"`
   - Pattern matching on compiler name:
     - `*clang|*gcc` → GNU-style
     - `*cl` → MSVC-style

3. **Host System** (last resort)
   - Checks `MULLE_UNAME` (the host OS)
   - `windows|mingw` → MSVC-style
   - Everything else → GNU-style (gcc)

## Why Toolchain Detection is First

When cross-compiling, the host system (e.g., Linux) doesn't match the target system (e.g., Windows). The toolchain name is the most reliable indicator of what compiler style to use:

- `toolchain-llvm-mingw-clang.cmake` → GNU-style clang for Windows
- `toolchain-msvc.cmake` → MSVC-style
- `toolchain-gcc-linux.cmake` → GNU-style gcc

## Code Location

File: `src/mulle-make-common.sh`
Function: `make::common::r_headerpath_preprocessor_flags()`
Lines: ~675-720

## Example

```bash
# mulle-craft passes:
mulle-make --toolchain toolchain-llvm-mingw-clang.cmake ...

# mulle-make detects:
DEFINITION_TOOLCHAIN="toolchain-llvm-mingw-clang.cmake"
# Matches *clang* → compiler="clang"
# Generates: -isystem /path/to/include
```

## Related

- Toolchain files are in the project's `cmake/` directory
- mulle-craft passes toolchain via `--toolchain` argument (see `src/mulle-craft-build.sh`)
- Compiler detection is in `src/mulle-make-compiler.sh`
