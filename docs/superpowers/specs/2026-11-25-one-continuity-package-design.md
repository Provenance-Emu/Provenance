# One continuity protocol and package for Provenance, iFly and iCube

Date: 2026-11-25. Status: proposal, second draft. No code has changed.

## Direction from the owner

The first draft of this document kept each app's current wire alive for installed builds. The owner then decided otherwise (2026-11-25):

> "i think with continutity, again since we haven't shipped yet, we should make a common best version protocol and use it for all the apps and then they could even talk to each other"
>
> "none of the apps have shipped live with these so now is the time"

So this draft designs:

- **one new protocol** for all three apps, taking the strongest parts of the three existing implementations;
- **cross-app sharing as a requirement**: Provenance, iFly and iCube devices find each other and share;
- **no compatibility** with any current build. There is no transition period and no build that speaks two protocols.

One consequence to accept knowingly: TestFlight builds already in testers' hands stop seeing newer builds for nearby sharing and handoff until they update. Sharing between two old builds keeps working.

## Recommendation in short

| Question | Answer |
|---|---|
| Which repository | **ContinuityKit**, as version 2.0. PVContinuity is retired. The protocol half of Provenance's `PVLibrarySharing` moves into ContinuityKit. |
| Bonjour service type | **`_pvcontinuity._tcp`**, one type for all apps. The three current types are dropped. |
| Protocol | **Continuity v2**, defined in section 3. Not any current wire as-is. |
| Cross-app | A peer is shown when it shares a system the browsing app can play. Games cross apps freely; saves cross only when both apps can read them and the owner has allowed it. |
| Through PVRemoteLibrary | ContinuityKit ships one `RemoteLibrarySource` for nearby peers. The work in progress in iFly and iCube is kept: a peer becomes one more source in the browser they are adopting. |

## 1. What exists today

Sources read: ContinuityKit `1d6c48b`, PVContinuity `bc65f46`, PVRemoteLibrary `89b0f05`, `PVLibrarySharing` on `develop`, iFly `904bb5623`, iCube `aa9ff9ac13`. Nothing was built or run for this document.

PVContinuity was written from ContinuityKit's design for GameCube and Wii: the file layout, routes, pairing maths, puller and fallback ladder match. Provenance uses neither. It wrote its own codecs for both wires and added a neutral third one (`_pvlibrary._tcp`, from `2026-10-14-cross-app-library-sharing-design.md`).

| | ContinuityKit (iFly) | PVContinuity (iCube) | PVLibrarySharing (Provenance) |
|---|---|---|---|
| Service type | `_ifly-continuity._tcp` | `_icube-continuity._tcp` (16 characters, one over the RFC 6335 limit) | Both of those plus `_pvlibrary._tcp` |
| TXT record | `v`, `sid`, `lib`, `pid`, `u0..u3`, game keys on handoff, `cap`, `dt`, `ic` | Same family without `cap` and `ic` | Adds `app`, `lx`, `sys`, `cv` |
| Identity | Ed25519 key per install | Same | Same, key in the Keychain |
| Unknown peer wants to browse | Owner prompt: Share Everything / Ask Per Game / Don't Share; trusted on first use | Refused until a 6-digit code pairing | Follows the peer's rule on each wire; either on its own |
| Same iCloud account | `ic` hash in the TXT record skips the prompt. The package notes the hash can be replayed by anyone on the LAN. | None | None (blocked: no shared CloudKit container) |
| Per-peer grant | everything / ask per game / denied | Same | Same |
| Library token | No lifetime; revoked on sharing off or trust edit | 1 hour, at most 16, trust re-checked per request | 1 hour, peer-scoped |
| Catalogue | One route, whole list, includes the owner's last played, play count, favourite and save count; `ETag` | Separate route, version-checked, title, size and identity only | iCube's shape plus `ETag`, system filter, paging |
| One game's files | `POST library/pull`, `file?path=` | `manifest?key=`, `file?key=&path=`, exclusion re-checked per file | Same as iCube |
| What a copy carries | Game, BIOS, save states, VMUs | Game only (asserted by a test); saves go over a separate app route to paired devices | Game only |
| Game identity | flycast id, MD5, serial | Game id + disc + revision, MD5, CRC32, with a match ladder | System + MD5 + size, then the peer's own id |
| Paths in a manifest | Relative to iFly's documents folder | Relative to Dolphin's User folder | Relative to the game; the receiver never mirrors a peer's layout |
| Continue this game | Yes: mint a state, pull, fallback ladder; code-less "Allow once / Always" request | Yes, pairing only | No |
| Presence beacon | Yes | No | No |
| Metering | 429 seam (iFly Pro's daily limit) | None | None |
| Offline package | `.iflypkg` reader and writer | Constants only | None |
| Resume and integrity | `.part`, `Range`, SHA-256 per file, manifest is the allow-list | Same | Same, plus bounded restarts and a cached manifest |
| Listener | The app's web server, through its own registrar protocol | The app's web server, through `PVWebServer` types | Its own `NWListener` with a LAN filter (loopback, link-local or on-link only; cellular and VPN refused) |
| Transport | Plain HTTP | Plain HTTP | Plain HTTP |
| Dependencies | ZIPFoundation, internal | PVSyncRules, PVWebServer, both public | PVSystems, content-server client |
| Licence | Provenance licence (BSD style) | GPL-2.0-or-later | Provenance licence |

What the user sees today: iFly shows a Nearby section inside its normal library with a host pill, copy options, sync subscriptions and approval prompts. iCube shows a nearby peer library, sharing settings and a handoff sheet. Provenance shows Nearby Libraries with an app badge, Share This Library and trusted devices.

### Strongest parts, and where each comes from

| Taken | From | Why |
|---|---|---|
| Separate, version-checked catalogue; per-file exclusion check; token lifetime, cap and live trust check; "a stranger gets the game and nothing of the owner's" as a tested rule; identity match ladder | PVContinuity | The safer server |
| Consent prompt with trust on first use; code-less continue; presence beacon; metering seam; package archives; opt-in extras; fallback ladder | ContinuityKit | The fuller feature set, and nobody walks across a room to read a code before browsing |
| System list and filter; paging; `ETag`; own listener with LAN filter; receiver-owned file placement; staging and containment; wire pinned by fixtures; one row per peer | PVLibrarySharing | What makes cross-app sharing work at all |

## 2. Package and service type

### 2.1 ContinuityKit 2.0 is the package

- **No app-specific dependency.** PVContinuity's public interface imports `PVSyncRules`, whose categories are iCube's, and `PVWebServer`'s route types. ContinuityKit depends on nothing an app would not want.
- **Licence.** PVContinuity is GPL-2.0-or-later; ContinuityKit and Provenance's code are not. Version 2 is mostly new code plus code moved from `PVLibrarySharing`, so ContinuityKit keeps its licence. Where PVContinuity's own files would be useful, the owner as author can relicense them (decision 2). Until that is decided, nothing is copied from PVContinuity into ContinuityKit: not source, tests or fixtures. Tests are written new or moved from `PVLibrarySharing`, and fixtures are the v2 ones from step 1.
- **Platforms.** ContinuityKit already declares watchOS and visionOS; it moves to iOS 17 and tvOS 17 to match PVSystems and PVRemoteLibrary.
- **The name fits all three apps.**

PVContinuity is archived with a pointer in its README once iCube has moved. Its tags stay so old iCube commits build.

`PVLibrarySharing` keeps what is Provenance's own: the content-server and RomM sources, missing-game recovery, local matching and the Realm glue.

### 2.2 `_pvcontinuity._tcp`

- One type, so each app lists one entry in `NSBonjourServices` and browses once.
- A new name on purpose. `_pvlibrary._tcp` is already spoken by Provenance TestFlight builds with a different protocol; reusing it would make old and new builds find each other and then fail. A new type makes them invisible to each other, which is the clean break the owner asked for.
- 13 characters, inside the 15-character limit that `_icube-continuity` breaks.
- It carries both library sharing and handoff sessions; the TXT record says which.

## 3. Continuity v2

### 3.1 Principles

1. **Systems are the common language.** Every game, save and advert names its system with the PVSystems identifier, which all three apps already depend on. No per-app platform strings.
2. **The receiver owns its file layout.** A manifest path is relative to the game, never to the sender's folders. Each app places files by kind. This is what lets a Dreamcast disc from iFly land correctly in Provenance.
3. **A stranger gets the game and nothing of the owner's.** Saves, BIOS and play history travel only under the rules in 3.6.
4. **One listener, in the package.** The package runs its own listener with the LAN filter on one port. Apps do not adapt their web servers, and all three behave the same.
5. **The wire is separate from the model** and pinned by fixtures in the package.
6. **Additions are optional keys.** Unknown TXT keys, JSON fields and query items are ignored; `hello` (below) lists features, so the next change does not need another break.

### 3.2 Discovery

One advert per running app. TXT record:

| Key | Meaning |
|---|---|
| `v` | `2` |
| `app` | `provenance`, `ifly`, `icube` |
| `pid` | Peer id (see 3.4) |
| `dt` | Device type: `ip`, `pd`, `tv`, `mc` |
| `cap` | Flags: `l` shares a library, `c` hosts continue, `s` offers saves. An advert with no flag is a presence beacon: the app is there and serves nothing. |
| `sys`, `sys1`… | Systems with something to share, compact ids, at most 240 bytes per key |
| `cv` | First 8 hex digits of the catalogue version |
| `u0..u3` | Base URLs, `.local` name last |
| `gs`, `gk`, `gt` | Only while a game is running and continue is on: its system, opaque key and title |

Never in the TXT record: a token, or any hash of the user's account.

On Apple platforms with Handoff, the running game is also published as an `NSUserActivity`. The activity type stays per app, because the system delivers an activity only to the app that declares it.

A browser shows one row per `(pid, app)` and hides a peer whose `sys` shares nothing with the systems this app can play.

### 3.3 Routes

All under `/continuity/v2`, JSON bodies, ISO 8601 dates.

| Route | Purpose |
|---|---|
| `GET hello` | No auth. App, app version, protocol minor, systems, feature list, limits (page size, token lifetime). |
| `POST pair/start`, `POST pair/complete` | 6-digit code pairing |
| `POST auth/start`, `POST auth/complete` | Signed nonce. Carries the scopes asked for: `browse`, `copy`, `saves`, `continue`. Answers 202 while the owner is being asked. Returns one peer-scoped token with the scopes granted. |
| `GET catalog?systems=&q=&limit=&cursor=` | Version-checked list, `ETag`, 304. Each entry: opaque `key`, title, system, identity fields, size, disc info, `hasArtwork`. |
| `GET art?key=` | Cover, `ETag` |
| `GET manifest?key=&include=` | One game's files. `include=saves,bios,extras` asks for more than the game; the server lists only what the token and the rules allow. 202 while a per-game prompt is open, 403 refused, 429 metered. |
| `GET file?key=&path=` | `Range`, 206, 416. Serves only paths of that game's manifest; exclusion and trust re-checked on every request. |
| `GET session` | The running game, if continue is on: its catalogue key and identity |
| `POST session/mint` | Makes a fresh save state and returns the session manifest (game, state, saves) |

One token family with scopes replaces today's separate session and library tokens. Tokens are peer-scoped, last one hour, are capped at 16, are stored as digests, and trust is looked up live on every request.

### 3.4 Identity, trust and pairing

**Identity.** Each device has one Ed25519 key, shared by the three apps through the shared Keychain group, so a device is one peer whichever app it runs. A peer on the wire is `(pid, app)`. An app that cannot reach the shared group falls back to its own key.

**Signatures** use the prefixes `pvcontinuity-pair-v2|` and `pvcontinuity-auth-v2|` and bind both peer ids, both app ids and both public keys.

**Three ways to become trusted:**

1. **Same owner.** The owner's devices recognise each other without a prompt. Recommended mechanism: a random secret kept as a synchronisable Keychain item in the shared group, which iCloud Keychain copies to the owner's devices; a peer proves it holds the secret by answering a challenge. Nothing derived from the account is broadcast, which removes the replay weakness of today's `ic` hash, and no shared CloudKit container is needed. To verify before building: that the item syncs to Apple TV and across the three apps' access groups. Fallback: the CloudKit hash with one shared container.
2. **Consent.** An unknown peer asks; the owner sees "Joe's iPad (iFly) wants to browse your library" and picks Share Everything, Ask Per Game or Don't Share. A yes trusts the device on first use.
3. **Code pairing.** The 6-digit code on screen, for networks the owner does not control. An app setting "Require a code for new devices" turns consent off.

**Trust is per device, grants are per device and app.** Trusting "Joe's iPad" once covers all three apps on it. What it may do is stored per `(pid, app)`: nothing, ask per game, or everything; and separately whether saves are included.

**Revocation** drops the peer's tokens at once, so a copy in flight stops at its next request.

### 3.5 Games and what a peer can use

An entry's identity carries every field any app has: system, MD5, CRC32, serial or game id, disc number, revision, title, size. Matching "already in your library" uses one ladder, strongest first: same system and same game id, disc and revision; same MD5; same game id with a different disc or revision (shown as a related version, never as the same game).

Which systems a peer can use:

- The browsing app sends `systems=` with what it can play. The server filters; the client filters again.
- iFly asks for the Dreamcast family, iCube for GameCube and Wii, Provenance for everything it has a core for.
- So an iCube device never lists a Dreamcast disc, and iFly and iCube show each other only if one day they share a system. Today they do not, so they are hidden from each other without any special rule.

File kinds are an open, dotted string, with ordering and "required" supplied per kind:

| Kind | Example | Travels to |
|---|---|---|
| `game` | Disc image and its siblings, primary file first | Any peer allowed to copy |
| `artwork` | Cover | Any peer allowed to browse |
| `extra.*` | Texture packs | On request, any peer allowed to copy |
| `save.battery.<format>` | `dc.vmu`, `gc.card`, `gc.gci`, `wii.nand`, `srm` | Same-owner devices, or a peer granted saves |
| `save.state.<core>.<version>` | flycast or Dolphin state with the core's state version | Same as battery saves, and offered only when the receiver reports the same core and version |
| `bios` | | Same-owner devices only, opt-in |

### 3.6 Saves across apps

Saves matter across apps where two apps run the same system:

| Pair | Battery saves | Save states |
|---|---|---|
| iCube ⇄ Provenance (GameCube, Wii) | Memory cards and Wii saves are the same formats | Both use the Dolphin core; a state loads only when the state version matches, which the kind's version field checks |
| iFly ⇄ Provenance (Dreamcast family) | VMU files are the same format | Native flycast and the libretro build are not assumed compatible; states are not offered unless the versions match |
| iFly ⇄ iCube | Nothing in common | Nothing in common |

Rules:

- A receiver states in `hello` which save formats and state versions it reads. A sender lists only those.
- Saves are never part of a copy by a stranger. They are included for same-owner devices, and for another person only when the owner turned on "Include my saves" for that device.
- GameCube memory-card images and the Wii NAND hold every game's saves, not one game's. The sender exports the one game's save where the format allows (`gc.gci`, a single Wii title folder) and never sends a whole card or NAND to another person.
- An incoming save never overwrites a local one silently. The receiving app keeps the local file and asks, or files the incoming one beside it.
- The owner's last played, play count and favourite are sent to same-owner devices only.

### 3.7 Continue this game

The flow is today's: the receiving device asks the host to mint a state, pulls small files first, and the fallback ladder decides what can start if the transfer dies.

Across apps it now works where the table above allows it. When the state cannot load on the receiver, the ladder falls to "start the game with the transferred battery save", which for GameCube and Dreamcast still resumes from the last in-game save.

A code-less continue is an `auth` request with the `continue` scope and the same prompt as browsing ("Allow once / Always / Don't allow").

Provenance gains continue between its own devices from the same code. Wiring it into Provenance's emulator is separate work after this migration.

### 3.8 Transfer

Unchanged in substance, because all three agree: `.part` files, `Range` resume, restart from zero when a ranged request gets a 200, SHA-256 on every file, the manifest as the allow-list, small files first. From Provenance: at most two restarts per file, a cached manifest so a resume does not spend a metered copy, a staging folder named by a hash with every path checked to stay inside it.

### 3.9 Transport security

Plain HTTP on the local network, as today, with the LAN filter on every connection. This authenticates peers and gives no confidentiality; that is stated in the sharing settings.

`hello` reserves a `tls` feature. Adding it later is not a break. Doing it now needs a certificate tied to the identity key on every device, which is the largest single piece of new work in this design (decision 4).

### 3.10 Other

- **Metering.** A host may answer 429 with a reason. Whether iFly keeps a daily limit now that a Provenance host serves the same Dreamcast games without one is decision 5.
- **Offline package.** One format, `.pvpkg`: a ZIP with the v2 manifest and the files. It replaces `.iflypkg` (and the unbuilt `.icubepkg`) and is importable by any app that plays the system.
- **Content server.** Unchanged and separate (`_pvcontent._tcp`).

## 4. Through PVRemoteLibrary

Two sessions are adopting PVRemoteLibrary in iFly and iCube now. That work is kept as it is: PVRemoteLibrary is the browse model (sources, catalogue cache, cover cache, matching, combined library), and a nearby peer is one kind of source in it (`LibrarySourceInfo.Kind.peer` already exists).

ContinuityKit ships a second product, `ContinuityRemoteLibrary`, that depends on PVRemoteLibrary and holds one type:

| `RemoteLibrarySource` | Continuity v2 |
|---|---|
| `info` | Peer name, `kind: .peer`, a glyph from `dt`; the app badge from `app` |
| `capabilities` | `paging` and `serverSearch` |
| `page(query, after:)` | `GET catalog` with `systems`, `q`, `limit`, `cursor` |
| `artwork(for:etag:)` | `GET art` with `If-None-Match` |
| `fetch(_:into:progress:)` | `auth` if needed, `GET manifest`, then the puller; returns the verified files |
| `LibraryGame` | `sourceGameID` = entry key; `system`, `md5`, `sizeBytes`, `gameID`, disc fields map one to one |

Notes for the two adopting sessions:

- Whatever adapter each app writes over its current peer package is replaced by this one source. Nothing above the source changes: not the browser, the caches, the matcher or any view.
- Waiting states (owner being asked, metered, refused) need to reach the row. If `FetchProgress` cannot carry "waiting for approval on the other device", PVRemoteLibrary needs a small addition; to check during step 3.
- Pairing, trusted devices, sharing settings and approval prompts are not part of PVRemoteLibrary. The package supplies the model for them; each app keeps its own screens.
- Saves and continue are not library browsing and stay outside PVRemoteLibrary.

## 5. Steps

Each step lands alone. An app keeps its current sharing, with itself, until its own step. After a package release, the pin is bumped in every app that uses it.

| # | Repo | Change | Done when |
|---|---|---|---|
| 1 | ContinuityKit | The wire as a document plus JSON and TXT fixtures, on a `v2` branch. Reviewed by the iFly and iCube sessions. | Fixtures agreed |
| 2 | ContinuityKit | 2.0 core for library sharing: model, codecs, identity, trust and grant stores, pairing and consent, listener with LAN filter, advertiser, browser, server, client, puller, staging. Moved from `PVLibrarySharing` where it exists. | `swift test` green, including two instances talking over a real socket, resume, tamper, revocation mid-copy and "no owner data to a stranger" |
| 3 | ContinuityKit | `ContinuityRemoteLibrary` product: the peer source for PVRemoteLibrary. | Source tests against the in-process server; PVRemoteLibrary's browser lists and fetches from it |
| 4 | Provenance | Adopt for Provenance ⇄ Provenance: `_pvcontinuity._tcp` in every Info.plist, `PVLibrarySharing` uses ContinuityKit for peers, and the three old listeners and adverts are removed. | Two Provenance devices browse and copy; old code deleted |
| 5 | iFly | Replace ContinuityKit 1.x use for library sharing with 2.0 and the peer source. Remove `_ifly-continuity._tcp`. | iFly ⇄ iFly and iFly ⇄ Provenance (Dreamcast) browse and copy on devices |
| 6 | iCube, PVContinuity | Same for iCube. Remove `_icube-continuity._tcp`. Archive PVContinuity. | iCube ⇄ iCube and iCube ⇄ Provenance (GameCube, Wii) on devices |
| 7 | ContinuityKit, iFly, iCube | Continue on v2: `session` routes, minting, fallback ladder, `NSUserActivity`. Can be folded into steps 5 and 6 if the owner prefers one cut per app. | Same-app continue works on devices in both apps |
| 8 | ContinuityKit, all apps | Saves: formats in `hello`, single-game export, conflict handling, the "Include my saves" grant; same-owner trust. | A memory card save goes iCube → Provenance and back; a VMU goes iFly → Provenance and back; a stranger's copy carries none |
| 9 | All, wiki | Device matrix (iPhone, iPad, Apple TV; every app pair), wiki page for the protocol, `.pvpkg`. | Checklist recorded here |

Steps 5 and 6 can run in parallel after step 3. Between steps 4 and 6 Provenance no longer serves the old iFly and iCube wires, so cross-app copies pause until each app's step lands; if that gap matters, do step 4 last.

Risks:

- **Step 2 is large.** Most of it exists in `PVLibrarySharing` with tests, which lowers the risk for the library half. The session half (step 7) is a port from ContinuityKit 1.x.
- **iFly and iCube lose features for a while if steps are split:** between step 5 and step 7 iFly has library sharing on v2 and continue still on 1.x, which means two packages or one cut. Folding 7 into 5 and 6 avoids that.
- **Same-owner trust through the Keychain is unproven on tvOS.** It is isolated in step 8 so nothing else waits on it.
- **Shared device identity needs the shared Keychain group in every target**, including extensions that might start a listener. None should.

## 6. Decisions for the owner

1. **Service type name.** Recommended `_pvcontinuity._tcp`. Reusing `_pvlibrary._tcp` saves a plist edit in Provenance but lets old TestFlight builds find new ones and fail.
2. **Licence.** Recommended: ContinuityKit keeps its licence; relicense any PVContinuity file that is ported directly.
3. **Same-owner trust: Keychain secret or CloudKit hash?** Recommended the Keychain secret, verified on Apple TV first.
4. **TLS now or later?** Recommended later, with the feature flag reserved. Now means every device generates and pins a certificate before the first release.
5. **Does iFly keep its free daily copy limit?** A Provenance host serves the same games with no limit, and an iFly host would meter a Provenance guest. Options: keep it for iFly hosts only, drop it, or make it a rule all three apps share.
6. **Consent or code by default?** Recommended consent (a prompt on the host), with "Require a code for new devices" as a setting. iCube today requires a code.
7. **May saves go to another person at all?** Recommended yes, off by default, per device, single-game exports only.
8. **BIOS.** Recommended: same-owner devices only, opt-in, never to another person.
9. **One cut per app or two?** Recommended one: fold step 7 into steps 5 and 6 so no app carries two continuity packages.
10. **Does Provenance get continue between its own devices?** Recommended yes, as follow-up work after step 9.
