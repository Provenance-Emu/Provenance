# Content server libraries

In **Settings → Advanced → Feature Flags**, enable **nearbyLibraries** and **contentServerLibraries**. Both are off by default.

Open **Nearby Libraries** from the library menu or Settings → Library. Under **Content Servers**, add the server's address and a read access token. Username/password sign-in is also available. Addresses without a scheme use HTTP on port 8473; use an explicit HTTPS URL for a TLS endpoint. Tokens live in Keychain and passwords are never written to settings.

Select a server, choose a library (or All libraries), and search its games. Only systems with an installed, enabled core are offered. **Download & Play** stages the game's files, checks them, imports through the normal Provenance importer with the selected system, and launches the registered game through SceneCoordinator. A later visit offers **Play** for a previously imported game. Missing BIOS, core selection, patches and other launch requirements use the normal app flow.

Managed items use the generated Swift client's manifest models and server SHA-256 digests. Indexed roots have no remote digest: the adapter streams a private temporary copy, hashes it locally, then hands that copy to the same verified transfer/import path. This local digest verifies the handoff, not the authenticity of the server's original bytes. Disc groups retain relative paths and descriptor references must remain inside the downloaded set. BIOS files, saves and states are not silently imported.

Downloads support cancellation and retries. Navigating away from a content server cancels its active transfer/import wait; an already claimed import finishes safely, and does not auto-launch after cancellation. Tokens are scoped to the server origin and requests do not follow redirects.

The `External/EmulatorContentClient` package is an unmodified snapshot of the server's generated Swift package. `UPSTREAM.md` records its source revision; `Scripts/update_content_client.py` refreshes it after generation. This avoids absolute paths to a developer's server checkout and does not require Xcode project edits.
