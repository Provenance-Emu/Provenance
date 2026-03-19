# RetroArch Script Tests

Shell script integration tests for `get-modules.sh` and `make_frameworks_retroarch.sh`.

## Running

```bash
cd CoresRetro/RetroArch/scripts/tests
bash run_tests.sh
```

Tests use a self-contained harness with no external dependencies. They mock `curl`, `xxd`,
`file`, and `codesign` via PATH overrides so network access is not required.

## Test Coverage

### `test_get_modules.sh`
- Happy path: valid zips → all dylibs extracted, exit 0
- All 404s (HTML responses) → invalid zips removed, exit non-zero (below 80% threshold)
- Partial failure: some valid, some 404 → valid succeed, exit if below threshold
- Corrupt zip (HTTP 200, not a zip) → detected and removed
- Pinned date validation: invalid format → fallback to latest with warning
- Pinned date URL check: HTTP 404 → fallback to latest, no abort

### `test_make_frameworks.sh`
- Happy path: valid Mach-O dylibs → frameworks created, exit 0
- Empty modules dir → exit 1
- Non-Mach-O dylib (corrupt) → skipped, counted as failure
- Framework executable validation: created successfully
- Counts match within 80% threshold → exit 0
- Counts below 80% → warning logged
