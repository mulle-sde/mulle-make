# mulle-make Definition System

## Overview

mulle-make uses a definition system to manage build settings. Environment variables serve as the base, and definitions can build on top or replace them.

## Environment Variables

### Compiler/Linker Flags (Shadowed - Initialized as Base)

These are initialized at startup: `DEFINITION_CFLAGS="${CFLAGS}"`

| Variable         | Description                    | Shadowed By              |
|------------------|--------------------------------|--------------------------|
| CFLAGS           | C compiler flags               | DEFINITION_CFLAGS        |
| CXXFLAGS         | C++ compiler flags             | DEFINITION_CXXFLAGS      |
| LDFLAGS          | Linker flags                   | DEFINITION_LDFLAGS       |
| CPPFLAGS         | C preprocessor flags           | DEFINITION_CPPFLAGS      |
| OTHER_CFLAGS     | Additional C flags             | DEFINITION_OTHER_CFLAGS  |
| OTHER_CXXFLAGS   | Additional C++ flags           | DEFINITION_OTHER_CXXFLAGS|
| OTHER_LDFLAGS    | Additional linker flags        | DEFINITION_OTHER_LDFLAGS |
| OTHER_CPPFLAGS   | Additional preprocessor flags  | DEFINITION_OTHER_CPPFLAGS|

**Behavior**: Environment is the base. Definitions append unless `--clobber` is used.

Example:
```bash
export CFLAGS="-Wall"
mulle-make definition set CFLAGS "-m32"
# Result: -Wall -m32
```

### Build Tools (Shadowed - Fallback Pattern)

These use fallback: `${DEFINITION_MAKE:-${MAKE}}`

| Variable    | Description        | Shadowed By           |
|-------------|--------------------|-----------------------|
| MAKE        | Make tool          | DEFINITION_MAKE       |
| CMAKE       | CMake tool         | DEFINITION_CMAKE      |
| NINJA       | Ninja build tool   | DEFINITION_NINJA      |
| MESON       | Meson build tool   | DEFINITION_MESON      |
| AUTOCONF    | Autoconf tool      | DEFINITION_AUTOCONF   |
| AUTORECONF  | Autoreconf tool    | DEFINITION_AUTORECONF |
| XCODEBUILD  | Xcodebuild tool    | DEFINITION_XCODEBUILD |

**Behavior**: Definition overrides environment if set, otherwise uses environment.

### Other Shadowed Variables

| Variable    | Description           | Shadowed By           |
|-------------|-----------------------|-----------------------|
| CMAKE_PP    | CMake preprocessor    | DEFINITION_CMAKE_PP   |
| PATH        | Search path           | DEFINITION_PATH       |

### Not Shadowed (Forwarded to Tools)

These are passed directly to underlying build tools without DEFINITION_ handling:

| Variable        | Description                      | Used By           |
|-----------------|----------------------------------|-------------------|
| CC              | C compiler                       | cmake/configure   |
| CXX             | C++ compiler                     | cmake/configure   |
| LD              | Linker                           | cmake/configure   |
| CMAKEFLAGS      | CMake flags                      | cmake             |
| CONFIGUREFLAGS  | Configure script flags           | configure         |
| MAKEFLAGS       | Make flags                       | make              |
| ANDROID_NDK     | Android NDK path                 | cmake             |
| MESON_BACKEND   | Meson backend (ninja/make)       | meson             |

## Definition Behavior

### Multiple Definition Directories

When using multiple `--definition-dir`, values append:

```bash
# def1: CFLAGS=-m32
# def2: CFLAGS=-fPIC
mulle-make project \
  --definition-dir def1/.mulle/etc/craft/definition \
  --definition-dir def2/.mulle/etc/craft/definition
# Result: -Wall -m32 -fPIC (if CFLAGS=-Wall in environment)
```

### Clobber Removes Everything

The `--clobber` flag removes environment and all previous definitions:

```bash
export CFLAGS="-Wall"
mulle-make definition set CFLAGS "-m32"
mulle-make definition set --clobber CFLAGS "-O3"
# Result: -O3 (environment and previous definition removed)
```

### Behavior Matrix

| ENV CFLAGS | def1    | def2    | def3 (--clobber) | Result              |
|------------|---------|---------|------------------|---------------------|
| -Wall      | -m32    | -fPIC   | (none)           | -Wall -m32 -fPIC    |
| -Wall      | -m32    | -fPIC   | -O3              | -O3                 |
| (none)     | -m32    | -fPIC   | -O3              | -O3                 |

## Key Rules

1. **Environment is the base** for *FLAGS variables
2. **Multiple definition dirs append** to each other
3. **--clobber removes everything** including environment
4. **OTHER_CFLAGS** is independent, combined at end: `CFLAGS + OTHER_CFLAGS → CMAKE_C_FLAGS`
5. **Build tools** use fallback pattern (definition or environment)
6. **CC/CXX/LD** are forwarded directly without shadowing

## See Also

- `mulle-make definition set --help` - Set definitions
- `mulle-make definition list` - List current definitions
- `test/09-cflags-combination/` - Test suite demonstrating behavior
