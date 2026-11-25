# One continuity package for Provenance, iFly and iCube

Date: 2026-11-25. Status: proposal, waiting for the owner's decisions (last section). No code has changed.

## Why

On 2026-11-25 the owner asked for shared packages to be adopted across all three apps. For nearby library sharing and "continue this game" there are three implementations today:

| App | Code | Service type |
|---|---|---|
| iFly | `Provenance-Emu/ContinuityKit` 1.0.2 | `_ifly-continuity._tcp` |
| iCube | `Provenance-Emu/PVContinuity` 1.0.1 | `_icube-continuity._tcp` |
| Provenance | `PVLibrarySharing` (in this repo) | `_pvlibrary._tcp`, and both of the above |

This document compares them, recommends one package and one protocol, and lays out a migration that keeps installed builds working.

It builds on two earlier documents and does not repeat them:

- `2026-10-14-cross-app-library-sharing-design.md` defined the neutral protocol ("extension v1.1", `_pvlibrary._tcp`) and Provenance built it. iFly and iCube reviewed it and reported no conflicts, but have not adopted it.
- `2026-11-23-shared-remote-library-browser-design.md` covers the browse model above the wire (`PVRemoteLibrary`). Its decision 8 was "do not merge the peer packages now". The owner's request of 2026-11-25 replaces that answer.

## Recommendation in short

1. **One package: ContinuityKit.** PVContinuity is archived once iCube has moved, and the protocol half of `PVLibrarySharing` moves into ContinuityKit.
2. **One library protocol: the neutral `_pvlibrary._tcp` dialect that Provenance already serves and browses.** Neither app's current protocol survives as the common one.
3. **The package also speaks both current protocols**, selected by a per-app profile, so a new build of each app still talks to installed builds of itself. Provenance already runs all three side by side, so this is known to work.
4. **"Continue this game" stays per app**: same wire as today, served from the shared code. A save state only loads in the app that made it, so there is nothing to unify across apps.

## 1. What each implementation does

Sources read: ContinuityKit at `1d6c48b`, PVContinuity at `bc65f46`, `PVLibrarySharing` on `develop`, iFly `develop` at `904bb5623`, iCube at `aa9ff9ac13`. The app columns come from reading source; nothing was built or run for this document.

### 1.1 ContinuityKit and PVContinuity are one design, forked

PVContinuity was written from ContinuityKit's design for GameCube and Wii. The file layout, type names, route paths, pairing maths, puller and fallback ladder match. A diff of the files that define the wire shows these differences and no others:

| | ContinuityKit (iFly) | PVContinuity (iCube) |
|---|---|---|
| Service type | `_ifly-continuity._tcp` | `_icube-continuity._tcp` |
| Signature prefixes | `ifly-continuity-pair-v1\|`, `ifly-continuity-auth-v1\|` | `icube-continuity-pair-v1\|`, `icube-continuity-auth-v1\|` |
| Handoff activity type | `com.joemattiello.ifly.continuity.play` | `com.joemattiello.icube.continuity.play` |
| Game identity fields | `flycastGameId`, `md5Hash`, `serial`, `discNumber`, `discGroupKey` | `gameID`, `md5`, `crc32`, `discNumber`, `revision`, plus a match ladder and `stableKey` |
| TXT game keys | `gid`, `md5`, `ser` | `gid`, `md5`, `crc`, `disc`, `rev` |
| Other TXT keys | `cap`, `dt`, `ic` | `dt` only |
| File kinds | `gameFile`, `bios`, `saveState`, `vmuGlobal`, `vmuPerGame`, `vmuAll`, `texturePack` | `gameFile`, `saveState`, `resumeState`, state metadata and thumbnail, memory card, Wii save, config, game settings |
| Session manifest | `files`, `bios`, `optionalExtras` (all required when decoding), `?extras=` | `files` only |
| Save state slot | `Int` | `Int?` (nil is the resume state) |
| `relativePath` root | App documents folder | Dolphin User folder (Caches on tvOS) |
| Library catalogue | `GET library/manifest`: whole list, with owner play data (last played, play count, favourite, save count), `ETag` | `GET library/catalog`: version-checked, title, size and identity only |
| One game's files | `POST library/pull {gameId}`, then `GET library/file?path=` | `GET library/manifest?key=`, then `GET library/file?key=&path=` |
| What a library pull carries | Game, BIOS, save states, VMUs | The game file only (`libraryUserDataKinds = []`, asserted by a test) |
| Unknown peer asks to browse | Owner prompt (Share Everything / Ask Per Game / Don't Share), trusted on first use | Refused: 403 "not a paired device" until a 6-digit pairing |
| Same iCloud account | `ic` hash skips the prompt | Not present |
| Code-less continue | `continue/start`, `continue/poll` with Allow Once / Always | Not present |
| Presence beacon | Yes (`cap`, no routes) | No |
| Library token | No lifetime set; revoked when sharing is turned off or trust is edited | 1 hour, at most 16 live, trust re-checked on every request |
| Per-game exclusion | Host adapter's job | In the package, re-checked on every file request |
| Metering | 429 seam on pulls and token handouts (iFly Pro) | None |
| Offline package | `.iflypkg` reader and writer (ZIPFoundation) | `.icubepkg` constants only |
| HTTP seam | Own `ContinuityRouteRegistrar` protocol | `PVWebServer`'s `WebRouteRegistering` |
| Dependencies | ZIPFoundation (internal) | PVSyncRules, PVWebServer |
| Language, platforms | Swift 6; iOS 16, tvOS 16, watchOS 9, macOS 13, visionOS 1 | Swift 5.9; iOS 17, tvOS 17, macOS 14 |
| Licence | Provenance licence (BSD style) | GPL-2.0-or-later |

Because the signature prefixes differ, an iFly signature never verifies on iCube and the reverse, even with the same key. And because `library/manifest` means "the whole catalogue" in one and "one game's files" in the other, one HTTP listener cannot serve both.

### 1.2 Provenance: `PVLibrarySharing`

Provenance uses neither package. It wrote its own codecs for both wires, pinned by JSON fixtures copied from both apps' tests, and added the neutral dialect.

- **As a client** it browses four service types (`_ifly-continuity._tcp`, `_icube-continuity._tcp`, `_pvlibrary._tcp`, `_pvcontent._tcp` reserved), keeps one row per peer id and prefers `_pvlibrary`.
- **As a server** it runs one `NWListener` per dialect, each on its own port from 8484, each advertised under that dialect's type. The iFly listener is advertised only while a Dreamcast-family game is shared, the iCube one only while a GameCube or Wii game is shared.
- **The neutral dialect** uses iCube's route shape (separate catalogue and per-game manifest, version-checked, key and path on every file request), iFly's consent prompt for unknown peers, code pairing as an alternative, `ETag` on the catalogue, a system filter and opt-in paging, the prefixes `pvlibrary-pair-v1|` and `pvlibrary-auth-v1|`, and four extra TXT keys: `app`, `lx`, `sys`, `cv`.
- It has no "continue this game" between devices. That was out of scope in October.
- It also has things neither package has: a LAN filter on every connection (loopback, link-local or on-link only; cellular and VPN interfaces refused), a staging folder with path containment, and a SHA-256 cache keyed by path, size and modification time.

### 1.3 The three, by topic

| | iFly | iCube | Provenance |
|---|---|---|---|
| **Discovery** | Bonjour TXT: `v`, `sid`, `lib`, `pid`, `u0..u3`, game keys on handoff adverts, optional `cap`, `dt`, `ic`. Handoff also through `NSUserActivity`. | Same codec family without `cap` and `ic`. Handoff also through `NSUserActivity`. | Same base keys plus `app`, `lx`, `sys`, `cv`. Three adverts. No `NSUserActivity` handoff. |
| **Trust** | Ed25519 identity per install, key in the app's keeping. Code pairing, consent with trust on first use, same-iCloud shortcut. | Same identity and pairing. Paired peers only. | Same identity (Keychain). Follows the peer's rule on each legacy dialect; consent or pairing on the neutral one. |
| **Per-peer grant** | everything / ask per game / denied | Same; default ask per game | Same; default ask per game |
| **Library browse** | Yes, with the owner's play data | Yes, without it | Yes, without it; filter and paging |
| **Single game copy** | Yes | Yes | Yes |
| **Owner data in a copy** | BIOS, states, VMUs | None. iCube has a separate app-side save route between paired devices (`NearbySaveTransfer.swift`), not read in detail here. | None |
| **Continue this game** | Yes: mint a state, pull, fallback ladder | Yes: same | No |
| **Offline package** | `.iflypkg` export and import | Not built | No |
| **Transport** | Plain HTTP on the app's web server | Plain HTTP on the app's web server | Plain HTTP on its own listeners |
| **Resume** | `.part` file, `Range`, restart on 200 | Same | Same, plus two restarts per file and a cached manifest so a resume does not spend a metered pull |
| **Integrity** | SHA-256 per file; manifest is the allow-list | Same | Same |
| **What the user sees** | Nearby section inside the normal library, host pill, copy options, sync subscriptions, trusted devices, approval prompts | Nearby peer library, sharing settings, handoff sheet, approval prompts | Nearby Libraries with app badge, Share This Library, trusted devices, approval alerts |

### 1.4 What each has that the others lack

- **Only ContinuityKit:** code-less continue, presence beacon, same-iCloud shortcut, metering seam, package reader and writer, opt-in extras, owner play data in the catalogue.
- **Only PVContinuity:** identity match ladder, token expiry and cap, live trust check per request, exclusion in the package, "a library pull carries nothing of the owner's" as a tested rule, file kinds tied to the sync rules.
- **Only PVLibrarySharing:** the neutral dialect, serving several dialects at once, system list and filter, paging, LAN filter, own listener, staging rules, fixtures for all three wires.

## 2. Recommendation

### 2.1 Keep ContinuityKit, and make it the only package

Reasons, from the code:

- **It has no app-specific dependency.** PVContinuity's public interface imports `PVSyncRules`, whose categories are iCube's (GameCube memory card, Wii save, Dolphin config), and `PVWebServer`'s route types. The October objection that `PVWebServer` clashed with a Provenance module of the same name no longer holds, since all three apps now use the shared `PVWebServer` package. But Provenance's sharing runs on its own listeners, not on the web server, and the sync-rules tie makes the file kinds iCube's. ContinuityKit's route seam is a three-line protocol that each app adapts in one file.
- **It is the superset on features** that are hard to add later (package archives, continue requests, beacons, metering), and the wider platform list.
- **Its licence fits all three apps.** PVContinuity is GPL-2.0-or-later. Moving its files into ContinuityKit would change ContinuityKit's licence. Provenance's `PVLibrarySharing` already contains independent, non-GPL implementations of iCube's wire, pairing replies, token rules and exclusion checks, so the iCube behaviour can come from there. (If the owner, as author, prefers to relicense PVContinuity's files, direct porting is simpler. See decision 3.)
- **The name is neutral.** `PVContinuity` would do as well; nothing depends on the choice except the repository that survives.

Three structural changes are needed inside ContinuityKit. Each is something one of the other two already does.

1. **A profile per app** replaces the hard-coded constants: service type, signature prefixes, activity type, package extension and type identifier, iCloud salt, queue labels, and the error text that says "Update iFly".
2. **The model and the wire separate.** Today both packages encode their model types directly, which is why two apps cannot share one model. The package gets one model (a game identity with every field optional; file kinds as an open string-backed type with ordering supplied by the app) and one codec per dialect, each pinned by fixtures. Provenance already works this way (`ContinuityWire`, `ServerWire`).
3. **Server rules become options of the dialect, not forks:** who may browse (consent or paired only), what a library pull carries, token lifetime and cap, whether the catalogue and the per-game manifest are one route or two.

`PVSyncRules` stays out of the package. iCube keeps its mapping from sync categories to file kinds in the app.

### 2.2 One library protocol: `_pvlibrary._tcp`

Why not pick iFly's or iCube's wire as the common one: the signature prefix and service type are baked into every installed build, so whichever is chosen, the other app's installed base cannot talk to it. Both choices cost the same, and each carries rules the other app does not want (iFly's sends the owner's play data and saves; iCube's refuses unknown peers outright).

Why the neutral dialect:

- It exists. Provenance serves and browses it, with tests in process and over a real socket, a back-compatibility matrix and fixtures.
- Both app sessions reviewed it in October and reported no conflicts.
- It takes the safer half of each: iCube's separate, version-checked catalogue and per-file exclusion check; iFly's consent prompt so nobody has to walk across a room to read a code before browsing.
- Its additions are optional TXT keys and query items, which old peers ignore.

The neutral dialect needs its own port. Its paths are the same as iCube's legacy paths with different signatures, and one of them collides with iFly's. Provenance solved this with a small `NWListener` server; that listener and the LAN filter move into the package as a second product so iFly and iCube get them too.

Things the neutral dialect does not have yet, which this work adds as optional parts:

- `ic` same-account shortcut (blocked on decision 5).
- Owner data for the owner's own devices (iFly's saves and VMUs in a copy; iCube's separate save route). The rule stays "a stranger gets the game only"; a peer on the same account or with an explicit grant may be offered more.
- A 429 answer for a metered host, so iFly Pro's limit keeps working when an iFly host serves the neutral dialect.

### 2.3 "Continue this game" is not unified across apps

The handoff session routes (`manifest`, `mint`, `file`, `pair/*`, `auth/*`, `continue/*`) are nearly the same in both packages and move into the shared code under the profile. Their wire does not change: same service type, same activity type, same JSON. A state minted by flycast loads only in iFly and one minted by Dolphin only in iCube, so a neutral handoff wire would have no user.

iCube gains code-less continue and the presence beacon for free if it wants them. Provenance could later add Provenance-to-Provenance handoff on the same code; that is a new feature and not part of this work.

### 2.4 What is left in each repo

| Repo | After the migration |
|---|---|
| ContinuityKit | Model, three dialect codecs, session, pairing and library servers, clients, puller, fallback ladder, package archives, multi-type browser, advertiser, listener with LAN filter, trust and grant stores, testing support |
| iFly | Profile, adapters to its web server, file layout, library and prompts; its views |
| iCube | Profile, adapters to `PVWebServer` and `PVSyncRules`, file layout, save route; its views |
| Provenance `PVLibrarySharing` | Content server and RomM sources, the `PVRemoteLibrary` bridge, missing-game recovery, local matching, Realm glue |
| PVContinuity | Archived, tags kept so old iCube commits still build |

## 3. Keeping installed builds working

### 3.1 Can a new build speak both protocols?

Yes. A new build of each app keeps its legacy advert and routes byte for byte and adds the neutral ones on a second port:

| New build of | Advertises and serves | Browses |
|---|---|---|
| iFly | `_ifly-continuity._tcp` (legacy, unchanged), `_pvlibrary._tcp` | Both |
| iCube | `_icube-continuity._tcp` (legacy, unchanged), `_pvlibrary._tcp` | Both |
| Provenance | All three, as today | All three, as today |

- A peer seen under two types is shown once, keyed by `pid`, and the neutral type wins. Provenance's browser already does this.
- An old build sees only the legacy advert and is served the legacy routes. Nothing it receives changes.
- **Pairing carries over.** The identity key and peer id are the same on every dialect; only the signed prefix differs. A device already trusted on the legacy type is recognised on the neutral one without a prompt. This must be a test in the package.
- "Byte for byte" is enforced by fixtures: the legacy codecs must reproduce the JSON and TXT records recorded from ContinuityKit 1.0.2 and PVContinuity 1.0.1.

Each app needs `_pvlibrary._tcp` in `NSBonjourServices` in every Info.plist. That only changes with an app release, which is why it is an early step.

### 3.2 How long

The neutral dialect is useful between two devices only when both run a build that has it. Until then the legacy path carries the traffic.

- **Handoff legacy wire:** no end date. It is the only handoff wire.
- **Legacy library routes in iFly and iCube:** keep for at least two feature releases and six months after the first release that includes the neutral dialect, whichever is longer. TestFlight builds expire after 90 days; App Store users update more slowly.
- **Provenance serving the iFly and iCube dialects:** keep for as long as those apps keep their legacy library routes, then drop the two extra listeners.
- Removal is a separate decision each time. To inform it, each app can count, locally, how often it meets a peer that offers only the legacy type.

The running cost of keeping a legacy dialect is one codec, one listener and one advert, all covered by fixtures.

### 3.3 Who sees whose library

This is a product decision and is listed as decision 1. What the protocol does by default, if nothing else is decided:

- Every advert lists the systems it shares (`sys`). A browser hides a peer that shares nothing it can play. iFly and iCube therefore never show each other; each shows a Provenance device only while that device shares Dreamcast-family or GameCube and Wii games; Provenance shows both.
- This is already how Provenance behaves towards unmodified iFly and iCube builds: they list a sharing Provenance device today, because it speaks their dialect. One direction (Provenance on iPad to iFly on Apple TV, one Dreamcast game) was confirmed on devices on 2026-10-31.

## 4. Steps

Each step lands alone and leaves every app working. Steps 6 to 8 can run in parallel once step 4 is released. Per the standing rule, each package release is followed by the pin bump in every app that uses it.

| # | Repo | Change | Done when |
|---|---|---|---|
| 1 | ContinuityKit | Add wire fixtures recorded from ContinuityKit 1.0.2, PVContinuity 1.0.1 and Provenance's `pvlibrary-*.json`; tests that the current code reproduces the iFly ones. No behaviour change. | `swift test` green; patch release |
| 2 | ContinuityKit, iFly | Introduce the profile; every hard-coded iFly constant reads from it; the default profile is iFly's. Minor release; iFly bumps the pin with no source change. | iFly fixtures unchanged; iFly builds |
| 3 | ContinuityKit, iFly | Split model from wire; open file kinds; server rules as dialect options. Add the iCube legacy dialect with its fixtures and the tests carried over from PVContinuity. Breaking, so 2.0; iFly's adapters update in the same change. | Both legacy fixture sets pass; iFly device smoke test (browse, copy, continue) |
| 4 | ContinuityKit | Add the neutral dialect (server, client, consent and pairing gates, filter and paging), the multi-type browser with `pid` de-duplication, and the listener with LAN filter as a second product. Moved from `PVLibrarySharing`. | Provenance's back-compatibility matrix passes inside the package; "trusted on legacy, silent on neutral" test passes |
| 5 | Provenance | `PVLibrarySharing` depends on ContinuityKit and deletes the moved code. | Existing `PVLibrarySharing` tests pass; phase 3 and 4 device checklists from the October document |
| 6 | iCube, PVContinuity | iCube switches to ContinuityKit with its profile; adapters for `PVWebServer` and `PVSyncRules`. Wire unchanged. Then archive PVContinuity with a pointer in its README. | iCube fixtures unchanged; old iCube build and new iCube build pair, browse, copy and continue with each other |
| 7 | iFly | Add `_pvlibrary._tcp`: Info.plist, second listener, advert, browse, `sys` filter. | New iFly and Provenance find each other once, labelled; old iFly still works with both |
| 8 | iCube | Same as step 7. | Same, for iCube |
| 9 | All, wiki | Device matrix (iPhone, iPad, Apple TV; each app pair; old against new). Update the shared-frameworks wiki page. Record the legacy end criteria. | Checklist recorded in this document |
| Later | ContinuityKit and apps | Same-account shortcut and owner data for own devices on the neutral dialect; Provenance-to-Provenance continue; peer-key sign-in for the content server. Each waits on a decision below. | |

Risks:

- **Step 3 is the large one.** It touches iFly's shipping feature. The fixtures from step 1 and ContinuityKit's 22 existing test files are the guard; a device smoke test is still required.
- **iCube's Bonjour type is 16 characters,** one over the RFC 6335 limit. It works with `NetService`, which the package must keep using for that advert.
- **Two listeners in iFly and iCube** means two ports and, on iOS, both stop in the background. Provenance already handles this through scene phase.
- **Binary releases.** ContinuityKit tags are prebuilt frameworks with frozen enums. Opening the file-kind type is an ABI break, which is why step 3 is a major version.

## 5. Decisions for the owner

1. **Should the apps see each other's libraries?** The default above shows a peer only when it shares a system the browsing app can play.
   - *Show (default):* a Provenance user's Dreamcast and GameCube games reach iFly and iCube and back; this is already true today through Provenance's legacy dialects. Cost: iFly's free daily copy limit applies only when iFly is the host, so a Provenance host gives iFly users unlimited copies; and BIOS and saves never cross apps.
   - *Same app only:* simplest to explain and keeps each app's paid features self-contained. Cost: the October work is switched off, and one household with two of the apps copies games by hand.
   - *Per app setting:* each app gets "Show other Provenance apps", default to be chosen. Cost: one more switch in three settings screens.
2. **Which package survives?** Recommended: ContinuityKit, for the reasons in 2.1. The alternative is PVContinuity with ContinuityKit's features ported in; it would keep the GPL licence and the `PVSyncRules` and `PVWebServer` dependencies.
3. **Licence of the iCube behaviour.** Recommended: take it from Provenance's own implementation in `PVLibrarySharing`, so ContinuityKit keeps its licence. Alternative: the owner relicenses PVContinuity's files, which allows direct porting.
4. **Legacy end date.** Recommended: no date now; the rule in 3.2 (two feature releases and six months), revisited with the local counts.
5. **Same-account shortcut across apps.** It needs one CloudKit container that all three apps can read, to compute the same `ic` hash, and one shared salt. Open since October. Until it is settled, cross-app peers use consent or pairing, and owner data does not cross apps.
6. **One identity per device across the three apps?** Sharing the Ed25519 key through the shared Keychain group would make one device one peer, so trusting "Joe's iPad" once covers all three apps. Recommended: yes, opt-in, after step 8.
7. **Does iCube adopt consent-first browsing on the neutral dialect?** The neutral dialect allows an unknown peer to ask and the owner to answer on screen. iCube's current rule is pairing only. Recommended: accept consent on the neutral type and keep pairing-only on the legacy type.
8. **Owner play data in the catalogue.** iFly sends last played, play count and favourite to any browsing peer; iCube deliberately sends none. Recommended for the neutral dialect: none by default, and only to a peer on the same account once decision 5 is settled.
9. **Offline packages.** `.iflypkg` exists; `.icubepkg` is constants only. Recommended: leave both as they are; the reader and writer become available to iCube through the package, and building the iCube feature is separate work.
