# Test 09: CFLAGS and OTHER_CFLAGS Combination

Tests how mulle-make combines CFLAGS and OTHER_CFLAGS from environment and multiple definition directories.

## Behavior Matrix

| ENV CFLAGS | ENV OTHER_CFLAGS | def1 CFLAGS | def2 CFLAGS | def3 CFLAGS (--clobber) | Result CMAKE_C_FLAGS           |
|------------|------------------|-------------|-------------|-------------------------|--------------------------------|
| undefined  | undefined        | undefined   | undefined   | undefined               | (empty)                        |
| `-Wall`    | undefined        | undefined   | undefined   | undefined               | `-Wall`                        |
| `-Wall`    | `-Wextra`        | undefined   | undefined   | undefined               | `-Wall -Wextra`                |
| `-Wall`    | `-Wextra`        | `-m32`      | undefined   | undefined               | `-Wall -m32 -Wextra`           |
| `-Wall`    | `-Wextra`        | `-m32`      | `-fPIC`     | undefined               | `-Wall -m32 -fPIC -Wextra`     |
| `-Wall`    | `-Wextra`        | `-m32`      | `-fPIC`     | `-O3`                   | `-O3 -Wextra`                  |
| undefined  | `-Wextra`        | `-m32`      | `-fPIC`     | `-O3`                   | `-O3 -Wextra`                  |

## Key Rules

- **Environment is the base**: `DEFINITION_CFLAGS` initialized from `CFLAGS` at startup
- **Multiple `--definition-dir` append**: Each adds to previous
- **--clobber removes everything**: Environment + all previous definitions
- **OTHER_CFLAGS independent**: Combined at end: `CFLAGS + OTHER_CFLAGS → CMAKE_C_FLAGS`

## Usage

```bash
cd test/09-cflags-combination
./run-test          # Run all tests
./run-test -v       # Verbose output
```

Test creates 3 definition directories (def1, def2, def3) and validates all combinations with environment variables.
