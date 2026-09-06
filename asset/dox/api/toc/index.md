# mulle-make Library Documentation for AI
<!-- Keywords: build, buildtool, cmake, definition, make, configure, cross-platform -->
## 1. Introduction & Purpose

**mulle-make** is a cross-platform command-line build orchestrator written in
Bash. It automatically detects which build system a project uses — `configure`,
`autoconf`, `cmake`, `meson`, `make`, `xcodebuild`, or a custom `script` — and
invokes it with the correct flags, compiler, and cross-compilation settings for
the target platform (Android, BSDs, Linux, macOS, SunOS, Windows/MinGW/WSL).

- **Problem solved:** You no longer write `mkdir build && cmake .. && ninja`
  yourself or maintain per-platform build invocations. mulle-make guesses the
  build system, sets up the build directory, emits per-tool flags, and records
  the build output into per-tool log files.
- **Key features:**
  - Automatic build-system detection (by probing for `CMakeLists.txt`,
    `meson.build`, `configure.ac`, `configure`, etc.).
  - A persistent, shareable *definition* system (default
    `.mulle/etc/craft/definition`) layered on top of environment variables.
  - Per-build-tool log files under `build/.log/` (access via `mulle-make log`).
  - Unified cross-compilation/toolchain support that translates a toolchain
    name into the native format of each build system.
  - Preference flags for dynamic/static libraries and Debug/Release builds.
- **Relationship:** A "Craft" (build) component of the `mulle-sde` toolchain.
  It depends on `mulle-env` for environment/tool handling and on
  `mulle-bashfunctions` for its shell function framework.

## 2. Key Concepts & Design Philosophy

- **Detect, then delegate:** mulle-make is a thin orchestration layer. It never
  compiles anything itself — it finds the build system and constructs the exact
  command line for it, then runs it.
- **Unified directory convention:** It operates on a fixed layout:
  `src/` directory from the project root (actual sources in a `src/` subdir),
  a `build/` build directory, and a `build/.log/` log directory. Everything is
  `cd`-ed relative to the project root and the build dir.
- **Definitions are the configuration currency:** Rather than depending on
  environment variables (except `CC`, `CXX`, `MAKE`, and the standard
  `CFLAGS`/`CXXFLAGS`/`LDFLAGS`/`OTHER_*` flags), users configure builds through
  *definitions* stored in definition directories. Environment variables form the
  base layer; definition directories layer on top; command-line `-D` options
  override. `--clobber` discards the environment and prior layers.
- **`+=` and `xcode-additive`:** Most build tools overwrite flag variables, but
  `xcodebuild` needs additive `+=` definitions. mulle-make tracks *plus keys* so
  the same logical definition can be emitted appropriately per tool.
- **Log-first diagnostics:** Every build step (`configure`, `make`, etc.) is
  redirected to a numbered per-tool logfile under `build/.log/`, plus a `.count`
  file. Build failure messages point at these logs, and `mulle-make log` greps
  or cats them.

## 3. Core API & Data Structures

mulle-make's "API" is its command-line surface. The canonical command list and
flags are authoritative in the built-in help (`mulle-make -v help`,
`mulle-make <command> -h`) and are reproduced here verbatim where possible.

### 3.1. Top-level invocation

```
mulle-make [flags] [command] [options]
```

**Global flags:**
```
   --args <file> : read the commandline from <file>. Must be only option.
   --clear       : clear all DEFINITION_ variables defined in environment
   -f            : force operation
   -ld           : additional debug output
   -le           : additional environment debug output
   -lt           : trace through bash code
   -lx           : external command execution log output
   -n            : dry run
   -s            : be silent
   -v            : be verbose (increase with -vv, -vvv)
```

**Commands** (`mulle-make <command>`): `project` (default), `definition`,
`install`, `libexec-dir`, `list`, `log`, `show`, `uname`, `version`.

### 3.2. `project` (default) — build a project

```
mulle-make project [options] [directory]
```

Builds the project in `directory` (default: current directory). At its simplest,
`mulle-make` is a shortcut for `mkdir build; cd build; cmake ..; make; cd ..`.

**Build options (shared by `project`, `install`, and `list`):**
```
   --build-dir <dir>          : specify build directory
   --debug                    : build with configuration "Debug"
   --definition-dir <path>    : specify definition directories (multi-use)
   --dynamic                  : prefer dynamic library output
   --include-path <path>      : specify header search PATH, separated by :
   --library-path <path>      : specify library search PATH, separated by :
   --mulle-test               : build for mulle-test
   --no-ninja                 : prefer make over ninja
   --prefix <prefix>          : prefix to use for build products e.g. /usr/local
   --release                  : build with configuration "Release" (Default)
   --show-log-info            : print log file paths before each build step
   --verbose-make             : verbose make output
   -D<key>+=<value>           : append a += definition for the buildtool
   -D<key>=<value>            : set the definition named key to value
   -j <cores>                 : number of cores parameter for make (64)
```

**Relevant environment variables (base layer for definitions):**
`CC`, `CXX`, `MAKE`, `CFLAGS`, `CXXFLAGS`, `LDFLAGS`, `OTHER_CFLAGS`,
`OTHER_CXXFLAGS`, `OTHER_LDFLAGS`.

### 3.3. `definition` — manage build definitions

```
mulle-make definition [option] <command>
```

Subcommands: `cat`, `export`, `get`, `list`, `unset`, `set`, `show`, `write`.

- **`set`:** `mulle-make definition set [option] <key> <value>` sets a build
  setting. Environment variables (`CFLAGS`, `LDFLAGS`, ...) are the base.
  Multiple `--definition-dir` layers append to each other.
  Options: `--clobber` (remove environment + previous definitions),
  `--concat` (append to previous value within same definition),
  `--xcode-additive` (emit `+=` for xcodebuild), `--append` (default, no-op),
  `--ifempty` (only set if no value exists yet).
- **`get`:** `get <key>` echoes a value to stdout. Exit codes: `0` found,
  `1` error, `2` not found.
- **`unset`:** `unset <key>` removes a build setting.
- **`cat`:** show definition file contents.
- **`export`:** `export [dir]` prints definitions as `mulle-make definition`
  commands (option `--export-command <prefix>` to change the emitted prefix).
- **`show`:** list all builtin keys, excluding plugin-specific ones (75 keys
  incl. `CC`, `CFLAGS`, `CMAKE_*`, `CONFIGURATION`, `OTHER_*`, `PREFIX`,
  `PREFERRED_LIBRARY_STYLE`, `TOOLCHAIN`, `SDK`, `USE_NINJA`, ...).
- **`write`:** `write <dir>` merges multiple definition dirs / options and writes
  them into a new directory.

Definition-specific options: `--definition-dir <path>` (default
`.mulle/etc/craft/definition`), `-D<key>=<value>`, `-D<key>+=<value>`.

### 3.4. `install` — build and install

```
mulle-make install [options] [src] [dst]
```

Builds the project in `src`, installs results to `dst` (default `/tmp`). If
`--prefix` is given, do not also pass `dst`. Example:
`mulle-make install "/home/nat/src/mulle-buffer" /tmp/usr`.
Shares the full build-options list of `project`, plus `--prefix`.

### 3.5. `list` — resolve definitions without building

```
mulle-make list [options]
```

Does not build; prints the merged/composed definition values at "build time" so
you can see how layered flags and `--clobber`/append options compose. Shares the
build-options list of `project`.

### 3.6. `log` — inspect build logs

```
mulle-make log [options] [command]
```

Operates on the `build/.log/` directory. Subcommands: `list`, `clean`, or any
tool command (`cat` default, `grep`, `ack`). `mulle-make log grep 'error:'`
greps through all project logs. Option: `-t <tool>` restricts to a tool.

### 3.7. `show` / `uname` / `libexec-dir` / `version`

- **`show`:** prints the supported buildtools: `autoconf`, `cmake`, `configure`,
  `make`, `meson`, `script` (and `xcodebuild` on platforms where present).
- **`uname`:** `mulle-make uname` prints mulle-make's simplified `uname(1)`
  output (e.g. `linux`).
- **`libexec-dir`:** prints the path of the mulle-make libexec directory
  (source `src/` in development, `libexec/` when deployed).
- **`version`:** prints the mulle-make version (e.g. `3.1.0`).

### 3.8. Build-tool plugins (`src/plugins/`)

Each supported build system has an adapter: `autoconf.sh`, `cmake.sh`,
`configure.sh`, `make.sh`, `meson.sh`, `script.sh`, `xcodebuild.sh`. These map
the generic definitions (`OTHER_CFLAGS`, `CMAKE_*`, `CONFIGUREFLAGS`,
`MESON_*`, `XCODE_XCCONFIG_FILE`, ...) onto the tool's native flags. Plugin
selection is determined by build-system detection and `PLUGIN_PREFERENCES`.

### 3.9. Cross-compilation / toolchain

Cross-compilation is configured through `--toolchain`,
`TOOLCHAIN_CMAKE`, `TOOLCHAIN_MESON`, and `TOOLCHAIN_TOOLS_ROOT`. A toolchain
name follows the pattern
`toolchain--<build>-<host>--<triplet>--<compiler>.cmake`, e.g.
`toolchain--linux-windows--x86_64-w64-mingw32--mulle-clang.cmake`. Tools are
discovered under `${TOOLCHAIN_TOOLS_ROOT}/bin/` (`clang`/`gcc`, `clang++`/`g++`,
`llvm-ar`/`ar`, `llvm-ranlib`/`ranlib`, `llvm-strip`/`strip`). See
`CROSSPLATFORM.md` for the full details.

## 4. Performance Characteristics

- mulle-make itself is a light Bash orchestrator; its runtime cost is dominated
  by the underlying build tool. No significant data structures — it is
  O(build steps) in work and O(1) in state per definition key.
- Parallel build throughput is delegated to the tool via `-j <cores>` (default
  64) for `make`/`ninja` and through `USE_NINJA` when a project supports it
  (`--no-ninja` opts back out).
- **Thread-safety:** Not a library — a CLI. Each invocation is a separate
  process and does not share mutable state. Parallel `mulle-make` runs on the
  same project are not supported (mirroring the general mulle-sde guidance to
  avoid running tool commands in parallel).
- Definition resolution is additive over layers (environment → definition dirs
  → command line), so resolution cost grows linearly with the number of
  definition directories.

## 5. AI Usage Recommendations & Patterns

- **Best Practices:**
  - Prefer the `definition` command and definition directories over exporting
    environment variables, except for the documented `CC`/`CXX`/`MAKE`/`CFLAGS`
    base flags.
  - Use `mulle-make definition set --clobber <key> <value>` to fully override an
    environment variable rather than appending to it.
  - Use `mulle-make list` to debug how layered definitions compose before
    actually building.
  - Route flags that must apply to every tool through the `OTHER_*` family
    (`OTHER_CFLAGS`, `OTHER_CXXFLAGS`, `OTHER_LDFLAGS`, `OTHER_CPPFLAGS`) when
    possible.
  - Prefer `--prefix` over the positional `dst` argument for `install`.
- **Common Pitfalls:**
  - Do not pass both `--prefix` and a positional `dst` to `install`.
  - `-D<key>+=<value>` (plus/`+=`) definitions are used by `xcodebuild` only;
    for other tools this may behave differently than appending.
  - Definitions are composed additively; if a value is unexpectedly "sticky,"
    an earlier definition directory or environment variable is the base — use
    `--clobber` to reset.
  - Build log locations are per-tool and numbered under `build/.log/`; failing
    to read the logs (`mulle-make log`) hides the real error the tool emitted.
- **Idiomatic Usage:** The mulle-sde way is to keep persistent definitions in
  the project's `.mulle/etc/craft/definition` directory so that `mulle-make`
  (and `mulle-sde craft`) recover them across machines and developers, and to
  let build-system *detection* decide the tool rather than pinning one manually.

## 6. Integration Examples

### Example 1: Basic project build (auto-detected cmake)

```bash
# In a directory containing a CMakeLists.txt:
mulle-make
# Equivalent to: mkdir build && cd build && cmake .. && ninja && cd ..
```

### Example 2: Inspect how layered definitions compose (via `list`)

```bash
export CFLAGS="-Wall"
mulle-make definition --definition-dir a set CFLAGS "-m32"
mulle-make definition --definition-dir b set --append CFLAGS "-fPIC"
mulle-make list --definition-dir a --definition-dir b
# Shows the composed CFLAGS across environment, dir a, then dir b.
```

### Example 3: Set persistent build definitions

```bash
mulle-make definition set --clobber CFLAGS "-g -O0"
mulle-make definition set PREFIX "/usr/local"
mulle-make definition --xcode-additive set ENABLE_FOO "1"
mulle-make definition get PREFIX
# -> /usr/local
```

### Example 4: One-off build with custom flags and prefix

```bash
mulle-make -DXDEBUG=1 -DOTHER_CFLAGS='-fPIC' --prefix /opt/myapp --debug
```

### Example 5: Build and install in one step

```bash
mulle-make install --prefix /usr/local ./example-project
```

### Example 6: Inspect build logs for errors

```bash
mulle-make log list
mulle-make log grep 'error:'
```

## 7. Dependencies

mulle-make's declared external dependency:

- `mulle-env` (environment/tool suite used for tool resolution and
  cross-compilation toolchain environment)

It is also built on the shared `mulle-bashfunctions` shell framework (used by
the `test/run-test` wrappers) and integrates with the broader `mulle-sde`
"reflect/craft" cycle.

## 8. Shortcut

No `asset/dox/api/toc/index.md` existed previously (no prior commit), so this
document is authored from scratch against the current tree (version 3.1.0).