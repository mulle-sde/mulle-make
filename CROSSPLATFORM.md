# Cross-Platform Compilation with mulle-make

This document describes how to use mulle-make for cross-compilation across different build systems (CMake, autoconf/configure, make, meson).

## Overview

mulle-make supports cross-compilation through a unified toolchain approach that works across all supported build systems. The key components are:

1. **Toolchain naming convention** - encodes target information in the filename
2. **Toolchain tools root** - directory containing cross-compilation tools
3. **Build system adapters** - automatic translation to each build system's format

## Toolchain Naming Convention

Toolchain files follow this naming pattern:

```
toolchain--<build>-<host>--<triplet>--<compiler>.cmake
```

### Components:

- **build**: The system you're building on (e.g., `linux`, `darwin`)
- **host**: The system you're building for (e.g., `windows`, `linux`, `android`)
- **triplet**: GNU target triplet (e.g., `x86_64-w64-mingw32`, `aarch64-linux-gnu`)
  - Format: `<arch>-<vendor>-<os>` or `<arch>-<vendor>-<os>-<abi>`
- **compiler**: Compiler suite name (e.g., `mulle-clang`, `gcc`)

### Examples:

```
toolchain--linux-windows--x86_64-w64-mingw32--mulle-clang.cmake
toolchain--darwin-linux--aarch64-linux-gnu--gcc.cmake
toolchain--linux-android--aarch64-linux-android21--clang.cmake
toolchain--linux-linux--x86_64-pc-linux-gnu--gcc.cmake
```

## Toolchain Tools Root

The `--toolchain-tools-root` option specifies the base directory containing your cross-compilation toolchain:

```bash
mulle-make --toolchain-tools-root /opt/mulle-clang-project-windows/21.1.8.2
```

mulle-make will automatically discover tools in `${TOOLCHAIN_TOOLS_ROOT}/bin/`:

- `clang` or `gcc` - C compiler
- `clang++` or `g++` - C++ compiler
- `llvm-ar` or `ar` - Archiver
- `llvm-ranlib` or `ranlib` - Archive indexer
- `llvm-strip` or `strip` - Symbol stripper

## Build System Integration

### CMake

CMake uses the toolchain file directly via `--toolchain`:

```bash
mulle-make --toolchain cmake/toolchain--linux-windows--x86_64--x86_64-w64-mingw32--mulle-clang.cmake \
           --toolchain-tools-root /opt/mulle-clang-project-windows/21.1.8.2 \
           install
```

The toolchain file should define:
- `CMAKE_SYSTEM_NAME`
- `CMAKE_C_COMPILER`
- `CMAKE_CXX_COMPILER`
- `CMAKE_C_COMPILER_TARGET` (for clang)
- Other CMake-specific variables

### Autoconf/Configure

For autoconf-based projects, mulle-make:

1. Parses the toolchain filename to extract the target triplet
2. Passes `--host=<triplet>` to configure
3. Sets environment variables: `CC`, `CXX`, `AR`, `RANLIB`, `STRIP`, `CFLAGS`, `CXXFLAGS`, `LDFLAGS`

Example:

```bash
cd libbacktrace
mulle-make --toolchain cmake/toolchain--linux-windows--x86_64--x86_64-w64-mingw32--mulle-clang.cmake \
           --toolchain-tools-root /opt/mulle-clang-project-windows/21.1.8.2 \
           --library-style static \
           install
```

This translates to:

```bash
CC=/opt/mulle-clang-project-windows/21.1.8.2/bin/clang \
CXX=/opt/mulle-clang-project-windows/21.1.8.2/bin/clang++ \
AR=/opt/mulle-clang-project-windows/21.1.8.2/bin/llvm-ar \
RANLIB=/opt/mulle-clang-project-windows/21.1.8.2/bin/llvm-ranlib \
CFLAGS="-target x86_64-w64-mingw32" \
./configure --host=x86_64-w64-mingw32 --enable-static --disable-shared --prefix=/usr/local
```

### Make

For plain Makefile projects, mulle-make passes cross-compilation tools as make variables:

```bash
make CC=/opt/.../bin/clang \
     AR=/opt/.../bin/llvm-ar \
     RANLIB=/opt/.../bin/llvm-ranlib \
     CFLAGS="-target x86_64-w64-mingw32" \
     install
```

### Meson

Meson requires a separate cross-file format. You can either:

1. **Provide a meson cross-file explicitly:**

```bash
mulle-make --toolchain-meson meson-cross-windows.ini install
```

2. **Use DEFINITION_MESON_CROSS_FILE environment variable:**

```bash
export DEFINITION_MESON_CROSS_FILE=meson-cross-windows.ini
mulle-make install
```

#### Meson Cross-File Format

Example `meson-cross-windows.ini`:

```ini
[binaries]
c = '/opt/mulle-clang-project-windows/21.1.8.2/bin/clang'
cpp = '/opt/mulle-clang-project-windows/21.1.8.2/bin/clang++'
ar = '/opt/mulle-clang-project-windows/21.1.8.2/bin/llvm-ar'
strip = '/opt/mulle-clang-project-windows/21.1.8.2/bin/llvm-strip'
ranlib = '/opt/mulle-clang-project-windows/21.1.8.2/bin/llvm-ranlib'

[properties]
c_args = ['-target', 'x86_64-w64-mingw32']
cpp_args = ['-target', 'x86_64-w64-mingw32']
c_link_args = ['-target', 'x86_64-w64-mingw32']
cpp_link_args = ['-target', 'x86_64-w64-mingw32']

[host_machine]
system = 'windows'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
```

## Complete Example: Cross-Compiling libbacktrace for Windows

```bash
# Setup
export TOOLCHAIN_ROOT=/opt/mulle-clang-project-windows/21.1.8.2
export TOOLCHAIN_FILE=cmake/toolchain--linux-windows--x86_64-w64-mingw32--mulle-clang.cmake

# Build
cd libbacktrace
mulle-make --toolchain "${TOOLCHAIN_FILE}" \
           --toolchain-tools-root "${TOOLCHAIN_ROOT}" \
           --library-style static \
           --prefix /tmp/libbacktrace-windows \
           install

# Result: static library at /tmp/libbacktrace-windows/lib/libbacktrace.a
```

## Environment Variables

You can also set these via environment variables:

```bash
export DEFINITION_TOOLCHAIN=/path/to/toolchain.cmake
export DEFINITION_TOOLCHAIN_TOOLS_ROOT=/opt/toolchain
export DEFINITION_TOOLCHAIN_MESON=/path/to/meson-cross.ini
export DEFINITION_LIBRARY_STYLE=static
```

## Library Styles

When cross-compiling, specify the library type:

- `--library-style static` - Build static libraries (`.a`)
- `--library-style dynamic` - Build shared libraries (`.so`, `.dll`, `.dylib`)

For configure-based projects:
- `static` → `--enable-static --disable-shared`
- `dynamic` → `--enable-shared --disable-static`

## Troubleshooting

### Tool Not Found

If mulle-make can't find cross-compilation tools:

1. Verify `--toolchain-tools-root` points to the correct directory
2. Check that tools exist in `${TOOLCHAIN_TOOLS_ROOT}/bin/`
3. Ensure tools are executable (`chmod +x`)

### Wrong Target Architecture

If binaries are built for the wrong architecture:

1. Verify the toolchain filename matches your target
2. Check that `CFLAGS` includes the correct `-target` flag
3. For configure, verify `--host` matches the target triplet

### Configure Can't Find Compiler

If configure fails with "C compiler cannot create executables":

1. The cross-compiler may not be able to create executables for the host system
2. Add `--enable-static` to avoid linking tests
3. Check that the compiler's target matches the `--host` triplet

## Advanced: Multiple Build Systems

Some projects support multiple build systems. You can specify which to use:

```bash
# Force CMake even if configure exists
mulle-make --plugin cmake install

# Force configure even if CMakeLists.txt exists
mulle-make --plugin configure install
```

## See Also

- [mulle-make documentation](README.md)
- [CMake cross-compiling](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html)
- [Autoconf cross-compilation](https://www.gnu.org/software/autoconf/manual/autoconf-2.69/html_node/Specifying-Target-Triplets.html)
- [Meson cross-compilation](https://mesonbuild.com/Cross-compilation.html)
