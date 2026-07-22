# Cross-Compilation Support

mulle-make supports cross-compilation through toolchain configuration. This works across all build plugins (cmake, configure, make, script).

## Configuration

Set these definitions to enable cross-compilation:

```bash
mulle-make definition set TOOLCHAIN "aarch64-linux-gnu-gcc"
mulle-make definition set TOOLCHAIN_TOOLS_ROOT "/usr/local/crossdev/aarch64-linux-gnu"
```

Or in definition files (`.mulle/etc/craft/definition`):

```
TOOLCHAIN=aarch64-linux-gnu-gcc
TOOLCHAIN_TOOLS_ROOT=/usr/local/crossdev/aarch64-linux-gnu
```

## Toolchain Naming Convention

Toolchain names follow the pattern: `<triplet>-<compiler>`

Examples:
- `aarch64-linux-gnu-gcc`
- `arm-linux-gnueabihf-clang`
- `x86_64-w64-mingw32-gcc`

The triplet is used to locate cross-compilation tools:
- `<triplet>-gcc` / `<triplet>-clang` - C compiler
- `<triplet>-g++` / `<triplet>-clang++` - C++ compiler
- `<triplet>-ar` / `llvm-ar` - Archiver
- `<triplet>-ranlib` / `llvm-ranlib` - Index generator
- `<triplet>-strip` / `llvm-strip` - Symbol stripper

## Plugin Behavior

### cmake plugin
- Passes `--toolchain <file>` to cmake
- Exports `MULLE_CROSS_COMPILER_ROOT` to cmake process
- Requires toolchain for cross-platform builds

### configure plugin
- Exports `CC`, `CXX`, `AR`, `RANLIB`, `STRIP` to configure script
- Tools are located in `TOOLCHAIN_TOOLS_ROOT`

### make plugin
- Exports `CC`, `CXX`, `AR`, `RANLIB`, `STRIP` to make process
- Tools are located in `TOOLCHAIN_TOOLS_ROOT`

### script plugin
- Exports `CC`, `CXX`, `AR`, `RANLIB`, `STRIP` to build script
- Exports `MULLE_TOOLCHAIN_TOOLS_ROOT` to build script
- Tools are located in `TOOLCHAIN_TOOLS_ROOT`

## Example

Cross-compile for ARM64 Linux:

```bash
mulle-make definition set TOOLCHAIN "aarch64-linux-gnu-gcc"
mulle-make definition set TOOLCHAIN_TOOLS_ROOT "/usr/aarch64-linux-gnu"
mulle-make --platform linux
```

For cmake projects with a toolchain file:

```bash
mulle-make definition set TOOLCHAIN "cmake/toolchains/aarch64-linux.cmake"
mulle-make definition set TOOLCHAIN_TOOLS_ROOT "/usr/aarch64-linux-gnu"
mulle-make --platform linux
```

## Build Script Contract

Build scripts invoked by the script plugin receive these environment variables for cross-compilation:

- `CC` - C compiler path
- `CXX` - C++ compiler path
- `AR` - Archiver path
- `RANLIB` - Index generator path
- `STRIP` - Symbol stripper path
- `MULLE_TOOLCHAIN_TOOLS_ROOT` - Root directory of toolchain tools

