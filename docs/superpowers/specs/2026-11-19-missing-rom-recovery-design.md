# Missing ROM recovery from nearby libraries and servers

Date: 2026-11-19, updated 2026-11-20. Status: design, owner direction applied 2026-11-20.

## Why

tvOS keeps the library in Caches and deletes it when it wants the space. iCloud
cannot bring most of those games back: CloudKit assets stop at 500 MB, so
Provenance syncs only smaller ROMs on tvOS, and iCube and iFly sync none.
Today a game whose file is gone and has no cloud copy fails to launch with no
message (`PVEmulatorViewController` logs and dismisses).

All three apps, RomM and the emulator-content-server (ECS) can already serve
ROMs on the LAN. A missing ROM should come back from whichever of them has it.
The same path helps an iOS user who deleted a file by accident.

Owner context: all three apps and ECS launch together shortly. Provenance's
piece must not depend on new builds of the others.

## Goals

- At launch, a game whose ROM is missing is restored from a source that has
  it, then boots, with no steps beyond waiting for the copy.
- Every copy asks first, with an Always Allow that makes later exact
  matches silent. A different version always asks.
- The game is never re-keyed or duplicated: saves, save states, screenshots,
  cheats and play statistics keep working.
- When nothing has it, say so. No more silent dismiss.
- Works on tvOS and iOS, for every source kind Provenance can already browse:
  iCube, iFly, another Provenance (same device or LAN), ECS, RomM.

## Non-goals (this piece)

- A find-by-hash route on peers and ECS, parallel queries, and picking the
  fastest source by measurement. That is piece 2, after release.
- Playing a disc from a server without storing it (iCube's RVZ/CISO streaming
  over WebDAV/SMB). Separate project.
- Refilling purged games in the background. tvOS purged that space on purpose.
- Restoring BIOS, saves or save states.
- Asking any device or server the user has not already paired or added.

## Anti-goals

- Never replace a file that exists. Recovery only fills a hole.
- Never swap in a different dump silently: save states may not load on it.
- Never add a wait to a launch whose file is present.

## What exists (checked 2026-11-19)

- `LibrarySource` (PVLibrarySharing) covers iCube, iFly, Provenance and ECS:
  `catalogue`, `pullManifest`, `download`. `LibraryPuller` copies into staging
  with resume and per-file SHA-256 checks.
- `RemoteLibraryItem` carries `md5` (optional), `sizeBytes`,
  `systemIdentifier`, `title`. ECS items report `sizeBytes: 0`, so size can
  never confirm an ECS match. A catalogue has no per-file names or sizes;
  those come only from `pullManifest`, one call per game, which iFly meters
  and may hold for its owner's approval.
- `NearbyLibraryReceiveService.receive` is typed to `ICubeContinuitySource`,
  needs exactly one game file and goes through the importer. Recovery does
  not reuse it; `LibraryPuller.pull` takes any `LibrarySource`.
- `PVSwiftUI` depends on `PVUIBase`, not the reverse, and `PVLibrarySharing`
  is a dependency of `PVSwiftUI` only. `PVEmulatorViewController` (PVUIBase)
  cannot call a `PVSwiftUI` type directly.
- Sources are built today by `NearbyLibrariesModel`, a main-actor UI object
  whose `PeerBrowser` runs only while a library view is on screen.
- `LocalLibraryIndex` documents the matching limit: MD5s agree only for
  single-file, headerless images. A `.cue`/`.m3u`/`.gdi` game's MD5 is not the
  image's, and the importer's MD5 is header-aware where a server's is raw.
- RomM is reached through `RomMClient` (emulator-content-server package) from
  `RomMLibraryView` / `RomMGameImport`; it is not a `LibrarySource`.
- Saved sources: paired peers in `FileHostTrustStore`, content servers in
  `LibrarySharing.contentServers` with Keychain tokens, RomM login in the
  Keychain. Live peers come from `PeerBrowser` (Bonjour).
- Launch: `PVEmulatorViewController.createEmulator` calls
  `needsCloudKitDownload` then `handleOnDemandDownload`; the final
  `fileExists` guard dismisses.
- `PVGame` has no record of where a game came from.
- Provenance no longer gates Nearby Libraries on a feature flag
  (`showsNearbyLibraries` is unconditional); the CHANGELOG and
  `docs/development/content-server.md` still say it does.

## Approaches

- **A. Client only (chosen for this piece).** Search the catalogues of known
  sources and match locally. No protocol change; works against the iCube, iFly
  and ECS builds that exist. Slower on large libraries.
- **B. A find route on every source.** One "do you have this?" request per
  source, in parallel, then a short timed read to pick the fastest. One round
  trip per source, but changes four codebases and bumps the protocol. Chosen
  for piece 2; A stays as its fallback for older peers.
- **C. UDP multicast query.** Needs the multicast entitlement, which Apple has
  not approved, and finds nothing B does not. Dropped.

Owner picked A now, B after release.

## Design

### Flow at launch

1. The ROM (or any required file of the game) is missing and iCloud cannot
   supply it (no cloud asset, or the on-demand download failed for a reason
   other than the user cancelling).
2. Show the existing download progress UI with "Looking for <title> on your
   network".
3. Ask sources in order, stopping at the first exact match (see Matching):
   the game's remembered source, then same-device apps, then LAN peers, then
   ECS servers, then RomM.
4. Exact match: ask (see Asking) unless Always Allow is on, then copy,
   verify, put the files where the game expects them, boot.
5. No exact match but a same-name candidate: always ask. Accept copies it
   as a stand-in; decline ends the launch.
6. Nothing found: alert "<title>'s file is missing and no nearby library or
   server has it", listing which sources were asked and which were
   unreachable. Then dismiss.

Cancel is available throughout and leaves the game as it was.

The same action is in the game's context menu as "Restore missing file" when
the file is absent.

### Matching

In order, for a candidate on the same system:

1. **Hash.** Single-file game: remote `md5` equals `PVGame.md5Hash`
   (case-insensitive), and sizes agree when both are known. Exact.
2. **Remembered source.** The hint's source and remote id (below). Exact; the
   pull is still verified by the manifest's SHA-256.
3. **Same name, then file set.** Candidates are narrowed from the catalogue
   by system and name: title or primary file name equal after normalising
   case, extension and punctuation. Never fuzzy (same rule as
   `BezelNameMatcher`). For the best candidate per source only, fetch its
   manifest. If every file of the game (primary plus related) has a manifest
   file with the same name and size, it is exact. This is the only exact
   route for multi-file games and headered systems, whose MD5s never agree.
   One manifest per source keeps iFly's metering and approval prompts to one.
   *(My call: name plus size for every file is strong enough to count as
   the same game, so Always Allow covers it.)*
4. **Same name only.** The name matched but the file set did not, or the
   source gives no per-file sizes. Asks first.

### Putting the file back

Recovery does not go through the importer: the game row already exists.
`LibraryPuller` pulls into staging; each file is then moved to the path the
game's `PVFile` records, only if nothing is there. Then
`GameFileStatusService.markDownloaded`.

A same-name match the user accepted is a different file with a different
hash. Owner's rule (2026-11-20): recovery is transparent; the database,
metadata, saves, screenshots and play statistics all keep working.

So a different version is a **stand-in**: it goes to the old game's recorded
path, under the old file name, and the game row is not touched. No re-key, no
second library entry. Everything linked to the game stays linked because the
game never changes. This also works with iCloud Sync on, where a re-key would
delete the game on the user's other devices (the reason
`PatchReplacement` blocks it).

What a stand-in costs, accepted:

- `PVGame.md5Hash` no longer equals the file's hash. The game's identity is
  the dump the user imported; the file is a substitute. The source hint
  records that the file is a stand-in and its real MD5.
- Save states made on the original dump may not load. The prompt says so.
- If the user later imports the original dump again, it lands on the same
  path and replaces nothing (the importer already treats a file at a known
  `romPath` as that game).
- If the game is later uploaded to iCloud, the stand-in's bytes go up under
  the old key. Other devices that hold the original keep theirs.

A multi-file game takes a stand-in only when the manifest has the same file
names (sizes may differ). With different file names the index file would not
resolve, so it is not offered; the final alert names the source that has
another version.

### Asking

Every recovery asks once before copying: "<title>'s file is missing. Copy it
from <source>?" with **Copy**, **Always Allow** and **Cancel**. Always Allow
is stored (`Defaults`, with a switch in Settings under Nearby Libraries) and
later exact matches copy and boot with only the progress UI.

A stand-in always asks, even with Always Allow on: "<source> has <file
name>, which may be a different version. Use it? Save states may not load."
*(My call: Always Allow never covers a different version.)*

### Remembering the source

A small store, `GameSourceHints`, keyed by game MD5: source kind, source
identity (peer id or server URL), remote item id, and the manifest's file
names, sizes and SHA-256s. Written whenever a game is copied from a source or
found by recovery. It is a JSON file beside the Realm database, not a Realm
property, to avoid a schema migration days before release. *(My call.)* It is
an optimisation: on tvOS it can be purged with everything else, and recovery
works without it.

### Sources and reach

- Only paired peers currently visible over Bonjour, saved content servers and
  a saved RomM login. No pairing or sign-in prompts start from a launch; a
  source that needs one is reported as "needs sign-in" in the final alert.
- An iFly host may meter or ask its owner to approve a pull. That wait shows
  in the progress UI as it does in Nearby Libraries.
- Catalogues are cached in memory for the session, so a second missing game
  does not re-fetch them.
- Peers are found without UI: a small headless directory starts a
  `PeerBrowser` when recovery begins, waits a short window (about 3 s) for
  adverts, and keeps only peers the trust store already knows. Discovery
  never runs for a launch whose file is present. It builds sources the same
  way `NearbyLibrariesModel` does (lines ~397-405); the plan extracts that
  construction so both share it. *(My call.)*
- Each source gets a short timeout for its catalogue (builder picks; about
  8 s) so one dead server cannot hold the launch.
- RomM is not a `LibrarySource` and has no SHA-256 manifest, so it is a
  second, smaller pull path: search through `RomMClient` (its search or hash
  filter if it has one, else the platform's game list), download with
  `client.download`, verify by RomM's reported hash when present, else by
  size. It is the last task in the plan and can slip past the release
  without affecting the rest. *(My call.)*

### Code shape

- `PVLibrarySharing`: `MissingGameQuery` (system, md5, size, title, file
  names and sizes), `RecoveryMatch` (exact / needsConfirmation, with the item
  and source), and `MissingGameMatcher`, a pure function over a
  `RemoteCatalogue`. All unit-testable without the network.
- `PVUIBase`: a protocol seam, `MissingROMRecovering`
  (`recover(gameMD5:progress:) async throws -> RecoveryOutcome`), with a
  registration point. `PVEmulatorViewController` calls it where the launch
  guard (~line 1038) would dismiss, and after an on-demand download that
  ends without a file. With nothing registered, behaviour is today's plus
  the new alert.
- `PVSwiftUI` (beside `NearbyLibraryReceiveService`):
  `MissingROMRecoveryService` implements the seam and is registered at app
  bootstrap. It lists sources, runs the matcher, pulls with `LibraryPuller`,
  restores, and reports progress.
- Restore resolves each target with `FileLocationResolver` from the
  `PVFile`'s `partialPath` (as `needsCloudKitDownload` does) and
  `game.relatedFiles`, moves staged files with the `LibraryStaging`
  confined-path helpers, then calls `markHandedOff`.
- Shared with iCube and iFly later: the PVLibrarySharing types are app-neutral
  on purpose.

### Flags and docs

Provenance already ships Nearby Libraries unflagged. Remove the stale "behind
the `nearbyLibraries` flag" wording from the CHANGELOG entry going forward and
from `docs/development/content-server.md`. iCube, iFly and ECS defaults are
changed in their own repos (separate sessions).

## Tests

- `MissingGameMatcher`: hash match, size disagreement, file-set match for a
  cue/bin set, headered single file falling to file-set, same-name asks,
  different system never matches, no fuzzy matches.
- Restore: never overwrites an existing file; a failed SHA-256 leaves the
  game unchanged; cancel leaves the game unchanged.
- Stand-in: the game row is unchanged (same MD5, saves and recents still
  linked); a multi-file set with different file names is not offered.
- Asking: Always Allow skips the prompt for exact matches only.
- Source ordering and per-source timeout, with fake sources.
- Device check owed: Apple TV with a purged game, iCube on a Mac as the host.

## Left to the builder

- Exact timeout values and the progress strings.
- Confirm no launch, sync or library scan path re-hashes a file and rejects
  or re-imports it when the hash differs from `md5Hash`.
- Whether RomM's client has a usable search; fall back to listing.
- Where exactly in `createEmulator` the call sits relative to archive
  handling and the `MultiFileSetFolder` handling near line 947.

## Piece 2 (after release, not designed here)

Find route on the peer dialects and ECS taking both hashes, name, system and
size; parallel queries; fastest-source pick by a short ranged read; the hint
carried in CloudKit game metadata so it survives a tvOS purge.
