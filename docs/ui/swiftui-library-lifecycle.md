# SwiftUI library lifecycle

The library shell replaces the UIKit container stack discussed in PR #3608.

## Ownership

- `ProvenanceApp` owns the SwiftUI scenes. Its aggregate `scenePhase` drives pause,
  background autosave, foreground state and entitlement refresh. The app observes
  `ThemeManager` so the scene color scheme and status bar follow theme changes.
- `PVApplicationServices` starts once per process. Realm configuration, bootstrap
  tasks, CloudKit, MetricKit, JIT acquisition and library notifications live here.
  It does not create windows or library controllers.
- `PVSystemEvents` forwards APNs, background-fetch, SiriKit and termination
  callbacks (the last flushes the running core). Its scene
  configuration installs the shortcut-only `PVSceneDelegate`. These adapters retain
  no library hierarchy. SwiftUI has no equivalent API for APNs registration or Home
  Screen Quick Action delivery.
- `PVLibraryRootView` owns paged-library navigation and SwiftUI presentations.
  `PVLibraryNavigation` implements the existing game/menu delegate contracts for
  library views without inheriting from `UIViewController`.
- `PVLibraryDrawerHost` observes menu visibility separately from the library's data.
  `PVLibraryDrawer` animates the panel offset and scrim; the library remains mounted.

The emulator's Metal/OpenGL view controllers and platform-specific facilities are
outside the library-shell migration.

## Appearance and interaction

The library header retains the theme accent, tracked title, glowing rounded border
and depth shadow. The drawer uses the palette's opaque menu surface, an accent edge
and a separate background shadow. Effects have no repeating timers. Reduce Motion
removes the spring and panel travel; Reduce Transparency increases scrim opacity.

Panel width follows the current window rather than `UIScreen` or device orientation
notifications. It caps at 380 points and preserves at least 44 points outside the
panel for dismissal where the window is large enough. Leading-edge gestures follow
layout direction; vertical scrolling does not close the menu.

Search is a SwiftUI field. Settings, imports, free ROMs, save-state management and
core selection use SwiftUI presentations. Core selection preserves per-game and
per-system defaults. A system file importer passes security-scoped URLs to the
existing copy/import service.

Removed: the side-navigation controllers, root/navigation controllers, hosting
representable, search-controller adapter, alternate `UIApplication` subclass and
nested Home page-view workaround.

## Validation

The focused `Provenance-Dev-UI` iOS Simulator app built successfully twice through
Xcode. Later iterations reused that target's compiler and linker invocations to
recompile the current `PVLibrary`, `PVLibrarySharing`, `PVSwiftUI` and app sources,
aggregate the package objects, relink the app and ad-hoc sign it. Signature
verification passed. The app runs on the dedicated iPhone 17 Pro with iOS 26.5.
This is focused-app validation, not a full shipping-workspace or tvOS build.

Runtime checks found and addressed:

- The pager's redundant bottom safe-area overrides clipped the toolbar's upper
  border. The running app now shows the complete rounded border below the header.
- At the largest accessibility text size, toolbar symbols crowded the title.
  Symbols now keep a toolbar size while the title scales and buttons retain
  44-point targets. The full Home title is visible at the largest size.
- Theme changes updated custom surfaces while leaving the scene's color scheme
  stale. Observing the theme at the app boundary fixes the scene background,
  status-bar contrast, native sheet title and search-prompt contrast.
- Disabled console search still installed an empty, constant-bound search field.
  It now omits the search modifier, and the running console page has no blank bar.
- A horizontal drawer-close drag could activate the pressed console row. Menu
  controls are disabled during horizontal drag translation; vertical movement
  does not set that translation. Repeating the same swipe now closes the drawer
  while preserving Atari 2600 as the selection. Vertical menu scrolling also ran.

Other runtime checks covered leading-edge opening, horizontal close without row
activation, vertical menu scrolling, backdrop dismissal, themed glow/shadow surfaces, search
text, no-results presentation, Clear Search, keyboard dismissal, settings, console
selection and the SwiftUI core-options sheet. An earlier native accessibility
inspection confirmed that opening the drawer hides the library behind it.
RocketSim's simulator hierarchy can still expose stale hidden elements, so visual
captures were used to verify the actual presentation.

A synthetic Atari 2600 ROM imported and started in Stella, completed the 120-frame
harness wait and returned to the library through Quit. Normal library-card launch,
Quick Save, return to the library and launching from its save-state card also ran.
The harness explicitly labels frame counts as estimated; its FPS field is not a
rendering-performance measurement.

All 19 helper XCTest cases passed in an isolated macOS harness using production
helper code and the repository test methods:

- Drawer geometry (4), including narrow and landscape windows.
- Tab selection (3), including removed consoles and empty libraries.
- Scene transitions (3), including foreground/background autosave ownership.
- Presentation input ownership (3), including overlapping sheet owners.
- Media-layout eligibility (3), including phone landscape and short windows.
- Drawer observation (3), verifying that menu changes do not publish a
  library-wide model change and unchanged model assignments remain silent.

The geometry helper was also exercised across 1,005 window sizes. Earlier isolated
checks typechecked drawer components against iOS 17 and tvOS 17, and header/HUD
components against iOS 17, with model/resource fixtures. These checks do not
replace the package's complete test suite or a current tvOS integration build.

### Recorded motion comparison

A refreshed comparison recorded four drawer transitions for each app on the same
iPhone 17 Pro simulator, with matching synthetic-library and save files. Both
captures encoded approximately 60 frames per second. During the middle 80% of
travel, SwiftUI showed five to seven distinct positions and a maximum repeated
position of 16.7–33.3 ms. UIKit showed three to four positions and 33.3–50 ms.
SwiftUI's travel segment was 83.3–116.6 ms; UIKit's was 83.3–116.6 ms. The open
panel widths were 312 and 270 points, respectively, and the animation curves differ.

These measure captured panel motion, not display frame times, CPU or energy.
The host was compiling tvOS during the recordings. Simulator Animation Hitches
recording previously reported that hitches are unsupported. The small-fixture
captures support retaining the current transform/opacity animation; they do not
establish large-library scrolling or hardware performance parity.

### Compact phone layout

The phone header now occupies 48 points including its lower inset, down from 68.
A Library Options menu beside the first section heading replaces the separate
62-point toolbar. Its six main rows retain sort, grid/list, cover sizing, grouped
display preferences and More actions. It remains reachable when saves are hidden
or absent. Empty save, Favorites and Recently Played sections are hidden; Most
Played uses the compact shelf height on phones. The full grid has an All Games
heading to distinguish it from the history shelves.

The phone save preview is 156 points in portrait and 112 in landscape, compared
with 260 and 130 previously. The header, removed toolbar and portrait save card
reclaim approximately 186 points before the game shelves, plus the space saved
by omitting empty sections. Non-phone header spacing and save heights retain
their existing dimensions.

Final UI compilation passed for iOS and tvOS. The iOS app was aggregated,
relinked, signed, verified, installed and launched. Native portrait/landscape,
list/grid switching, grouped display preferences and hiding/restoring save
previews were exercised. SwiftLint reported no errors, with existing warnings.
This pass changes presentation and adds no persistence or navigation service.

### Remaining checks

Native phone rotation was exercised on the rebuilt app in portrait and both
landscape orientations, with the drawer open and closed. The library keeps its
phone layout and the toolbar remains visible. This revealed a closed-drawer strip
in the landscape safe area: the hiding distance now includes the side inset.
Repeated rotation confirms that the strip is gone on both sides. Returning Home
also keeps Settings and Add Games visible at the top of the drawer. Native
accessibility exposes the drawer while hiding the background library.

The follow-up UI compilation completed all 201 compiler jobs without errors;
package aggregation, app relinking, ad-hoc signing and signature verification
passed. Linked symbols contain the SwiftUI drawer and exclude the legacy root
controller. Five current drawer-geometry XCTest cases passed, including a new
landscape safe-area regression case. The cached compiler invocation required a
fresh, preloaded OpenGLES import cache and removal of its stale SDK stat-cache
argument; no graphics source or SDK headers were changed.

The UIKit baseline uses the same Realm library but a separate app Documents
container. Its initially different save preview was fallback artwork because the
synthetic ROM's screenshot file was missing there. The current app correctly
loads the actual black test-ROM capture. Visual comparisons must mirror these
local test files as well as the shared database.

The focused tvOS app built successfully, passed strict signature verification and
ran on the dedicated Apple TV 4K simulator with tvOS 26.5. Linked symbols include
the SwiftUI root/drawer and exclude the legacy root controller. Remote input
verified Home → Systems, Settings activation, Menu returning to navigation, and
Import Status presentation/dismissal back to Systems. The empty Systems page now
has themed focusable actions: the UIKit baseline had no content focus target and
Menu exited to the TV Home screen. The new page opens its sidebar and remains in
the app. Pink/cyan focus glows were inspected in Systems and Settings.

The TV build selected its SDK from the destination, allowing macros to build for
the Mac host. Its invocation also used
`OTHER_CPLUSPLUSFLAGS='$(inherited) -Wno-error=module-import-in-extern-c'` for a
bundled Vulkan header diagnostic. No core source or SDK headers were modified.
The current lookup package embeds database archives at the app root and launches
without the obsolete resource bundles required by the stale cached TV app.
An attempted Time Profiler attachment stalled and was terminated; it does not
supply CPU evidence. All tracked competing builds paused for this validation
were resumed afterward.

Still to validate: iPad window resizing, full VoiceOver and Reduce
Motion/Transparency interactions, physical
controller navigation through all presentations, native file imports, deep links,
shortcuts, Siri/Spotlight, background autosave and CloudKit push delivery.
