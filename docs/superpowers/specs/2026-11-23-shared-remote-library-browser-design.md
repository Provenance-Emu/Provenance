# Shared remote-library browser (Provenance, iFly, iCube)

Date: 2026-11-23. Status (2026-11-24): the owner accepted the recommended answers below. The package's
first cut exists at github.com/Provenance-Emu/PVRemoteLibrary (private; 25 tests pass on the Mac, builds
for iOS and tvOS). No app uses it yet.

## Why

The owner, testing the tvOS TestFlight on 2026-11-23:

> in tvos and ios provenance, when browsing a emualtor content server or romm share,
> it's a stupid ugly single page. but on ifly and icube, they just look like the normal
> all or per system browser, but with tab / ui indicators of the server it's browsing.
> i wonder if we can even have the option to combine local and all remotes and show
> indicators on sync status and availability, local content results caching etc.
> that should be part of the shared lib and all the apps use it like that

Three apps browse the same servers with three separate implementations. Provenance's
is the weakest, and none of them can show local and remote games in one list.

## What exists today

Provenance was read directly. The iFly and iCube columns come from a read-only survey
of their source on 2026-11-23 and were not built or run; check a detail there before
relying on it.

| | Provenance | iFly | iCube |
|---|---|---|---|
| Browse view | `NearbyPeerLibraryView`: its own scroll page of sections, own tile, own search field. RomM is a separate `RomMLibraryView` reachable only from Settings | `NearbyLibrarySection` inside the normal `LibraryView`, with the library's own console filter, sort, search and grid/list toggle | `NearbyPeerLibraryView` filling the library column of `TVLibraryView` |
| Server indicator | A row of buttons above the library (`serverTabs` in `PVLibraryRootView`); a sidebar entry on tvOS | A filter pill named after the host, followed by console pills | `LibrarySourcePill` in the filter bar, a rail entry on tvOS |
| Remote item | `RemoteLibraryItem` (PVLibrarySharing) | `NearbyRemoteGame` | `ContinuityLibraryEntry` (PVContinuity) |
| Source abstraction | `LibrarySource` actor protocol; `ECSSource`, peer sources | `ServerLibrarySource`; ECS and RomM implementations | `RemoteGameCatalog` actor protocol; ECS and RomM implementations |
| Catalogue | ECS paged with server search; peers whole | Whole catalogue | Paged with server search |
| Catalogue cache | None | One JSON file per server, shown stale-first, refreshed after 600 s | None |
| Cover cache | In memory, per screen | 480 px JPEG files, no ETag | `RemoteCoverCache`: files, ETag revalidation |
| "Already have it" | `LocalLibraryIndex`: system + MD5 + size | MD5, then install folder, then file name | Local `gameID` set |
| Merged with local | No | No | No |
| Downloads | One copy task per item, foreground | One transfer at a time | Background downloads with a journal, joined per game |
| Server save sync | No | No | Yes (`EmulationServerSaveSyncWorker`) |
| Peer package | `PVLibrarySharing` (in this repo) | `ContinuityKit` | `PVContinuity` |
| ECS client pin | `7b30839` | `0ae2187` | `f779275` |

Only the wire clients (`EmulatorContentClient`, `RomMClient`) are shared, and each app
pins a different revision. Everything above them is written three times.

Provenance already has the seam the fix needs: its grids draw `GameItemPresentable`
values (`GameCellModel`), not Realm objects, through `GameItemPresentableView`. That
protocol already carries `hasCloudAssets` and `isDownloaded`.

## Goals

- Browsing a server, a RomM share or a nearby peer uses each app's normal library
  screens: all games and per system, same grid and list, same sort and search.
- The screen always shows which source it is browsing.
- An optional combined view shows local games and every source's games in one list,
  each game once, with where it is and whether it can be played now.
- The catalogue and covers of a source open from a cache, without waiting on the network.
- One shared package holds the model, the sources, the caches and the merge. All three
  apps use it.

## Non-goals

- A shared library screen. Each app keeps its own views and theme (see decision 2).
- Server-side changes to emulator-content-server or RomM.
- Save sync with a server in Provenance or iFly. The item state leaves room for it.
- Replacing nearby-peer pairing, consent or transfer; those stay as they are.

## Design

### 1. The package

A new package, working name **PVRemoteLibrary**, in its own repository like PVSystems
and PVLookup. It depends on `PVSystems`, `EmulatorContentClient` and `RomMClient`. It
has no UIKit, SwiftUI, Realm or SwiftData, so `swift test` runs on the Mac.

It does not depend on a peer package. Three peer packages exist; each app adapts its
own to the source protocol below with a small file. Folding the peer packages together
is separate work.

### 2. Model

```swift
public struct LibrarySourceID: Hashable, Codable, Sendable   // "local", "ecs:<origin hash>", "romm:…", "peer:…"

public struct LibrarySourceInfo: Sendable {
    var id: LibrarySourceID
    var kind: Kind            // .local, .contentServer, .romm, .peer
    var name: String          // host or device name: the indicator's text
    var symbol: String        // SF Symbol: the indicator's glyph
}

public struct LibraryGame: Identifiable, Hashable, Codable, Sendable {
    var id: String                 // source id + the source's own game id
    var source: LibrarySourceID
    var title: String
    var system: SystemIdentifier?
    var platformName: String       // the source's raw platform, for display when unmapped
    var md5: String?
    var sizeBytes: Int64
    var fileName: String?
    var artKey: String?
    var discCount: Int             // how many discs the set has
    var gameID: String?            // GameCube/Wii id and similar
    var discNumber: Int?           // which disc of the set this entry is
    var revision: Int?
    var ownerLastPlayed: Date?     // what the source knows; nil for most
    var ownerFavorite: Bool?
}
```

`LibraryGame` is the union of today's three item types. Provenance's
`RemoteLibraryItem` maps to it field for field.

### 3. Sources

```swift
public protocol RemoteLibrarySource: Actor {
    nonisolated var info: LibrarySourceInfo { get }
    nonisolated var capabilities: SourceCapabilities { get }   // serverSearch, paging, temporaryPlay, saveSync
    func page(_ query: CatalogueQuery, after cursor: CatalogueCursor?) async throws -> CataloguePage
    func artwork(for game: LibraryGame, etag: String?) async throws -> ArtworkResult
    func fetch(_ game: LibraryGame, into directory: URL,
               progress: @Sendable (FetchProgress) -> Void) async throws -> FetchedGame
}
```

A source owns its whole transfer and hands back the files (`fetch`). Ranged requests,
resume, verification and background sessions differ too much between RomM (one
whole-file download), the content server (Provenance's verified, resumable puller)
and iCube's background downloader to share one request shape.

The package ships `RomMSource` in its own product, `PVRemoteLibraryRomM`, so the core
does not depend on the server client package. The content-server source is not in the
package yet: Provenance's `ECSSource` leans on `PVLibrarySharing`'s transport, puller
and staging, so Provenance adapts it in place first, and it moves into the package when
iFly switches. A source that cannot page returns everything as one page. A source
without server search is filtered by the browser.

### 4. Catalogue store

`RemoteCatalogueStore` (an actor) keeps one file per source in Caches, holding every
page fetched so far, the query it answers and the fetch date. This is iFly's
`ServerCatalogStore` made to hold pages.

- Opening a source returns the cached catalogue at once, marked stale, then refreshes.
- A refresh that fails leaves the cached catalogue on screen with the error beside it.
- Refresh happens on open when older than 10 minutes, on pull-to-refresh, and when the
  source reappears on the network.
- Paged sources fill the cache as pages arrive; server-search results are kept apart
  from the browsed catalogue and are not written to disk.
- Removing a source deletes its file.

`RemoteCoverCache` is iCube's: files in Caches, a thumbnail per cover, the server's
ETag sent back as `If-None-Match`.

### 5. Matching and the combined library

Each app gives the package its local games as plain values:

```swift
public struct LocalGameRef: Sendable {
    var id: String; var title: String; var system: SystemIdentifier
    var md5: String?; var sizeBytes: Int64; var fileName: String?
    var gameID: String?; var discNumber: Int?; var revision: Int?
    var isSingleFileImage: Bool; var isOnDisk: Bool
}
```

`LibraryMatcher` decides whether two entries are the same game, strongest rule first:

1. Same system, same MD5, and the same size when both know it (today's `LocalLibraryIndex`).
2. A recorded link: the local game was downloaded from that source entry. The package
   keeps this table; it replaces Provenance's `LibrarySharing.games.<peer>` defaults
   key and iFly's install-folder check.
3. Same system, same `gameID` and same `discNumber` (iCube). An entry with no disc
   number matches only another with none; `discCount` is never used to match.
4. Same system and same normalised file name.

Titles are never matched. A disc set whose MD5 is not the image's own
(`isSingleFileImage == false`) skips rule 1.

`CombinedLibrary` merges the local list with any number of source catalogues into rows:

```swift
public struct CombinedGame: Identifiable, Sendable {
    var id: String                       // the local id when there is one, else the first source's
    var local: LocalGameRef?
    var remotes: [LibraryGame]           // one per source that has it
    var availability: Availability
    var transfer: TransferState?         // queued, downloading(fraction), verifying, importing, failed
}

public enum Availability: Sendable {
    case onDevice                         // local file present, on no source
    case onDeviceAndSources               // local file present and at least one source has it
    case localRecordOnly                  // in the library, file not on this device, a reachable source has it
    case missingFile                      // in the library, file not on this device, no reachable source has it
    case remoteOnly                       // on a reachable source only
    case unreachable                      // known only from a cached catalogue whose source is offline
}
```

Title, artwork, favourite and play history come from the local record when there is
one. Sorting, search and grouping by system run on the merged rows, so a game sorts the
same wherever it lives. Search is local and immediate over the cached catalogues; for a
source with server search the store also asks the server and adds what comes back.

Offline, a source's rows stay, drawn as unreachable, and cannot be downloaded. A filter
(All, On This Device, one source) sits where the source indicator is.

Save-sync state is a field for later (`saveSync: inSync / localNewer / remoteNewer`).
Only iCube could fill it today.

### 6. View model

`RemoteLibraryBrowser` (`@Observable`, main actor) is what an app's views read: the
sources, the selected scope (one source, or combined), sections by system, load phase,
stale flag, transfers. The app injects three closures: its local games, "import this
downloaded file", and "play this local game". Pairing, consent and sign-in screens stay
in the apps and hand the browser a ready source.

### 7. What each app's views do

The package draws nothing. Each app adapts `CombinedGame` to the cell it already has
and adds two small things to that cell: a source glyph and an availability mark.

**Provenance.** A `GameCellModel` is built from a `CombinedGame`; `hasCloudAssets` and
`isDownloaded` already express remote-only. `ConsoleGamesView` and the tvOS
`TVMedia` grids take their rows from either Realm or the browser. The `serverTabs`
button row becomes a source pill in the library header (iOS) and the existing sidebar
entries (tvOS); selecting one shows the normal home and per-system views scoped to that
source. `NearbyPeerLibraryView` shrinks to the states that are not a library: pairing,
code entry, waiting for approval, failure. `RomMLibraryView` goes away once RomM is a
source like the others.

**iFly.** `ServerLibrarySource`, `ServerLibraryModel`, `ServerCatalogStore` and
`NearbyRemoteGame` are replaced by the package; `NearbyLibrarySection` keeps drawing.

**iCube.** `RemoteGameCatalog`, `ContinuityLibraryBrowseController` and
`RemoteCoverCache` are replaced by the package. iCube gains the catalogue cache; its
background downloader stays and reports into `TransferState`.

## Order of work

1. **Package, no UI.** Model, source protocol, `ContentServerSource`, `RomMSource`,
   both caches, matcher, combined library, browser; tests on the Mac against recorded
   server responses. Align all three apps on one emulator-content-server revision.
2. **Provenance, one source at a time.** Server and RomM browsing through the normal
   per-system and all-games views on iOS and tvOS, with the source indicator. This is
   the smallest step that fixes what was reported. Peers follow through an adapter over
   `PVLibrarySharing`.
3. **Provenance, combined view,** behind a setting, off by default.
4. **iFly** switches to the package. Low risk: the package's shape is closest to iFly's.
5. **iCube** switches. Highest risk because of paged browsing and background downloads.
6. Combined view in iFly and iCube.

Steps 2 and 4 can run at the same time once step 1 is tagged.

## Risks

- **Large catalogues.** A server with tens of thousands of games cannot be fetched whole
  on open. The store caches what was browsed; the combined view lists only what is
  cached and says so. If the server's change feed (`ContentSync.changes(cursor:)`) can
  drive a full background index, that removes the limit; not investigated.
- **Wrong matches.** A false match hides a remote game behind a local one. Rule 4 (file
  name) is the weak one; it is why titles are excluded and why the rules are ordered.
- **Realm-backed grids.** `ConsoleGamesView` passes lazy `Results<PVGame>` in places.
  Remote rows need the array path, which exists, but large combined lists must not
  materialise the whole local library on the main thread.
- **Three peer packages.** The adapters hide the difference; they do not remove it.

## Decisions for the owner

1. **Where does the shared code live?** Recommended: a new repository, PVRemoteLibrary.
   The emulator-content-server client package should stay a thin wire client, and
   `PVLibrarySharing` is inside the Provenance repo where iFly and iCube cannot use it.
2. **Share the views too, or only the model?** Recommended: only the model and view
   model. The three library screens differ too much (SwiftUI over Realm snapshots,
   SwiftData, iCube's `TVLibraryView`); a shared grid would be a fourth library screen.
   A shared source pill and availability badge could come later as an optional product,
   the way SkinKit splits `SkinKitBezels` and `SkinKitBezelsUI`.
3. **Is the combined view on by default?** Recommended: off, under Library settings,
   until matching has been seen on real libraries.
4. **How is a source shown?** Recommended: a pill in the library's filter bar on iOS
   (as iFly and iCube do) and the sidebar entry on tvOS, plus a small glyph on each tile
   in the combined view.
5. **Whole catalogue or pages?** Recommended: pages, cached as browsed, with the
   change-feed index investigated during step 1.
6. **What does selecting a remote-only game do?** Recommended: keep today's choice,
   "Play Temporarily" or "Download and Run", for sources that support temporary play,
   and download-then-play for the rest.
7. **Does Provenance get server save sync?** Recommended: not in this work; leave the
   state field and decide after the browser ships.
8. **Should the peer packages merge?** Recommended: not now. `ContinuityKit`,
   `PVContinuity` and `PVLibrarySharing` each sit behind an adapter; merge them only if
   the adapters turn out to be more than a file each.
9. **Does RomM leave Settings in Provenance?** Recommended: yes. Adding a RomM server
   moves to the same "Add Content Server" flow and it appears as a source.
