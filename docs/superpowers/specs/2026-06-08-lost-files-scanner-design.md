# Lost Files Scanner (Library Health) — Design

**Date:** 2026-06-08
**Status:** Approved design — ready for implementation plan
**Module home:** `PVLibrary` (engine + scanner), `PVUIBase`/`PVSwiftUI` (UI), `PVSettings` (flag)

## Problem

Users struggle to place ROM files correctly — especially multi-disc sets
(`.cue`+`.bin`, `.m3u` playlists), and they drop files in the wrong place
(Documents root, `ROMs/` root, `BIOS/` root, the wrong system folder). The
app also accumulates orphaned files (on disk but never recorded in the DB),
leftover archives, and stray large blobs (hung caches, partial extracts).
There is currently **no** disk-vs-DB reconciliation anywhere in the app.

This feature adds a **Library Health scanner** that finds these problems at
key moments and either **auto-fixes the unambiguous cases** or **alerts the
user with a one-tap fix** for the ambiguous/destructive ones.

## Posture

**Hybrid:** silently auto-fix the unambiguous (with a visible, undoable
receipt), alert for everything ambiguous or destructive. Never delete
silently. Every auto-fix is reversible for the session; every delete is
recoverable for 7 days.

## Scope (v1)

In scope — detection categories:

| Cat | Name | Condition | Default action |
|-----|------|-----------|----------------|
| **A** | Misplaced ROM | ROM-extension file in `ROMs/` root, Documents root, or the wrong system folder | unambiguous system → **auto-fix** to `ROMs/<sys>/`; multiple candidate systems → **alert** w/ system picker |
| **B** | Misplaced BIOS | known BIOS file outside `BIOS/` | **auto-fix** → `BIOS/` (via `Imports/` staging, see §4) |
| **C** | Orphaned ROM | ROM in a correct system folder but absent from the DB | **auto-fix** → register in place |
| **D** | Multi-disc fragment | `.cue` referencing a missing `.bin`; `.bin` with no referencing `.cue`; `.m3u` with missing disc members | **alert** (never auto-guess) |
| **E** | Junk | unclassifiable files, archive leftovers, `.part` / `.tmp` / `.DS_Store` | **alert** + confirmed quarantine-delete |
| **F** | Large blob | file `> largeFileThreshold` matching nothing | **alert** w/ size + confirmed quarantine-delete |

Explicitly **out of scope for v1** (designed-for, not built):

- **DB→disk dangling references** (a DB row whose file is missing). v1 scans
  **disk → DB** only. The inverse pass must respect CloudKit `isDownloaded ==
  false` placeholders (see §5) and is deferred.
- Permanent fix history (the Fixed log is session-scoped).
- Auto-resolution of D fragments.

## Architecture

Three units, each independently understandable and testable.

### `LibraryHealthScanEngine` (pure, no UIKit, no I/O side effects)
- **Input:** a snapshot of on-disk files (URL + size + parent-dir role), a
  DB-truth set (referenced file paths), and cue/m3u parse results.
- **Output:** `[LibraryHealthFinding]`, each tagged with category, suggested
  action, candidate systems, and an `autoFixable` flag.
- **No file moves, no Realm access, no FileManager calls** — it is given
  data and returns findings. This is the unit-test surface.
- Home: `PVLibrary/Sources/PVLibrary/Services/LibraryHealth/`.

### `LibraryHealthScanner` (`@MainActor`, `ObservableObject`, `PausableService`)
- Coordinator. Gathers the disk snapshot + DB-truth off-main (cancellable
  `Task`), invokes the engine, publishes `ScanResult`, and **executes**
  auto-fixes by routing through the importer (§4).
- Conforms to **`PausableService`** (PVPrimitives) and registers with
  **`BackgroundServiceRegistry`** — so it auto-pauses on `pauseAll(reason:
  .emulation)` and resumes on emulation stop, exactly like `DirectoryWatcher`
  / `CloudKitDownloadQueue`. `pause(reason:)` cancels/suspends an in-flight
  walk; nothing runs during gameplay.
- Home: `PVLibrary/Sources/PVLibrary/Services/LibraryHealth/`.

### UI: `LostAndFoundView` + `LostAndFoundViewModel`
- Home: `PVUIBase/Sources/PVUIBase/SwiftUI/Imports/` (next to
  `ImportStatusView`), reusing the retrowave tile style.

## Data model

```
enum LibraryHealthCategory { misplacedROM, misplacedBIOS, orphanedROM,
                             multiDiscFragment, junkFile, largeUnmappedFile }

enum LibraryHealthAction { move(to: URL), reimport(system: SystemIdentifier),
                           registerInPlace(system: SystemIdentifier),
                           quarantineDelete, chooseSystem, ignore }

struct LibraryHealthFinding {
    id: UUID
    category: LibraryHealthCategory
    url: URL
    fileSize: Int64
    detectedSystem: SystemIdentifier?       // single, unambiguous
    candidateSystems: [SystemIdentifier]     // >1 → needs user choice
    suggestedAction: LibraryHealthAction
    autoFixable: Bool
    detail: String                           // "in ROMs/ root · 512 KB"
}

struct FixedLogEntry {                       // the undoable receipt
    finding: LibraryHealthFinding
    actionTaken: LibraryHealthAction
    timestamp: Date
    undoToken: UndoToken                     // original URL, or quarantine path
}

struct ScanResult {
    pendingFindings: [LibraryHealthFinding]  // alert cases (D/E/F + ambiguous A)
    fixedLog: [FixedLogEntry]                // session auto-fixes + manual fixes
    lastScanDate: Date
    counts: ...
}
```

## 4. Fix execution — route through the existing importer

Verified against `GameImporter` / `GameImporterFileService`:

- **ROM move (A) and register-in-place (C):** call
  `GameImporter.addImports(forPaths:targetSystem:)` with the resolved system.
  - ROMs use `moveItem` (`GameImporterFileService.swift:484`) which relocates
    and removes the original — so A's misplaced original is not left behind.
  - A **same-path guard** (`:480-487`, `:285-307`) makes C (file already in
    the correct folder) a no-op move that still registers the DB record.
  - `targetSystem` forces placement and skips system detection
    (`GameImporter.swift:894-980`, sets `userChosenSystem`).
- **BIOS (B) — staged through `Imports/`:** `handleBIOSItem` **copies** BIOS
  into `BIOS/` and only deletes the source **if it came from `Imports/`**
  (`:177`, `:189-195`). A misplaced BIOS left elsewhere would re-detect on the
  next scan. **Therefore B moves the file into `Imports/` first, then
  enqueues** — the importer's own cleanup removes the staged original. No
  parallel deletion logic in the scanner.
- The scanner captures the **original URL before** enqueueing, for Undo.

**Why route through the importer:** reuses dedup (filename/romPath, byte-
identity `filesAreByteIdentical`), placement, BIOS notification
(`.BIOSFileFound`), and DB-record creation — instead of a parallel,
divergent file-mover.

### Quarantine (E/F deletes)
- Move to `Documents/.Quarantine/<yyyy-MM-dd>/` plus a manifest
  (original path, deleted date).
- A cleanup pass at the start of each scan purges manifest entries older than
  `quarantineRetentionDays` (7).
- Undo = move back from quarantine to the original path.

### Session Fixed-log + Undo
- Every auto-fix and quarantine-delete appends a `FixedLogEntry`, surfaced in
  the sheet with per-item **Undo**.
- Session-scoped (plus the last `ScanResult`), not permanent history.

## 5. CloudKit safety

Verified: ROM CloudKit record IDs are **MD5/content-derived**
(`CloudKitSchema.romRecordID(md5:)`, `CloudKitSchema.swift:247-253`), **not**
path-derived. Moving a ROM preserves its CloudKit identity — **no orphan/dup
churn** from auto-fix moves.

Exclusions the scanner MUST apply (avoid false positives on in-flight sync):

- Skip any file currently in `SyncProgressTracker` active/queued downloads
  (a partially-downloaded file must not be flagged as E/F junk).
- v1 walks **disk → DB**, so CloudKit `isDownloaded == false` placeholders
  (no file on disk) are naturally not visited. The inverse DB→disk pass is
  deferred precisely because it must honor `isDownloaded`/`GameFileStatusService`.

CloudKit-synced scopes for reference (`CloudKitNonDatabaseSyncer`,
`CloudKitSchema`): ROMs, Save States, BIOS, Battery States, Screenshots,
Cheats, (DeltaSkins when enabled).

## 6. Triggers

All gated by `Defaults[.libraryHealthScanEnabled]` (PVSettings, default
**true**) and by **importer idle** (see guards below).

| Trigger | Scan | Throttle |
|---------|------|----------|
| **App boot / first library load** | full | once per launch, after Realm loads, off-main |
| **Post-import** | full | on `GameImporter.processingState → .idle` after real activity, debounced |
| **Background-return on Library/Home** | full | only if `> backgroundRescanInterval` (30 min) since last scan **and** the library is dirty (see §7) |
| **Manual** | full | none — Settings row "Scan Library for Lost Files" + pull-to-scan in the sheet |

### Importer-coordination guards (from review)
- **Gate every trigger on `GameImporter.processingState == .idle`** — not just
  the post-import one. If the importer is mid-flight, defer/skip (a half-copied
  file must not be flagged as a blob; a `.bin` landing before its `.cue` must
  not be flagged as a D fragment).
- **Exclude `Imports/`** (the importer's staging inbox) and **any path
  currently in the import queue** from the disk walk — that directory is the
  importer's by design.

## 7. Background-return change signal

- Primary: a **dirty flag** set whenever `DirectoryWatcher` or the CloudKit
  download queue writes into a scanned directory. More reliable on iOS than
  directory mtime (CloudKit writes and move semantics make mtime noisy).
- Fallback heuristic: directory mtime delta. Treated as a v1 heuristic only —
  the spec does not promise mtime precision.

## 8. UI integration

Reuses the existing floating import surface (`ImportProgressView` /
`ImportStatusView`, driven off `GameImporter.importQueuePublisher`, overlaid
via `fullScreenCover` on `ConsoleGamesView:485-499` and `HomeView:295-305`).

- **Floating widget:** when `pendingFindings` is non-empty, show a distinct
  **"N items need attention"** pill (retroPink/orange), tappable.
- **`ImportStatusView` segmented section:** `Importing | Library Health`. The
  Library Health pane lists findings (category icon, filename, `detail`,
  actions: **Fix / Choose System / Delete / Ignore**) plus a collapsible
  **Fixed** log with per-item **Undo**.
- **Settings entry** presents the same view standalone for on-demand scans.
- Retrowave styling: black `opacity(0.7)` tiles, pink→blue gradient borders,
  glow shadows — matching `ImportTaskRowView` / `RetroTheme`.

## 9. Constants (no magic numbers)

- `largeFileThresholdBytes`
- `backgroundRescanInterval = 30 * 60`
- `quarantineRetentionDays = 7`
- quarantine root: `Documents/.Quarantine/`
- junk extensions / dotfile set: `.part`, `.tmp`, `.DS_Store`, archive
  leftovers (curated constant)

## 10. Testing

- `LibraryHealthScanEngine` is pure → unit tests in PVLibrary for each
  category (A–F) from synthetic disk+DB inputs, including ambiguous-system A
  (alert) vs unambiguous A (auto-fix), and the importer-idle/`Imports/`
  exclusion logic at the snapshot-building layer.
- Quarantine retention purge logic (7-day boundary) unit-tested.
- Undo round-trip (move-back, quarantine-restore) unit-tested at the model
  layer.
- tvOS parity: no `DragGesture` / haptics / orientation APIs — reuse existing
  import-UI patterns that already build on tvOS. Verify iOS + tvOS compile.

## Multi-platform / conventions

- iOS 17+, tvOS 17+, macOS 14+ (Catalyst), visionOS. All UI compiles on iOS
  **and** tvOS.
- Use `SystemIdentifier` enum, never raw `com.provenance.*` strings.
- Foundation-only in the engine (Linux-testable where the module allows).

## Companion task (separate PR, NOT part of this spec)

Amazon/associate links in the **About** tab: a "Support / Recommended Gear"
group inside `SocialLinksSection` (`SettingsSwiftUI.swift`), using the existing
`Link + SettingsRow` pattern. Amazon Associates links to **physical goods**
are generally App-Store-permitted, so shown on all builds, but behind a single
constant flag (separate from `isAppStore`) for a one-line disable if review
objects. The Associate tag is `provenance09-20` (append `?tag=provenance09-20`).
Tracked separately to keep this spec focused.
