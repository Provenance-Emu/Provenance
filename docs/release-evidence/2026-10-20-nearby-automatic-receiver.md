# Provenance nearby automatic receiver — 2026-10-20

This is source/native evidence, not two-device acceptance or a shipping claim. Parent checkout has unrelated dirty work, deliberately preserved. No commit, workspace-pin update, app/core build, simulator or device mutation was performed by this work.

## Direction and release scope

| Direction | Manual ROM copy | Automatic nearby ROM copy |
| --- | --- | --- |
| Provenance → iCube | Existing `ICubeDialectServer` and iCube receiver | Existing server consumed by the new iCube automatic adapter; iCube evidence belongs to its separate checkout |
| iCube → Provenance | Existing protocol source; now uses confirmed import for the iCube path | New opt-in receiver, using the same source and importer |

Both apps must remain open nearby. Subscriptions use paired stable advertisement peer IDs. The receiver never initiates pairing; missing/revoked host pairing fails visibly. Only a playable single iCube ROM image is imported. BIOS/saves are left at the source. Removing a subscription, source or remote entry never deletes local games.

Custom metadata convergence is **not implemented** by ROM copying. The current catalogue/art routes expose source title and artwork; the current importer derives local metadata and does not apply those remote overrides. Tags have no wire field. Cross-app title/cover/tag editing therefore remains a release contract gap, owned separately by the parent task.

## Implementation

- `PVLibrarySharing/Transfer/AutomaticLibraryReceiver.swift`: Foundation scheduler, explicit per-peer opt-in, foreground/emulation/trust gates, one owned task, cancellation ownership retained until delegate exits, periodic discovery checks. A blocked entry remains visible while other additions continue.
- `LibraryReceiveSerialExecutor.swift`: cancellation-aware app-wide lease for manual/automatic iCube transfer through confirmed import.
- `ICubeContinuitySource.swift`: expected advertisement peer ID checked before authentication proof and code pairing; strict iCube-only ROM manifest validation before the shared decoder can drop userdata fields; iCube file-download idle deadline 135 seconds accommodates the existing 120-second owner approval, while ordinary requests keep their normal timeout.
- `LibraryStaging.swift` / `LibraryPuller.swift`: descriptor and partial-path confinement, symlink escape rejection at descendant, files-base and hashed-folder levels before manifest writes, full staged-file digest revalidation, fresh-manifest handling, cancellation checked after an uncooperative download and before finalizing bytes.
- `NearbyLibraryReceiveService.swift`: observes actual `ImportQueueItem` terminal state; no fixed delay or global completion-handler replacement. A skipped/non-enqueued item cannot falsely succeed. Success requires Realm registration, all registered files, SHA-256 matching the offered ROM, and stable file stats during hashing. Fingerprints use device/inode/size plus mtime/ctime seconds and nanoseconds through uncached `lstat`; an identical size and restored mtime cannot hide replacement or in-place edits. Later receipts require fresh manifest descriptors, the same registration paths, and all actual file stats; stale Realm rows after cache eviction do not count as present.
- `ImportQueueClaim.swift` / `ImportQueueItem.swift` / `GameImporter.swift`: queued-only cancellation by stable IDs, synchronized against worker claim. No file deletion/rollback. Started imports retain the physical lease until terminal. Terminal queue history no longer rejects restoring the same staging path; live duplicates remain blocked.
- `NearbyLibraryAutomaticService.swift`: independent iCube browser and persisted source opt-ins/receipts; pauses on inactive/background on both iOS/tvOS, emulation, bootstrap and feature-flag gates. `LibrarySharingService` forwards its existing scene handler; dirty `ProvenanceApp.swift` remains untouched.
- `NearbyLibrariesModel.swift`: successful outbound code pairing persists the accepted host ID/name/public key; iCube manual copies share the automatic receiver's confirmation/lease path. Existing other-dialect import paths remain as before.
- `AutomaticLibraryCopySettingsView.swift` / `NearbyLibrariesView.swift`: paired-source toggles, status, retry and stop controls; explicit nearby/open-app/additive behavior.

## Native evidence

- `swift test --package-path PVLibrarySharing --disable-automatic-resolution --jobs 2`: 140 tests passed after source fixes (baseline 123). Includes scheduler opt-in/presence/foreground/emulation/cancellation/revocation, transfer gate ownership, source identity, staging path and post-download cancellation regressions.
- `python3 Scripts/tests/test_import_queue_claim.py`: 4 tests passed, including 100 concurrent queued-cancel/worker-claim races. This compiles the actual production claim helper and its checked-in unit tests.
- `python3 Scripts/tests/test_nearby_import_completion.py`: extracts the actual production app completion bridge and actual queue duplicate method into a small native module with API stand-ins. Red: 5 tests, 1 expected failure for terminal queue history; bridge success and both cancellation paths passed. Final green: 7 tests, 0 failures. These include terminal-history retry, live-duplicate blocking, missing secondary/registration/source mismatch, and same-size replacement with restored mtime. The intermediate receipt test also reproduced Foundation URL resource-values caching after deletion; uncached `lstat` fixed it.
- Durable final logs: [sharing package — 140 passed](2026-10-20-native/pv-library-sharing.log), [app completion/receipt helpers — 7 passed](2026-10-20-native/nearby-import-completion.log), [import queue claim — 4 passed](2026-10-20-native/import-queue-claim.log). Final package safety red: `/tmp/provenance-nearby-base-safety-red.log` (10 expected assertions before base/strict-manifest fixes).
- `swiftc -frontend -parse` on the six changed/new nearby app implementation files passed. This is syntax evidence only; conditional app code still requires a full PVUI typecheck through Xcode.
- Removed unused `PVPrimitives` dependency from the pure sharing package after source search showed no imports/public reexports/types. This allowed the actual native package tests; workspace pins were not changed.

## Remaining acceptance gates

1. Parent review of these dirty parent files and app target compile on both iOS/tvOS, with existing parent bootstrap/app changes included.
2. Real iCube/Provenance foreground pairing, manual import and automatic opt-in in both directions; owner approval delay, wrong code, revocation, discovery denial and network interruption.
3. Background/emulation/Stop during queued and started imports; cancellation may preserve a started completed local import, but cannot falsely report a receipt or start a replacement concurrently.
4. Cache eviction/restoration, identical no-op, same-name/different-ROM collision preservation, and source addition/removal with all local copies preserved.
5. Resolve and test the separate custom title/cover/tag cross-app metadata contract.

No separate parent issue was created from this subtask; parent owns issue creation and dirty-parent review before commit/push.
