# Content server libraries

Open **Nearby Libraries** from the library menu or Settings → Library. Under **Content Servers**, add the server's address and a read access token. Username/password sign-in is also available. Addresses without a scheme use HTTP on port 8473; use an explicit HTTPS URL for a TLS endpoint. Tokens live in Keychain and passwords are never written to settings.

Select a server, choose a library (or All libraries), and search its games. Only systems with an installed, enabled core are offered. **Download & Play** stages the game's files, checks them, imports through the normal Provenance importer with the selected system, and launches the registered game through SceneCoordinator. A later visit offers **Play** for a previously imported game. Missing BIOS, core selection, patches and other launch requirements use the normal app flow.

Managed items use the generated Swift client's manifest models and server SHA-256 digests. Indexed roots have no remote digest: the adapter streams a private temporary copy, hashes it locally, then hands that copy to the same verified transfer/import path. This local digest verifies the handoff, not the authenticity of the server's original bytes. Disc groups retain relative paths and descriptor references must remain inside the downloaded set. BIOS files, saves and states are not silently imported.

Downloads support cancellation and retries. Navigating away from a content server cancels its active transfer/import wait; an already claimed import finishes safely, and does not auto-launch after cancellation. Tokens are scoped to the server origin and requests do not follow redirects.

Provenance uses the `EmulatorContentClient` and `RomMClient` products from the [Emulation Server Swift package](https://github.com/Provenance-Emu/emulator-content-server). Update the revision in both `PVLibrarySharing/Package.swift` and `PVUI/Package.swift` together, then resolve dependencies in the Xcode workspace.


## Missing files

When a game's file is gone (tvOS purges the library's cache, and iCloud holds no copy of large games), starting the game looks for it on paired nearby apps and saved content servers. It asks before copying; **Always Allow** makes later exact matches silent (Settings → Library → Restore Missing Games Without Asking). A same-name file that may be a different version always asks, and takes the old file's place without changing the game's entry, saves or statistics. A server is asked only while its saved token works; a nearby iFly or Provenance device only after its library was opened once from Nearby Libraries.
