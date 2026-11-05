Run on macOS from the repository root:

```sh
python3 Cores/Mupen64Plus/Tests/SaveStateLifecycle/check.py
```

Initialize the pinned Mupen core submodule first. The script compiles the production
save-request code and callback registry directly into a temporary Foundation host.
It substitutes engine command results, so it exercises queue ordering, retries,
completion, cancellation and handler lifetime without starting an emulator.

The never-ready and slow accepted-save cases intentionally cross the production
five-second readiness allowance. Other cases cover initial rejection while already
ready, a future ready event, a failed engine completion, stop before/after acceptance,
nil completion blocks, paused/unpaused restoration, duplicate completion events and
ready events arriving after cancellation. Overlapping requests are tested while
waiting for readiness and after engine acceptance: only the first may schedule;
the second must receive a busy error and the save slot must be released.
Every completed request must remove its
handler; non-nil completions must run exactly once on the main thread.

This test does not prove engine save-file persistence or ROM boot/rendering. Those
require a separate native-core simulator/device save → file → load test.
