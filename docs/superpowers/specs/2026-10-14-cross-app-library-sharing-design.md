# Cross-app library sharing (Provenance ⇄ iFly, Provenance ⇄ iCube, content server)

Date: 2026-10-14. Status: phase 1 shipped; phases 2–5 built 2026-10-15 (see the "as built" sections at the end). Same-iCloud saves (phase 5) are blocked on open question 4.

## Goal

iFly (Dreamcast) and iCube (GameCube/Wii) already let a user browse and copy games from a nearby device running the same app. Provenance should do the same, across apps, in both directions: iFly ⇄ Provenance and iCube ⇄ Provenance. iFly ⇄ iCube is out of scope because the two apps share no systems. Later, `Provenance-Emu/emulator-content-server` (ECS) must be reachable through the same client code.

**Decision:**

- The app-to-app protocol is the **continuity library contract** that iFly and iCube already ship, with additive extensions: app id, extension level, system list and a system filter.
- Provenance speaks each app's current dialect unchanged, as a client and as a server.
- ECS is a second transport behind the same internal source abstraction.

**Out of scope:** the single-game cross-app hand-off and the handoff-session routes (`/api/continuity/manifest|mint|file|continue/*`). The hand-off is iFly's `EcosystemShareCenter` HTTP fetch, which the share sheet is replacing, and Provenance's `PVLibrary/.../EcosystemIntegration/EcosystemFetchService.swift`.

## 1. What exists today

### 1.1 iFly: `iFly/Externals/ContinuityKit` plus `Sources/Core/Continuity`

| Aspect | iFly |
|---|---|
| Package | A local SPM package (Swift 6, depends only on ZIPFoundation). Routes are registered through `ContinuityRouteRegistrar` (`Sources/Core/Continuity/ContinuityRegistrarAdapter.swift`). |
| Transport | Plain HTTP on the main web server. The port tries 80→8080→8000→8888→9000. Library routes answer 404 while sharing is off. |
| Bonjour | `_ifly-continuity._tcp`, peer-to-peer enabled, instance name "iFly <host>" (`ContinuityBonjourAdvertiser.swift`, `Project.swift:95`). |
| TXT | `v=1`, `sid`, `lib=1`, `pid`, `u0..u3` base URLs. `tok` is never published. Game keys `name/plat/gid/md5/ser/stem` appear only on hand-off adverts. `cap/dt/ic` are modelled but unset. **No app id, no system list** (`Discovery/ContinuityTXTRecord.swift`). |
| Auth | `POST /api/continuity/library/auth/start {peerId,name,publicKey,icloudHash?}` → `{authId,serverId,nonce}`, then `auth/complete {authId,peerId,signature}` → `{libraryToken}`. The signature is Ed25519 over `"ifly-continuity-auth-v1\|peerId\|serverId\|"+nonce`. Unknown peers get a host consent prompt with three choices (Share everything / Ask per game / Don't share) and are trusted on first use; the client polls 202 for up to 120 s. A matching iCloud hash skips the prompt (`Server/ContinuityLibraryServer.swift`). |
| Catalogue | `GET .../library/manifest` (Bearer, `ETag`/304) returns `{version:1, peerId, deviceName, games[], catalogVersion?}`. Each game is `{title, platform, md5?, sizeBytes, artKey?, saveStateCount, vmuFileCount?, lastPlayedDate?, playCount?, favorite?, addedDate?}`. The id is `md5`, or `title\|platform\|sizeBytes` when there is no md5. `platform` is a display name ("Dreamcast", "Naomi", "Naomi 2", "Atomiswave"). No pagination. |
| Pull | `POST .../library/pull {gameId}` returns a `ContinuityManifest` (`files[]`, `bios[]`, `saveState?`, `optionalExtras[]`). This is the only metered route: 202 while per-game consent is pending, 403 when declined, **429 when the free daily pulls are used up (Pro is unlimited)** (`ContinuityPullMetering.swift`). |
| File | `GET .../library/file?path=` serves only paths from a granted pull. Range requests get 206, and an unsatisfiable range gets 416. The client resumes from `.part` files and checks SHA-256 per file (`Client/ContinuityPuller.swift:158-198`). |
| What travels | The game file plus its siblings (GDI tracks, Naomi CHD), the **BIOS**, every save state and the VMUs (`ContinuityFileProviderAdapter.swift:84-150`). The receiver recreates `relativePath` verbatim under `FlycastPaths.baseDirectory`. |
| Tests / UI | `ContinuityKitTests` (LibraryServerAuth/Pull/AskPerGame, SameICloudAutoTrust, LibraryPullLiveE2E), app `Tests/Nearby*`. UI: `NearbyLibrarySection`, `NearbyPullView`, `ContinuityShareLibraryToggle`, `LibrarySyncSubscriptionView` (subscriptions scope `.systems(Set<String>)` client-side). |

### 1.2 iCube: `Cores/Dolphin/dolphin-ios/Source/iOS/PVContinuity`

| Aspect | iCube |
|---|---|
| Package | `PVContinuity`. It depends on `../PVSyncRules` and on **iCube's own package named `PVWebServer`** (`addAsyncHandler`, `WebRoute.swift:154`). |
| Bonjour / TXT | `_icube-continuity._tcp` (`Discovery/ContinuityBrowser.swift:13`). TXT uses the same codec family: `v, sid, tok, lib, pid, dt, u0..u3`, plus the game keys `name/plat/gid/md5/crc/disc/rev/stem`. **No app id, no system list.** |
| Auth | Library auth requires an **already paired** peer; otherwise `auth/start {peerId}` returns 403 "not a paired device". Pairing uses a 6-digit code shown on the host: `/pair/start`, then `/pair/complete` with an HMAC proof. Pairing routes exist from app launch (`App/Common/Continuity/ContinuityManager.swift:124-170`). Domain prefixes are `icube-continuity-pair-v1\|` and `icube-continuity-auth-v1\|`. Tokens last 1 h, at most 16 can be live (429 beyond that), and the default grant is `askPerGame`. |
| Catalogue | `GET .../library/catalog` returns `{version:1, sourceDevice, entries[{key, game{gameID?,md5?,crc32?,displayName,platform,discNumber?,revision?}, sizeBytes, hasArtwork}]}`, where `key` is `GameIdentity.stableKey`. The decoder **rejects any version outside 1...1** (`Model/ContinuityLibraryCatalog.swift`). |
| Pull / file | `GET .../library/manifest?key=` returns the disc image only. `GET .../library/file?key=&path=` re-checks exclusion and supports Range. |
| What travels | **The game file only. No saves, memory cards, INIs or config** (`Server/ContinuityLibraryManifestBuilder.swift`, `libraryUserDataKinds = []`). The receiver recreates the path under the iCube User directory and registers it (`ContinuityLibraryBrowseController.swift:116`). |
| Tests / UI | `PVContinuityTests` (LibraryServer, LibraryManifest no-owner-data, Wire, Trust, PairingServer, Puller). UI: `ContinuityLibrarySharingView`, `ContinuityPeerLibraryView`. |

### 1.3 Divergences that matter

| | iFly | iCube |
|---|---|---|
| `GET /api/continuity/library/manifest` | **The whole catalogue** | **One game's file set** (`?key=`) |
| `/library/file` query | `?path=` | `?key=&path=` |
| `/library/art?key=` | Opaque artKey | stableKey |
| Unknown peer | Consent prompt, trusted on first use | Must pair with a code first |
| Crypto domain | `ifly-continuity-*-v1` | `icube-continuity-*-v1`. **Signatures do not verify across apps.** |
| Platform value | Display names | `gc`/`wii` in code (`ContinuityPaths.swift:102-103`). The coordinator reports "GameCube"/"Wii", so map both. |
| Owner data in a pull | BIOS, all states, VMUs | None |
| Catalogue version check | Not enforced | Enforced |

iCube's package is the newer and cleaner one. Its catalogue and manifest are separate, its decoding is version-checked, it shares the least owner data, and it re-checks exclusion on every file. iFly's is richer: consent-first trust, iCloud auto-trust, ETag caching, subscriptions and art thumbnails. Both share one design, but **the same paths mean different things** in each, so one HTTP listener cannot serve both dialects.

### 1.4 Content server (ECS)

The repo is real and contract-first. It has an OpenAPI contract (`packages/protocol/openapi/openapi.yaml`, snapshot `docs/protocol/v1-surface.json`) and a generated Swift client with resume logic (`clients/swift`, `ResumePlanner.swift`). It states that "apps stay adapters" (`docs/workstreams/app-adapters.md`).

| Aspect | ECS |
|---|---|
| Base | `/api/v1`. `GET /capabilities` reports protocol major/minor, feature flags and `maxPageSize: 100`. Errors are `problem+json`. |
| Discovery | `_pvcontent._tcp`. The TXT allowlist is `id, v, tls, pair, name` (`packages/discovery/src/txt.ts`). A manual URL also works. |
| Catalogue | `GET /items?libraryId=&cursor=` returns `{items[{id,title,systemIdentifier,md5,crc,revision,…}], nextCursor}`. **There is no system filter** (`apps/server/src/routes.ts:302-320`). `GET /systems` returns Provenance's dotted ids. |
| Manifest / file | `/items/{id}/manifest` lists files as `{kind(rom\|bios\|save_state\|…), relativePath, size, sha256, md5, crc, required, contentPath}`. `/files/{id}/content` supports Range (206 plus a strong ETag); a 200 reply to a ranged request means restart from zero. |
| Auth | Bootstrap, then login, then device tokens. Minting a device token needs an `admin`-scoped token (`requireUser(request,'admin')`). Guest grants exist. `bios` and `system_file` are restricted kinds. |

### 1.5 Provenance pieces reused

| Piece | Where |
|---|---|
| Hummingbird engine; Bonjour `_http._tcp` | `PVWebServer/Sources/PVWebServerSwift/PVModernWebServer.swift`. Its routes are hardcoded in `buildHTTPRouter`. The uploader defaults to GCD (`useModernWebServer` is false, `PVSettingsModel.swift:707`). |
| Browser/advertiser pattern | `PVNetplay/.../NetpacketTransport.swift:76`, `PVNetplayBonjourDiscovery.swift` |
| System ids | `PVPrimitives/Sources/PVSystems/SystemIdentifier.swift` |
| Identity / hashing | `PVGame.md5Hash` is the primary key and is **uppercase**. MD5 is taken over the primary file with headers stripped (`GameImporterDatabaseService.swift:945-1006`). |
| Importer | `GameImporter.addImports(forPaths:targetSystem:)` (`GameImporter.swift:927`) |
| Deep link / keychain | `provenance://open?md5=` (`PVAppDelegate+Open.swift:375`). Keychain group `com.joemattiello.shared` (`CrossAppEntitlementPublisher.swift`). |

## 2. Architecture

The new package is **`PVLibrarySharing`** (Tier 4). It depends on PVPrimitives, PVLogging, Hummingbird, Network and CryptoKit. It has **no Realm**, so `swift test` runs on the host. Library glue lives in PVLibrary (`LibrarySharingProvider`) and the screens live in PVUI.

```
Core/       RemoteItem, RemoteManifest, RemoteFile, SystemMap, TXT codec (legacy + ext keys),
            PairingMath(domain:), PeerIdentity, TrustStore, GrantStore
Sources/    protocol LibrarySource { catalogue(filter,cursor); manifest(item); download(file,to,resumeFrom); artwork(item) }
            IFlyDialectSource, ICubeDialectSource, PVLibrarySource (ext), ECSSource
Server/     DialectListener ×3 (Hummingbird, one port per advertised type):
            iFly routes / iCube routes / _pvlibrary routes
Discovery/  PeerBrowser (four types, de-dupe by pid), Advertiser (one NetService per type, own port)
```

Provenance cannot reuse either app's package:

- **iCube's `PVContinuity`** would drag in a second package named `PVWebServer`, which clashes with Provenance's.
- **iFly's ContinuityKit** sits inside the iFly repo with iFly constants.

Provenance therefore writes its own codecs, pinned by **golden-JSON fixtures** copied from both apps' wire tests.

## 3. Protocol

### 3.1 Legacy dialects (frozen)

Provenance implements both dialects exactly as shipped: the same routes, domain prefix, id scheme and platform strings, and the same pairing replies. That includes iCube's 404 after a valid pairing proof when idle (`ContinuityPairingServer.swift:243-247`).

**Each dialect gets its own listener port**, advertised under that dialect's type. URLs already travel in each advert's `u0..u3` and SRV record, so clients never learn about the other ports.

On each dialect, the served catalogue contains **only the systems that app runs** (§3.3). Unmodified iFly and iCube builds can therefore browse Provenance with no change, and they never see its NES library.

### 3.2 Extension v1.1 (additive; all three apps adopt it)

Nothing existing changes. TXT `v` stays `1` and the catalogue `version` stays `1` (iCube would reject 2). Every addition is optional and ignored by old peers.

**TXT keys:**

| Key | Value |
|---|---|
| `app` | `provenance` / `ifly` / `icube` / `ecs` |
| `lx` | `1`: the library-extension level. Absent means legacy only. |
| `sys`, `sys1`, `sys2`… | Systems with at least one shareable item, as `SystemIdentifier` raw values minus the `com.provenance.` prefix. Case is preserved and compared case-insensitively. Example: `dreamcast,naomi,naomi2,atomiswave`. Each key holds at most 240 bytes. Provenance's ~70 ids come to about 480 bytes, so 2–3 keys next to `u0..u3`/`pid`/`sid`. `sys=*` means unspecified. |
| `cv` | Optional: the first 8 hex digits of the catalogue version, so a client can skip an unchanged refetch |

How peers use `sys`:

- Provenance hides peers whose `sys` doesn't intersect its playable systems.
- iFly and iCube hide a Provenance device that has none of their systems.

**Shared service type `_pvlibrary._tcp`.** Peers advertise it alongside their legacy type during the transition. Its route set is iCube's shape (`library/catalog`, `GET library/manifest?key=`, `library/file?key=&path=`, version-checked), plus:

- iFly's consent-first auth body (`name`, `publicKey`, `icloudHash?`)
- ETag/304 on the catalogue
- `art?key=`
- the neutral prefixes `pvlibrary-pair-v1|` and `pvlibrary-auth-v1|`
- `/pair/complete` returning 200 `{paired:true}`

The type is not `_pvcontent._tcp`: an ECS client would call `/api/v1/capabilities` on it and get a 404.

**Catalogue filter and paging.** These apply on all three catalogue routes, and iFly and iCube may add them to their legacy routes as well:

- `?systemIdentifier=com.provenance.dreamcast,com.provenance.naomi` takes full dotted ids and uses ECS's field name. Old servers ignore it, so **clients always filter locally too**.
- `?limit=N&cursor=…` is opt-in: without `limit` the full list comes back, as today. The response adds `nextCursor`, where null or absent means the list is complete. This matches the ECS `Page` shape.
- Entries gain optional `systemIdentifier`, `md5`, `crc` and `serial`.

### 3.3 System mapping (`SystemMap`, unit-tested)

| App | Wire value | `SystemIdentifier` |
|---|---|---|
| iFly | "Dreamcast", "Naomi", "Naomi 2", "Atomiswave" | `.Dreamcast`, `.NAOMI`, `.NAOMI2`, `.Atomiswave` |
| iCube | `gc` or "GameCube"; `wii` or "Wii" (case-insensitive) | `.GameCube`, `.Wii` |
| ECS / `_pvlibrary` | dotted `systemIdentifier` | Identity |

An unknown string maps to nil. The item shows greyed out ("Not supported by Provenance").

### 3.4 Identity

Each item is addressed by its dialect id (iFly `id`, iCube `key`, ECS `id`) and treated as opaque.

The local "In your library" match uses `(systemIdentifier, lowercased md5, size)`. The fallbacks are iCube's `gameID+disc+rev` and iFly's serial.

MD5s **agree only for single-file, headerless images** (GC `.iso`/`.rvz`, DC `.chd`/`.cdi`):

- For CD sets, Provenance hashes the `.cue`/`.m3u`/`.gdi` text, which it also rewrites during import (`cleanCueFile`).
- It strips headers on some systems.
- Its MD5s are uppercase.

The badge is therefore best effort. After a copy lands, the importer's own MD5 check handles de-duplication. Integrity rests on each file's **SHA-256**.

### 3.5 Transfer

- Each file downloads with `GET` plus `Range: bytes=N-` into `<staging>/<item>/<relativePath>.part`. After its SHA-256 checks out, it is renamed into place. Small files go first.
- A ranged GET that comes back 200 discards the partial file, as ECS's `ResumePlanner` does.
- **Multi-file games:**
  - GDI and Naomi CHD siblings are already listed by iFly.
  - When Provenance serves a cue/bin or m3u set, it sends the primary file plus `PVGame.relatedFiles`, keeping the directory shape.
  - Folder games (DOS, ScummVM) send every file in the folder.
- **Receiving.** Provenance never mirrors a peer's layout. Files are staged under `Imports/` (`Library/Caches` on tvOS). The **primary file** then goes to `addImports(forPaths:targetSystem:)` with the mapped system, so `.chd`, `.iso` and `.bin` don't prompt.
- **Serving a dialect.** The receivers recreate `relativePath` verbatim:
  - iFly: Provenance emits `ROMs/<file>` (`FlycastPaths.romsDirectory`).
  - iCube: a path under its User directory (§6, Q6).
- **Hashing.** Both pullers require a SHA-256 for every file. Provenance computes it lazily on first pull and caches it by `(path, size, mtime)`. The UI shows "Preparing…" while a large image hashes.

### 3.6 What is shared; trust

**Provenance as a server:**

| Kind | Default |
|---|---|
| ROM or disc image plus siblings | Yes. Can be excluded per game or per system. |
| Artwork | Yes |
| BIOS | **No**, matching the ECS restriction. On the iFly dialect `bios[]` is sent empty. *To verify:* that iFly's receiver accepts this and falls back to its own BIOS check. |
| Saves, states, battery saves | **No** for other users. Opt-in for same-iCloud peers in phase 5. This follows iCube. |

**Provenance as a client:**

- BIOS files are imported only after the user confirms.
- iFly states and VMUs are skipped, because states from another core don't load.

**Trust model:**

- Each install has an Ed25519 identity, with the private key in the Keychain.
- Trust and grant stores follow iCube's shapes: `everything`, `askPerGame` or `denied`, with `askPerGame` as the default.
- When Provenance is the client:
  - iFly peers use consent auth and show "Waiting for approval on <device>".
  - iCube peers need code pairing first, and a 404 after a correct proof counts as paired.
- When Provenance is the server, it offers consent auth on the iFly listener and on `_pvlibrary`, and code pairing on the iCube listener.

**LAN-only guarantees:**

- Listeners prohibit the cellular interface.
- A request is accepted only if it comes from loopback, a link-local address, or the on-link prefix of one of the listener's interfaces. That last rule covers global IPv6 on home networks.
- Sharing off stops the listeners.
- Tokens are scoped to a peer and last 1 h.
- File routes serve only paths listed in the manifest, and keys containing `..`, `/` or `\` are rejected.
- Traffic is plain HTTP, the same as the peers. This is documented: it gives no confidentiality.

**Metering.** Provenance meters nothing. As a client it explains iFly's 429 ("free daily copies used up; iFly Pro removes the limit") and its 202.

### 3.7 ECS through the same abstraction

| | App peer | ECS (`ECSSource`, vendored `clients/swift` models) |
|---|---|---|
| Discovery | Legacy types and `_pvlibrary._tcp` | `_pvcontent._tcp`, or a manual HTTPS URL |
| Auth | Nonce signature | Login, then a read device token in the Keychain. A reader-role user without `admin` scope falls back to the session token. |
| Catalogue / filter | Dialect route plus `systemIdentifier` | `/items?libraryId=&cursor=` and local filtering until the filter ships |
| Manifest / file | Dialect routes | `/items/{id}/manifest` (`rom` → game, `bios` → opt-in), `/files/{id}/content` plus Range |

Proposed additive ECS changes:

1. A `systemIdentifier` filter on `GET /items`.
2. Allow TXT `app=ecs` and `sys=*`.
3. Optional peer-key auth with the `pvlibrary-*` prefix, so a LAN server can admit a paired device without a password.
4. Allow a reader to mint a read-scoped device token.

## 4. Provenance integration

**Listeners and advertising:**

- Hummingbird listeners run on their own ports, starting at 8484 and taking the next free port. They are separate from the uploader and its toggle.
- They run while "Share this library" is on. On iOS that means while the app is in the foreground; tvOS can also serve when idle.
- `_pvlibrary._tcp` is always published while sharing is on.
- `_ifly-continuity._tcp` is published only when the shared catalogue contains a Dreamcast-family game, and `_icube-continuity._tcp` only when it contains a GameCube or Wii game.

**Info.plist.** Every Provenance and ProvenanceTV plist adds `_pvlibrary._tcp`, `_ifly-continuity._tcp`, `_icube-continuity._tcp` and `_pvcontent._tcp`, and updates `NSLocalNetworkUsageDescription`. `ProvenanceTV-Lite-Info.plist` currently lacks even `_http._tcp`. iFly and iCube add `_pvlibrary._tcp` when they adopt v1.1.

**UI:**

- Settings › Library › Share this library: the switch, the systems to share, and Trusted devices.
- Each game's context menu gets "Don't share".
- Library › Nearby libraries shows peer tiles with an app badge. Each peer's catalogue is grouped by system, filtered to systems Provenance can play, and badged "In your library".
- A copy reports progress in `ImportStatusView`. When it finishes, Play opens the game through `provenance://open?md5=`.
- ECS servers are added under Settings › Library › Content servers.
- tvOS is both a client and a server, with focus-friendly code entry.

## 5. Phases (one session each)

| # | Scope | Acceptance |
|---|---|---|
| 1 | Core plus discovery plus **client browse** for both dialects: TXT codecs, SystemMap, identity, iFly consent auth, iCube code pairing (with the 404 rule), catalogue fetch, local filter, Nearby list behind a feature flag | Golden fixtures from iFly `LibraryManifestCodecTests`/`AdvertisementCodecTests` and iCube `WireTests` decode, and `swift test` is green. **On device, an iCube peer is actually discovered.** `icube-continuity` is 16 characters, one over the RFC 6335 limit of 15, so an empty browse must not pass silently. Each peer lists only playable systems. |
| 2 | **Client pull + import**: iFly pull (202/403/429), iCube manifest, Range resume, SHA-256, staging, import with target system, GDI multi-file, artwork | A DC GDI and a GC RVZ each copy, import under the right system and boot. Wi-Fi cut at 50 % resumes without starting over. A tampered byte fails the check. |
| 3 | **Provenance as server, legacy dialects**: three listeners with one port per type, the LAN filter, the SHA-256 cache, the iFly dialect (consent, ETag catalogue, pull, file), the iCube dialect (pairing replies mirrored exactly, catalog, manifest, file), per-dialect system filtering, advertising, Share settings | Unmodified iFly lists only DC/Naomi/Atomiswave and copies one game that boots. Unmodified iCube pairs, lists GC/Wii and copies one game. A test asserts that no BIOS or save is listed in any manifest. |
| 4 | **Extension v1.1**: `app/lx/sys/cv`, `_pvlibrary._tcp` routes, `systemIdentifier` filter, cursor paging, neutral prefixes. Provenance ⇄ Provenance moves onto it. Hand the spec and fixtures to the iFly and iCube sessions. | Two Provenance devices browse a 5,000-game library in pages of 200. A pre-v1.1 iFly or iCube still interoperates (back-compat matrix). |
| 5 | **ECS readiness + polish**: `ECSSource` (manual URL, login → token, items/manifest/content), file the ECS proposals, opt-in saves for same-iCloud peers, tvOS server | List and copy from `ecs serve` fixtures. A guest token can't fetch BIOS. A ranged read matches the local bytes. |

**Two-device release checks:**

- iPhone ↔ Apple TV and iPad ↔ iPhone, in both directions, for each pair: Provenance↔iFly, Provenance↔iCube and Provenance↔Provenance.
- A copy over peer-to-peer Wi-Fi with no router.
- Revoking trust mid-copy gives a clean 401.
- Turning sharing off hides the device within one browse cycle.
- Denying Local Network permission shows the Settings hint.
- A network that hands out global IPv6 still connects.

## 6. Open questions (default in bold)

1. Should the three apps share one extracted continuity-core repo, or keep three codecs pinned by fixtures? **Fixtures now; extract after phase 4.**
2. Should app peers eventually move to the ECS `/api/v1` read profile? **Not in v1.x. Revisit once ECS ships.**
3. Should the shared type be its own `_pvlibrary._tcp`, or `_pvcontent._tcp` with an `app=` discriminator? **`_pvlibrary._tcp`.**
4. Cross-app same-iCloud auto-trust needs one CloudKit container for computing `ic` (user record ids differ per container) and a shared salt. **Agree on a container all three are entitled to (sibling containers landed in 2c5b3933b3). Until then, use consent or pairing.**
5. Should the Ed25519 identity be shared across the team's apps on one device through `com.joemattiello.shared`? **Yes, opt-in. One device is then one peer.**
6. Which User-directory path should the iCube dialect emit for a GC/Wii file? **Confirm with the iCube session; default `Games/<file>`.**
7. Should BIOS be sent on the iFly dialect, which marks BIOS as required? **No, if iFly tolerates an empty `bios[]`. Verify on device.**
8. Should Provenance meter pulls? **No.**
9. Plain HTTP on the LAN? **Yes, the same as the peers. Revisit together with ECS TLS (`tls=1`).**
10. Sync subscriptions (auto-copy new games)? **After phase 5.**
11. Do the sharing types also go in tvOS Lite's plist? **Yes. Lite still has to compile and launch.**

## Answers received after the first draft

- **iFly, empty BIOS list (open question 7):** accepted. "Required" is checked per listed file only; a game is bootable when no listed `required` gameFile/bios is missing and at least one gameFile completed (ContinuityKit/Client/PullFailure.swift:18-28). Gotcha: `ContinuityManifest` decodes `bios` and `files` as non-optional arrays (Model/ContinuityManifest.swift:58-59), so Provenance must always send `"bios": []`, set `required` explicitly on every FileDescriptor, and use the kinds exactly (`gameFile` for `ROMs/<file>`). The receiver boots with its own BIOS folder; a missing NAOMI/Atomiswave BIOS surfaces as iFly's normal boot message, not a pull failure. SHA-256 is used for skip-if-present, so per-file SHA-256 stays.
- **iCube, pairing when idle (finding 2):** confirmed by the iCube session. `pair/complete` stores the trust first and returns 404 "no active handoff session" whenever no handoff session is up; treat that 404 as paired, then library pulls go through `library/auth/start` + `complete`.
- **iCube, served folder (open question 6):** use relativePath `Software/<filename>`, not `Games/<file>`. iCube resolves relativePath against its Dolphin User root (`ContinuityPaths.absoluteURL`, Source/iOS/App/Common/Continuity/ContinuityPaths.swift:26) and registers the written path with the library cache; `Software/` is the only folder its scanner reads. The `gc`/`wii` codes are only per-platform sidecar naming. Keep the filename as-is (iso/gcm/gcz/rvz/wbfs/ciso/wia/dol/elf/wad).

## Phase 2 as built (2026-10-15)

- **Staging is not `Imports/`.** Copies land in `Library/Caches/LibrarySharing/Incoming/<app>-<hash>/files/<relativePath>`, a different location from the one §3.5 names. `Imports/` is watched: the watcher would pick up half-written `.part` files, or queue finished ones without the mapped system before the copy hands them over, and the importer's queue de-duplication would then drop the call that carries the system. `addImports(forPaths:targetSystem:)` takes paths anywhere and moves the files into `ROMs/`. Every game file of the set is handed over, the same as a ROM-folder scan.
- **The folder is named by a hash** of (peer id, app, item id). iFly ids are `title|platform|size`, so a title could carry `/` or `..`. Every `relativePath` is checked to stay inside the folder before anything is written (`LibraryStaging.containedURL`).
- **The pull manifest is cached** in the staging folder. iFly's `pull` is metered and can prompt per game, so a resumed copy, whether after a dropped connection or a relaunch, re-authenticates and fetches only files. Only a 404 on the file route ("not part of a granted pull") requests the manifest again, and only once.
- **Transfer rules:**
  - Files go smallest first, each through `<file>.part` with `Range: bytes=N-`.
  - The copy starts a file over from zero when the host answers 200 to a ranged request, sends a 206 for another range, or answers 416. Two restarts are allowed per file.
  - A short body resumes from what arrived.
  - On a 401 the client re-authenticates once.
  - SHA-256 is compared case-insensitively, and a mismatch deletes the `.part`.
  - File downloads use a 60 s idle timeout, not the 8 s browse timeout.
- **Copied:** game files only. BIOS (§3.6: user confirmation first) and saves are left on the host and logged. The BIOS confirmation flow is not built.
- **Cleanup:** `LibraryStaging.sweep()` runs when Nearby Libraries opens. It removes a handed-off folder once the importer has emptied it, or after 24 h if the importer skipped a duplicate. An abandoned partial copy is removed after 7 days.
- **Not done:** progress in `ImportStatusView` (the row shows it instead), "Play" through `provenance://open?md5=` once the import lands, and importing the peer's artwork.

### Phase 2 device checklist

- [ ] iFly host, Dreamcast GDI: tap Copy. The row goes from Connecting to Copying N% to Checking, then Importing. The game appears under Dreamcast and boots.
- [ ] iFly host with Ask per game: the row shows "Waiting for approval on <device>". Allow, and the copy proceeds. Deny gives "The other device declined this copy."
- [ ] iFly host past its free daily copies: the row shows the iFly Pro limit message (HTTP 429).
- [ ] iFly Naomi zip with companion CHD: both files arrive and the game imports as NAOMI. Watch that `ArchiveCompanionLayout` still pairs them when the source is outside `Imports/`.
- [ ] iCube host, GameCube `.rvz` and Wii `.wbfs`: they copy, import under GameCube/Wii without a system prompt, and boot.
- [ ] Turn Wi-Fi off at about 50 % of a large image, then on, then tap Retry. The log shows `Range: bytes=N-` on the file request, and no second `library/pull` on iFly.
- [ ] Kill Provenance mid-copy, relaunch, open the peer and tap Copy: the copy resumes.
- [ ] Tamper test: serve a file whose bytes differ from the manifest hash (a debug iFly build). The copy fails with "arrived damaged" and leaves no `.part`.
- [ ] Copy a game already in the library: the importer skips the duplicate, and the staging folder is gone within 24 h.
- [ ] tvOS: Copy and Stop are reachable with the remote. The copy lands in the library on Apple TV, where staging under Caches is expected.
- [ ] BIOS and VMU/state files are never written anywhere (check `Library/Caches/LibrarySharing`).

## Phase 3 as built (2026-10-15)

- **NWListener, not Hummingbird.** `LibraryHTTPListener` is a small HTTP/1.1 server, with keep-alive, `Content-Length` bodies, and file bodies streamed in 256 KB chunks with each send awaited. Each dialect gets its own listener on the first free port from 8484, with `prohibitedInterfaceTypes = [.cellular]` and peer-to-peer Wi-Fi on. Every connection goes through `LANFilter`: loopback, link-local, or the on-link prefix of a local interface (which admits global IPv6). Cellular, `utun` and `ipsec` interfaces never count as LAN. Hummingbird would have hidden the remote address and the per-port Bonjour handling, and would have pulled the ServiceContext version caps into this package.
- **Adverts use `NetService`.** `NWListener.service` can't be trusted with `_icube-continuity._tcp` (16 characters), and iCube publishes with NetService itself. The TXT record is `v=1`, a fresh `sid`, `lib=1`, `pid`, and `u0..u3` (Wi-Fi IPv4 URLs first). `_ifly-continuity._tcp` is published only while the shared library holds a Dreamcast-family game, and `_icube-continuity._tcp` only while it holds a GameCube or Wii game. Adverts are refreshed when the app becomes active and when the shared systems change.
- **iFly dialect** (`IFlyDialectServer` with `ConsentGate`): consent auth that mirrors `ContinuityLibraryServer`. A trusted peer gets a token silently. A stranger gets one prompt and 202 until the owner answers; "Share Everything" and "Ask for Each Game" trust the peer on first use, "Don't Share" denies it.
  - The catalogue carries an `ETag`, and a matching request gets 304.
  - Pull manifests put the primary file first. iFly boots the first `gameFile`, as the iFly session confirmed.
  - Paths are `ROMs/<file>`, or `ROMs/<primary stem>/<path>` for a set, so GDI tracks sit next to the `.gdi`.
  - Every manifest has `"bios": []` and `"optionalExtras": []`, and `required` and `size` on every file.
  - The file route serves only paths from a granted pull. "Ask for Each Game" answers 202, then 403 on a refusal. No route ever answers 429.
- **iCube dialect** (`ICubeDialectServer`): `pair/start` and `pair/complete` are mirrored exactly. That covers 3 pairings in flight, 3 code tries, 202/401/403/410, and the trust stored before the **404 "no active handoff session"** answer.
  - Library auth requires a paired peer and allows at most 16 live tokens.
  - Catalogue keys are iCube's `stableKey` (`id:<GAMEID>|d0|r-1` when `PVGame.romSerial` holds the game id, else `md5:<md5>`).
  - The manifest lists the image only, as `Software/<file>`.
  - The file route re-derives the manifest. For an "Ask per game" peer it holds the request open for the owner's answer, as iCube does.
- **Trust:** `FileHostTrustStore` keeps peers and grants in `Application Support/LibrarySharing/trusted-peers.json`; it holds public keys only. A known peer id can never swap keys. The host signs with the same Keychain identity the client uses.
- **SHA-256** is computed on the first pull and cached by `(path, size, mtime)` in `hashes.json`.
- **App:**
  - `LibrarySharingService` (PVUI) starts the host while the setting is on, the app is active and the flag is on. iOS stops it in the background, through `ProvenanceApp`'s scene-phase handler.
  - Owner prompts are `UIAlertController`s on top of whatever is showing.
  - `RealmSharedLibrary` reads `PVGame` per request: the primary file plus related files, with paths relative to the primary's folder.
- **Tests:** Provenance's own iFly and iCube clients run against these servers, both in process and over a real socket with URLSession (range resume included). The JSON is decoded with structs that copy each peer's required fields. One test asserts that no manifest lists anything but `gameFile`.
- **Not done:**
  - A "Don't share" action on a game's context menu (per-system exclusion is built).
  - Serving from tvOS Top Shelf or background.
  - `NSBonjourServices` in the Tuist dev apps.
  - Advert refresh after each import: adverts refresh on activation instead.

### Phase 3 device checklist

Manual verification, 2026-10-31: Joe confirmed successfully copying one Dreamcast game from Provenance on iPad to iFly on tvOS. This verifies that copy direction only. Game format/build numbers and launch after copying were not recorded.

- [ ] Share This Library on (iPhone). Unmodified iFly on another device lists the Provenance device and shows only Dreamcast/NAOMI/Atomiswave games. iFly's consent prompt appears on the Provenance device.
- [ ] iFly copies a single-file `.chd` and a GDI set from Provenance, and both boot in iFly. With Play, iFly boots the `.gdi`, not a track.
- [ ] "Ask for Each Game": iFly shows waiting, the Provenance device shows "wants to copy <game>", and Allow lets the copy proceed. "Never Allow This Device" moves the device to Nothing in Trusted Devices.
- [ ] Unmodified iCube finds Provenance under `_icube-continuity._tcp`. Watch for the 16-character type: the Provenance log should show "published _icube-continuity._tcp". iCube shows "Pair", the code appears in an alert on Provenance, and pairing completes even though Provenance answers 404.
- [ ] iCube lists only GameCube/Wii games and copies one into `Software/`. It appears in iCube's library and boots.
- [ ] Turn Share This Library off: both peers drop the device within one browse cycle, and a copy in flight fails cleanly.
- [ ] Remove a device in Trusted Devices mid-copy: its next request gets 401/403.
- [ ] Background the iOS app: the listeners stop (peers lose the device), and they come back on return.
- [ ] Apple TV as the host: same checks with the remote. Prompts appear over any screen.
- [ ] A network that hands out global IPv6: a peer reaching the host over IPv6 is accepted. A peer through a VPN or a routed subnet is refused (watch for "refused" in the log).
- [ ] Provenance ⇄ Provenance over the legacy dialects: device A's Nearby Libraries lists device B under the iFly and iCube types, and copies work.

## Phase 4 as built (2026-10-15)

- **The v1.1 plan went to the iFly and iCube sessions before it landed.** It is in the shared notes folder as `library-sharing-v1.1-plan.md` together with the `pvlibrary-*.json` fixtures. Both sessions reported no conflicts, plus these constraints, which Provenance follows:
  - Keep `v` and `sid` in every advert. iFly and iCube drop a record without them.
  - Never start a new key with `u` followed by a digit.
  - Leave the per-game keys off library adverts.
  - Keep catalogue and manifest `version` at exactly 1 on the legacy types.
  - Name the advert "Provenance on <device>".
  - Keep publishing `_ifly-continuity._tcp`, because iFly can't browse `_pvlibrary._tcp` until it adopts v1.1.
  
  Adoption on their side is left to the owner's schedule.
- **TXT** (`LibraryAdvertTXT`):
  - Every advert adds `app=provenance` and `lx=1`.
  - `sys`, `sys1`… hold the compact ids, sorted, at most 240 bytes per key. An empty value means nothing shared; `*` means unspecified. `.Unknown` is never listed.
  - `cv` is optional and not sent yet.
  - The legacy adverts list only their own systems; `_pvlibrary` lists every shared system.
  - `PeerAdvertisement` decodes all of these. `mayServe(_:)` hides a peer whose `sys` misses every playable system, and a legacy advert with no `sys` is always shown.
- **Discovery:**
  - `PeerBrowser` also browses `_pvlibrary._tcp`.
  - `DiscoveredPeer.deduplicated` keeps one row per `pid` and prefers `_pvlibrary`.
  - Nearby Libraries hides the device's own adverts by comparing `pid` with its identity.
- **`_pvlibrary._tcp` server** (`PVLibraryDialectServer`), always published while sharing is on:
  - Consent auth through `ConsentGate` with `pvlibrary-auth-v1|`.
  - Code pairing through `PairingGate`, shared with the iCube dialect, with `pvlibrary-pair-v1|`. A right code answers 200 `{"paired":true}` and grants "Ask per game", so the next browse needs no prompt.
  - The catalogue uses iCube's shape: `version` 1, dotted `platform` and `systemIdentifier`, and an optional `serial`. It carries an `ETag` and supports 304.
  - Manifest paths are `<file>`, or `<primary stem>/<path>` for a set, with the primary first. "Ask per game" runs on the manifest route (202, then 403 on a refusal), and the file route serves only granted keys.
- **Filter and paging** (`CatalogueQuery`):
  - `?systemIdentifier=` takes dotted or compact ids.
  - `?limit=` (capped at 500) and `cursor` are opt-in. The cursor is `<first 8 of the version hash>.<offset>`. A cursor from a changed catalogue gets 410, and the client starts over once.
  - The legacy iFly and iCube catalogue routes accept the same query items. Old clients send none and get the unpaged list.
- **Client** (`PVLibrarySource`):
  - Asks for the playable systems, 200 per page, and filters locally too.
  - Caches the whole list under the first page's `ETag`.
  - Polls the manifest through 202.
- **Hosting:**
  - A third listener runs on the next free port.
  - Adverts are republished only when their `sys` set changes.
  - The URL candidates end with `<host>.local` (`ProcessInfo.hostName`), which is the one that works on router-less peer-to-peer Wi-Fi.
  - `RealmSharedLibrary` now reads every non-excluded system, caches the read for 30 s, and the systems list in settings shows the systems in the library.
- **Info.plists:** all ten list `_pvlibrary._tcp` and `_pvcontent._tcp` (phase 5), and `NSLocalNetworkUsageDescription` mentions copying and sharing.
- **Back-compat matrix** (tests):
  - Old iFly client against a v1.1 Provenance: unpaged, unfiltered.
  - Old iCube client: unchanged auth, and `version` 1.
  - v1.1 client against a server that ignores the filter and `limit`: filtered locally.
  - Legacy advert with no `sys`: shown.
  - Catalogue `version` 2 is rejected.
  - An iFly-domain signature fails on `_pvlibrary`.

### Phase 4 device checklist

- [ ] Two Provenance devices, both sharing: each lists the other once (not three times), labelled Provenance, and neither lists itself.
- [ ] Browse a large library (seed thousands of games): the log shows `limit=200` pages. The list completes, and a second open is a single 304.
- [ ] Copy a GDI set and a `.chd` from A to B, and a GameCube ISO from B to A. Each lands under the right system and boots.
- [ ] Turn a system off in Share This Library on A: within one browse, B no longer lists those games. The `_ifly-continuity._tcp` advert disappears once no Dreamcast-family system is shared.
- [ ] Unmodified iFly and iCube against the same v1.1 Provenance still browse and copy (phase 3 checklist), and they don't show the `_pvlibrary` advert.
- [ ] Router-less: two iPhones, Wi-Fi on but not joined to a network. Peer-to-peer browse finds the other device, and the copy uses the `.local` URL.
- [ ] Change the library while B is paging (import on A mid-browse): B restarts and shows the full, new list.

## Phase 5 as built (2026-10-15)

- **`ECSSource` is a client only**, behind the same `LibrarySource` as the app peers, so browsing and `LibraryPuller` (staging, Range resume, SHA-256) are unchanged. `PeerApp.contentServer` (`ecs`) names it.
  - Capabilities: `GET /api/v1/capabilities` must report protocol major 1, and `limits.maxPageSize` sets the page size.
  - Auth: a token stored in the Keychain (`KeychainECSTokenStore`, one item per server URL), else `POST auth/login`, then `POST device-tokens {name, scopes:["read"]}`. A reader without `admin` scope can't mint one and keeps the session token, as §3.7 expects. A 401 signs in again once.
  - Catalogue: `GET /libraries`, then `GET /items?libraryId=&limit=&cursor=` for each library, every page. Filtering is local, because the server has no system filter yet (proposal 1).
  - Manifest: `rom` maps to a game file, and every other kind (`bios`, `save_state`…) is left behind.
  - Content: `GET <contentPath>` with Range, where 200 to a ranged request means start over. A `contentPath` on another host is refused.
- **UI:** Settings › Library › Nearby Libraries › Content Servers holds Add (address, username, password), delete, and the shared browse/copy screen. The password is used for one sign-in and never stored; the server list (URL and username) is in UserDefaults.
- **Not built:**
  - `_pvcontent._tcp` discovery. ECS TXT (`id, v, tls, pair, name`) carries no `lib`/`u0`, so it needs its own decoder. The type is already in every Info.plist.
  - Artwork from ECS.
  - Opt-in saves for same-iCloud peers, **blocked on open question 4**: all three apps need one CloudKit container for the `ic` hash, and nobody has agreed on one. Until then every peer goes through consent or pairing, and saves never travel.
  - tvOS serving needs nothing more. tvOS keeps the host up for as long as the app runs, since it never stops on background (`LibrarySharingService.handleScenePhase`).
- **Tests:** `ECSSourceTests` runs against an in-process fake of `apps/server/src/routes.ts`. They cover paging, local filtering, device-token minting and reuse, the reader fallback, re-sign-in, a wrong password, a newer protocol, ROM copy with Range resume, BIOS left behind, restart on 200, and a refused foreign `contentPath`. Not yet run against a live `ecs serve`; that's on the checklist.

### ECS proposals (drafts; not filed)

To file on Provenance-Emu/emulator-content-server once the owner approves. Each one is additive.

1. **`systemIdentifier` filter on `GET /api/v1/items`.** Take comma-separated dotted ids, matching the field name. Clients filter locally until it ships.
2. **TXT `app=ecs` and `sys=*`** on `_pvcontent._tcp`, so app peers can show a content server alongside the others and hide one that has nothing they play (the same keys as v1.1).
3. **Optional peer-key auth with the `pvlibrary-*` prefixes.** `POST /api/v1/auth/peer/start {peerId,name,publicKey}` → nonce, and `complete {signature}` → a read device token, after the owner approves once. A LAN server could then admit a paired Provenance with no password.
4. **Let a reader mint a read-scoped device token for itself.** Today `requireUser(request,'admin')` blocks it, so readers fall back to the shorter-lived session token.

### Phase 5 device checklist

- [ ] `pnpm ecs serve` with the repo's fixture library. Add the server by URL in Content Servers, sign in, browse, and see only systems this device plays.
- [ ] Copy a ROM. It imports under the right system and boots. Kill Wi-Fi at 50 %: Retry resumes with Range, and the server log shows a 206.
- [ ] Sign in as a guest or reader without `admin`. Browsing works on the session token, and a guest grant can't fetch BIOS (the server refuses, and the client never asks anyway).
- [ ] Relaunch: the server opens with no password prompt (Keychain token). Revoke the device token on the server: the next browse fails with the sign-in message, and re-adding the server with the password fixes it.
- [ ] Delete the server row: its Keychain token is gone (check with a re-add that asks to sign in).
- [ ] tvOS: add a server with the remote keyboard, browse and copy.
