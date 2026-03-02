---
applyTo: "**/*Bridge+Controls.mm"
---

## Emulator Core Bridge Standards

These files map `GCController` input to emulator-specific button constants. Follow these rules:

1. **All controller types must be handled** — `GCExtendedGamepad`, `GCMicroGamepad`, and `GCKeyboard`
2. **Match upstream constants** — button/axis constants must match what the upstream emulator source expects; never invent new values
3. **Never modify upstream source** — files inside `Cores/<name>/<upstream-dir>/` are submodule content; only edit files in the `PV<Core>Core/` bridge layer
4. **Null-safety** — always nil-check `gamepad.controller` and optional button properties before use
5. **Analog vs. digital** — use `.value` for analog axes/triggers; use `.isPressed` for digital buttons

## Validation

Bridge files are compiled only in the full Xcode workspace build. You cannot `swift build` them standalone. Use the CI smoke-build or verify in Xcode:
```bash
xcodebuild build -workspace Provenance.xcworkspace \
  -scheme "Provenance-CI" \
  -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO -quiet
```
