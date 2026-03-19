# RetroArch Script Tests

Shell test suite for `get-modules.sh` and `make_frameworks_retroarch.sh`.

## Running

```bash
cd CoresRetro/RetroArch/scripts/tests
bash run_tests.sh
```

Tests use a self-contained harness with no external dependencies. They mock `curl`, `xxd`,
`file`, `codesign`, `vtool`, and `lipo` via PATH overrides so network access is not required.

## Test Approach

The suite contains two complementary layers:

**Unit tests** (most tests) — exercise isolated validation logic inline (zip magic
checking, threshold arithmetic, date-format validation) without invoking the real scripts.
These are fast and dependency-free.

**Integration tests** (prefixed `test_integration_`) — invoke `get-modules.sh` and
`make_frameworks_retroarch.sh` directly in a controlled temp directory with mocked system
tools. These catch regressions where the real scripts diverge from the unit-tested logic.

## Test Coverage

### `test_get_modules.sh`
- Happy path: mocked downloads succeed → dylibs created, exit 0 (integration)
- All downloads fail → below 80% threshold → exit 1 (integration)
- Valid zip passes magic-byte validation
- HTML 404 page fails validation and is removed
- Partial failure: valid zips survive, HTML removed
- 80% download threshold: 90% passes, 70% fails, exact 80% passes, 0% fails
- Pinned date format: valid YYYY-MM-DD accepted, invalid rejected, inline comments rejected
- Pinned date URL: HTTP 404 → fallback to latest, HTTP 200 → pin kept
- Zero dylibs detected, non-zero dylibs counted
- Corrupt/truncated zip detected and removed

### `test_make_frameworks.sh`
- Happy path: valid Mach-O dylibs → frameworks created, exit 0 (integration)
- Empty modules dir → exit 1 (integration)
- Valid Mach-O dylib accepted
- HTML/corrupt dylib rejected
- Framework executable present: validated
- Framework executable missing: detected as failure
- Count below 80% threshold: warning logged
- Count above 80%: no warning
- 0 frameworks from N dylibs: would exit 1
- 0 dylibs caught at entry check
- Multiple dylibs: all frameworks created end-to-end
