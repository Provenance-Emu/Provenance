# Developer Velocity Roadmap — build speed, debug APIs, web server

**Date:** 2026-10-09 · **Status:** Roadmap (three workstreams, each its own spec + session)

## Why

iFly and iCube iterate in minutes: the emulator core builds outside the app, per platform
slice, cached; the app is Tuist-generated with small focused targets; and an HTTP/WebSocket
automation API (REST + MCP-style) lets a person or an agent drive the app, pull logs and
screenshots, and run scenarios without Xcode attached. Provenance has none of that at the
same quality: the workspace build is slow, custom targets (Lite, UI test app) are hand-edited
pbxproj, the core builds (Azahar 30–40 min/slice, Dolphin 30–60) re-run too often, and
debugging means a paste of Console output. This costs wall-clock and tokens on every change.

## Workstream A — Project generation and fast iteration targets

**Decision:** Tuist, because iCube already runs it (`Source/iOS/App/Project.swift`,
`Tuist.swift`, CI step "tuist generate" in iCube's build.yml) and its lessons are fresh
(xcframework binary targets must resolve before generate; version pinned via mise).
xcodegen stays only where it already is (Cores/Azahar/project.yml) until migrated.

Scope for the spec:
1. `Project.swift` for the app targets (Provenance, Lite, XL, tvOS, extensions) generated
   from one source of truth; the PV* packages stay SwiftPM.
2. **Iteration targets as data:** a `FocusedApp` target template taking a core list and a
   feature-flag set, so "app with only Azahar + the skins UI" is a 10-line addition, and
   a `CoreHarness` target that boots one core headless for tests/screenshots.
3. **Core slices built outside the app, cached per platform:** generalise
   `Cores/Azahar/build_azahar_core.py` + Dolphin's `BuildiOSXCFramework.py` into one
   `Scripts/cores/build_slice.py <core> <platform>` with a content-hash stamp (submodule
   HEAD + flags + toolchain), a shared cache dir, and only the active platform's slice
   built by the aggregate target. CI caches the slice dir keyed on the stamp.
4. Document in CLAUDE.md and a `fast-iteration` skill: how to add a focused target, how to
   build one core slice, how to run a core harness.

## Workstream B — Debug and automation API (port from iCube)

Sources to port: `Cores/Dolphin/dolphin-ios/Source/iOS/PVWebServer/Sources/PVWebServer/`
(`WebRoute`, `WebServerClientMode`, `WebServerLifecyclePolicy`, `WebServerPathSafety`,
`ROMUploadServer`) and `PVContinuity/Sources/PVContinuity/Server/` (`BearerTokenValidator`,
`ByteRangeRequest`, `ContinuityRoutes`, session/library servers, WebSocket frame handling
tested in `WebSocketFrameTests`). iFly has the same lineage; locate its checkout before
writing the spec (not under this workspace).

Scope for the spec:
1. REST + WebSocket endpoints on the existing server: app state, library query, launch
   game by id/md5, core options get/set, pause/resume/quit, save/load state, screenshot,
   log tail/stream, skin/overlay selection, input injection. Bearer token, LAN only.
2. MCP manifest exposing the same, so a Claude session drives a device or simulator
   directly instead of asking the maintainer for pasted logs.
3. `Scripts/dev/pv` CLI wrapping it (`pv launch <md5>`, `pv logs -f`, `pv shot`), used by
   the `run` skill.

## Workstream C — Web server quality and performance (port from iCube/iFly)

Scope for the spec:
1. WebDAV and HTTP on the same port; port detection and jumping at start; always-on
   server while foregrounded, kept alive through active transfers in background, with
   upload/import I/O paused rather than the server stopped.
2. Client compatibility and speed fixes already made in iCube/iFly: Safari/Edge uploads,
   macOS Finder and Windows WebDAV quirks, parallel downloads, range requests
   (`ByteRangeRequest`), streaming multipart, TCP no-delay, serial file writer.
3. Transport security parity ("better encryption" per the maintainer: confirm what iCube
   ships — TLS with a generated cert, or token-only — before specifying).

## Order and sessions

1. **A first** (it makes B and C cheaper to test), as its own session: brainstorm → spec →
   plan → subagent batches. Expect pbxproj churn; land on a branch, verify CI builds all
   variants, then merge.
2. **B and C together** in a second session, since both live in PVWebServer and B's
   endpoints ride C's server lifecycle. Port tests with the code.
3. Each session ends by updating CLAUDE.md and adding/refreshing a skill so later
   sessions use the tooling instead of rediscovering it.

## Related, already open

- Console-style overlays: batches 1–3 bound every system; follow-ups are a device palette
  pass, the 2600 paddle variant, snapshot tests, and deleting the legacy default skin.
- Azahar: scaling-mode hook (`EmulatorCoreScalingModeApplying`), Apple Silicon FastInterp
  work (memory: azahar-apple-silicon-perf-followup), upstream PRs for the fork patches.
