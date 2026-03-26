## PVRemappableController — Handler Chaining Rules (added PR #3529)

When reviewing changes to `PVRemappableController.swift` or any code that installs
`GCControllerButtonInput.valueChangedHandler` / `pressedChangedHandler`, check:

### 1. No clobbering of the remapping pipeline
`setupButtonRemappingHandlers(on:)` installs `valueChangedHandler` on every button
including `buttonOptions`. Any subsequent `setupXxxFeatures` method that also sets
`valueChangedHandler` on the same button object **overwrites** the remapping pipeline.

**Rule:** Special-feature setup methods (`setupDualSenseFeatures`, `setupDualShockFeatures`,
`setupXboxFeatures`, `setupSwitchFeatures`) must NOT set `valueChangedHandler` on
`buttonOptions`. That button is owned by the remapping pipeline.

### 2. Platform-aware ButtonIdentifier for buttonOptions
`setupButtonRemappingHandlers` uses a platform-specific `ButtonIdentifier` for `buttonOptions`:
- `GCDualSenseGamepad` → `.createButton` (iOS 14.5+)
- `GCDualShockGamepad` → `.share`
- `GCXboxGamepad` → `.shareButton`
- Generic `GCExtendedGamepad` → `.options`

If you add support for a new controller type with a special options button, add a
branch here AND update `identifier(for:)` to return the matching case.

### 3. No double events from handleSpecialButton
`handleSpecialButton(_:)` must only call `valueChangedHandler` (press + release).
Calling `pressedChangedHandler` in addition doubles events when both handlers are set.

### 4. button(for:id:on:) identity rules
- `.micButton` → `dualSense.buttonMicrophone`  (NOT `buttonOptions`)
- `.createButton` → `dualSense.buttonOptions`
- `.share` → `dualShock.buttonOptions`
- `.shareButton` → `xbox.buttonOptions`
These must not alias each other.
