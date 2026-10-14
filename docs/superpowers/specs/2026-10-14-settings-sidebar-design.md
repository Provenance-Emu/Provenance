# Settings sidebar (iOS) — design note

Date: 2026-10-14. Scope: the iOS/iPadOS Settings root (`PVSettingsView`). tvOS is unchanged.

## Why

The iOS Settings root was five bottom tabs (General, Emulation, Controller, Advanced, About), each a long
scroll of collapsible sections with 32pt gradient titles and pink neon shadows on section headers. Controller
alone held six sections, and the retrowave decoration made headers hard to read. iFly's settings screen is
easier to scan, so this copies its structure and type scale while keeping Provenance's retrowave colours.

## What was copied from iFly

Source: `iFly/Sources/UI/Views/SettingsView.swift`, `SettingsView+Layout.swift`, `SettingsTabItems.swift`,
`SettingsView+Helpers.swift`, `Tests/SettingsTabLayoutTests.swift`.

- **Two arrangements.** A wide container gets a leading sidebar of panes, a divider, and the selected pane's
  content. A narrow one gets a horizontally scrolling capsule strip of the same panes above the content.
- **Sidebar rows:** 17pt SF Symbol, `.callout` monospaced label that scales down rather than clipping, 12/8
  padding, 8pt corner radius. The selected row gets the accent at 20% fill and accent text.
- **Tab-strip chips:** caption icon and caption-medium label, 14/8 padding, `.ultraThinMaterial` when unselected,
  over a material strip.
- **Content column:** search field pinned above a scroll view, 24pt spacing between sections, standard padding.
  In the sidebar arrangement the column is capped at 700pt and centred. A GeometryReader gives the column a
  concrete width, so the first layout pass can't cache an over-wide width (an iFly bug).
- **Section headers:** `.title2.bold()`, one solid accent colour, no shadow, always expanded. The header doubles
  as the search scroll anchor.
- **Readability:** a near-opaque palette background behind the content column, so body text no longer sits on
  the retro grid. Row titles use `.headline`, iFly's row-title size.
- **Unknown size class means narrow.** A transient `nil` size class on first render falls back to the strip.
- **Section bodies are type-erased** (`AnyView` per section). iFly's settings crashed in the runtime type
  demangler when a tab body's generic type got too deep.
- **Locked-layout tests**, after `SettingsTabLayoutTests`: pane order, names and icons; every section in
  exactly one pane; every search entry resolving to a pane; legacy tab mapping; arrangement per width class
  and width.

## What differs from iFly

- **Arrangement rule** (`SettingsLayoutRules.arrangement`). iFly switches on size class alone, because it
  swaps whole scenes and always sees `.regular` on iPad. Provenance presents Settings as a sheet, and that sheet
  can be narrow. The rule therefore also uses the container width (safe area excluded):
  - tvOS: unchanged layout (`.tvOSSections`).
  - Regular class: sidebar when the container is at least 600pt wide, otherwise the tab strip (iPad form sheet).
  - Compact class: tab strip, unless the container is at least 700pt wide. That gives every notched iPhone the
    sidebar in landscape (about 724–750pt after insets) but not an iPhone SE (667pt).
  - Unknown class: tab strip.
- **Nine panes, not iFly's eleven.** They are built from Provenance's existing sections, regrouped (`SettingsPane`):
  General (App), Library (Library, Library Management), Emulation (Core Options, Saves),
  Audio & Video (Audio, Video, Recording & Streaming), Controllers (Controller, Haptics & Rumble, DualSense,
  Analog Deadzone), Touch Controls (On-Screen Controls, Delta Skins), RetroAchievements, Advanced,
  About (Social Links, Documentation, Roadmap, Build, Extra Info).
- **Retrowave colours stay.** The accent is `retroPink`, used for the selected sidebar row and section headers.
  Each section's rows sit on a card in the palette's `settingsCellBackground` at 35%, with a pink-to-blue
  hairline stroke. A gradient rule sits under the header row. The selected chip is `retroPurple` with a
  `retroPink` stroke, because white 12pt text on `retroPink` falls short of 4.5:1 contrast.
- **Sidebar width is 220pt** (iFly: 200pt), so "RetroAchievements" fits in monospaced type without scaling.
- **Done / Help** sit in a plain header row ("SETTINGS" title between them) instead of iFly's navigation toolbar.
  The old hand-drawn buttons were overlaid on the content; the new row is laid out above it. Both stay hidden
  when `showsDoneButton` is false, as before.
- **No controller / keyboard focus layer.** iFly's `SettingsView+Controller.swift` and `+Input.swift` drive the
  sidebar from a gamepad. Provenance's iOS settings had no such layer before, and this change does not add one.
- **No collapsible groups.** Panes are short enough without them. `Defaults[.collapsedSections]` is no longer
  read on iOS, which affects UI state only. tvOS keeps its own `TVOSSettingsSectionState`.

## Unchanged

- **Settings keys and semantics:** every section view (`AppSection`, `LibrarySection2`, …) is re-hosted as is.
  `AdvancedTogglesView`, `ControllerSettingsView` and `PVSettingsModel` are untouched.
- **`SettingsTab` and `SettingsDestination.tab(_:)`** (deep links, e.g. `showSettings(tab: .advanced)`).
  `SettingsPane(tab:)` maps each tab to the pane that holds its first section.
- **`SettingsSearchIndex`:** a result now opens `SettingsPane(section:)` and scrolls to the section header
  (`.id(sectionTitle)`). That also works when the result is in the pane already on screen, because closing the
  results list re-creates the scroll view and its `.task(id: pendingScrollSection)` fires. Breadcrumbs read
  "Pane › Section".
- **tvOS:** the `TVOSSettingsSection` column, its search page, and `SettingsRow`'s tvOS branch.

## Files

- `PVUI/Sources/PVSwiftUI/Settings/SettingsLayout.swift`: the pure model (`SettingsPane`, `SettingsLayoutRules`,
  `SettingsArrangement`, `SettingsWidthClass`).
- `PVUI/Sources/PVSwiftUI/Settings/SettingsSidebarContainer.swift`: the sidebar / tab-strip container and
  `SettingsPaneSection`.
- `PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift`: the iOS body now hosts the container. The five
  `*TabContent` builders were replaced by a `sectionContent(_:)` switch. `SettingsRow`'s iOS title is
  `.headline`. Two neon shadows were removed from Delta Skins body text.
- `PVUI/Tests/PVSwiftUITests/SettingsLayoutTests.swift`.

## Left for follow-up

- `CollapsibleSection` / `CollapsibleSectionExpansion` (PVUIBase) and the `settings.tab.*` strings no longer have
  an iOS settings caller. Delete them once this lands.
- Settings subpages (`Views/*.swift`) still carry about 16 pink text shadows, including `AdvancedTogglesView`
  line 60, which another change owns. Restyle them separately.

## Screenshots to take (device or simulator)

Take each in a dark and a light palette:

1. iPad, full screen, landscape and portrait: sidebar with General selected, then Controllers.
2. iPad, Settings as a sheet: check which arrangement the sheet's width gives.
3. iPad Split View at ½ and ⅓: tab strip.
4. iPhone 17 Pro, portrait (tab strip) and landscape (sidebar; check that the sidebar scrolls to About).
5. iPhone 17 Pro Max landscape (regular width): sidebar.
6. iPhone SE landscape: tab strip.
7. Search "rumble" and choose "Rumble Profiles": the Controllers pane opens and scrolls to Haptics & Rumble.
   Repeat with a result in the pane already open.
8. A `showSettings(tab: .advanced)` deep link (the Advanced shortcut) opens the Advanced pane.
9. Settings opened over a running game (pause menu → Settings): the content background is opaque, and toggles
   and sliders render correctly.
10. Rotate an iPhone between portrait and landscape with a pane selected: the selection survives the switch
    between strip and sidebar.
11. Dynamic Type at XXL: sidebar labels scale down, and section headers wrap rather than clip.
12. tvOS: Settings looks exactly as before.
