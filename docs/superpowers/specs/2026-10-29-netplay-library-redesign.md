# Library-first Network Play

The approved design uses an opaque themed hub: games and nearby rooms side by side on tvOS, Games/Rooms tabs on iPhone. Existing artwork cells, focus buttons and full-screen TV presentations are shared throughout the flow. A game's context menu opens its multiplayer details directly.

## Eligibility and ordering

`PVNetplay` owns the typed modes, metadata provenance, eligibility and deterministic ranking. The UI adapter requires a local file and an installed, enabled core for the game's system. Shared-console play, alternating turns, link cable, local wireless and native network play are separate modes. Player counts are bounded by both game and core. Spectator and timing controls follow the selected integration.

Known single-player games and unsupported combinations are excluded. Missing facts remain in a separate opt-in Unverified list, never in Suggested, All supported, Recent or Favorites. A one-player-per-device label does not disprove linked multiplayer.

Suggested prioritizes compatible open rooms, favorites, then last played. All supported and Favorites use title A–Z. Recent requires play history and sorts newest first. Title, system and ROM identity break ties. Unplayed eligible games are included. Search matches title and system; pagination happens after filtering and ranking.

## Metadata

The bundled catalog contains 4,954 GameCube/Wii records from [GameTDB](https://www.gametdb.com/Wii/Downloads), matched by system and full disc serial. Local and native-network player counts are kept separate. Custom titles and GBA/DS peripheral records are omitted. One-local-player records without another known mode remain unverified. No multiplayer facts are inferred from titles or genres.

`Scripts/netplay/build_multiplayer_catalog.py` updates the catalog from an official archive, checks both consoles are present, and records the source XML digest. The resource source file provides retrieval details. Catalog metadata describes multiplayer modes; it does not certify every ROM against every emulator version.

Other systems and unmatched games can receive exact-ROM confirmations through Review Multiplayer Details. The source/notes field is required. Confirmations are stored locally, keyed by system and ROM MD5. They do not transfer to another dump or patched game. Patched variants never inherit serial-based catalog facts. Reset removes the local override. Existing Realm libraries need no schema migration.

## Core and launch checks

The compatibility map describes implemented integrations, not historical RetroArch rollback support. Native mGBA is capped at two link peers; PPSSPP exposes local wireless; Dolphin and selected Mednafen systems expose shared controllers. gpSP/melonDS DS must register env 78 in the running build before being recommended; observations are scoped to platform, app build and core version. Other thin cores do not inherit support from their console or dylib presence.

Room joins require the same ROM, compatible installed core and player limits. New advertisements include mode and core version; legacy advertisements must resolve to exactly one compatible mode. Passwords travel through the launch intent. The selected core is passed explicitly, rechecked at boot, and the runtime bridge must report netplay support. Game selection enters room setup directly.

## Validation

`xcrun swift test --package-path PVNetplay` covers eligibility, unverified exclusion, ordering, metadata persistence/catalog identity, discovery metadata and existing transport tests. `python3 Scripts/tests/test_multiplayer_catalog.py` covers conservative source ingestion. Focused iOS/tvOS simulator hosts exercise the actual settings and room-setup sources, including remote toggling and capability-limited controls. These checks do not establish two-device gameplay compatibility.
