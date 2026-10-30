# Premium themes integration handoff

Owner chat: `01a160ea-5e66-7880-90a9-85ba20676cf2`.

Theme implementation and simulator review are complete. Work is in the shared main checkout on `develop`; no separate theme branch or worktree exists. No theme builds are running or reserved.

## Exclusive module changes

The following nine files are exclusively owned by this theme task. Their working diffs were compared with the preserved final theme patch and matched exactly before commit:

- `PVSettings/Sources/PVSettings/Settings/Model/ThemeOption.swift`
- `PVSettings/Tests/PVSettingsTests/PVSettingsTests.swift`
- `PVThemes/Sources/PVThemes/ThemeApplier.swift`
- `PVThemes/Sources/PVThemes/ThemeManager.swift`
- `PVThemes/Sources/PVThemes/Themes/CGA/CGAColors.swift`
- `PVThemes/Sources/PVThemes/Themes/DarkTheme.swift`
- `PVThemes/Sources/PVThemes/Themes/LightTheme.swift`
- `PVThemes/Sources/PVThemes/Themes/RetroWave/RetroWaveThemePalette.swift`
- `PVThemes/Tests/PVThemesTests/PVThemesTests.swift`

These changes curate coherent CGA palettes (including coherent Random selection), repair palette-role protocol dispatch, soften RetroWave, persist RetroWave separately from Dark, and provide synchronized palette snapshots for dynamic legacy colors. The commit is titled `fix(themes): refine premium palettes and persist RetroWave`; use Git history to resolve its SHA.

## Remaining shared UI ownership

These source edits are already present in the shared working tree. **Do not apply the reference patch wholesale and do not commit whole mixed files blindly.** The reference below captures this task's exact hunks before later netplay and UIKit-cleanup edits; its context may now be stale.

- `PVUI/Sources/PVSwiftUI/Home/HomeView.swift`
- `PVUI/Sources/PVSwiftUI/RootView/PVLibraryRootView.swift`
- `PVUI/Sources/PVSwiftUI/Settings/Components/ThemeSelectionView.swift`
- `PVUI/Sources/PVSwiftUI/Settings/SettingsSearchViews.swift`
- `PVUI/Sources/PVSwiftUI/Settings/SettingsSidebarContainer.swift`
- `PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift`
- `PVUI/Sources/PVSwiftUI/tvOS Media UI/TVMediaGameTileView.swift`
- `PVUI/Sources/PVSwiftUI/tvOS Media UI/TVMediaMainView.swift`
- `PVUI/Sources/PVSwiftUI/tvOS Media UI/TVMediaSidebarRail.swift`
- `PVUI/Sources/PVUIBase/SwiftUI/Components/RetroWave/RetroTheme.swift`
- `PVUI/Sources/PVUIBase/SwiftUI/Components/RetroWave/RetroWaveColors.swift`
- `PVUI/Sources/PVUIBase/SwiftUI/GameItem/GameItemViewCell.swift`
- `PVUI/Sources/PVUIBase/SwiftUI/GameItem/GameItemViewRow.swift`

Specific overlap boundaries:

- `PVLibraryRootView.swift`: only the ThemeManager observed-object declaration and root `.tint(...)` are theme-owned. The netplay request state, presentation modifier and notification routing belong to the netplay task.
- `SettingsSwiftUI.swift`, `SettingsSidebarContainer.swift` and `SettingsSearchViews.swift`: theme-owned changes are palette colors, explicit search prompt color, category chip contrast, Plus banner surfaces/detail text, Settings color-scheme environment and tvOS choice-list colors. Preserve later UIKit/settings cleanup and all existing behavior.
- `HomeView.swift`: only two section-title opacity changes to `0.72` (All Games and Recent Saves).
- `GameItemViewCell.swift`: palette-driven artwork glow color and removal of the unconditional title glow. `GameItemViewRow.swift`: removal of the title glow only.
- The three tvOS media files own palette observation/role usage, readable text, sidebar surfaces/shadow, game tile titles, shelf/View All labels, and the reduced light-theme vignette. Preserve unrelated routing, Realm lifecycle, gameplay, and netplay changes.
- `RetroTheme.swift` / `RetroWaveColors.swift`: computed legacy colors backed by the active palette plus palette-driven shared component text/surfaces.
- The former three-line `.retrowave` switch change in `PVSettingsViewModel.swift` has been superseded by the later UIKit cleanup commit `9f92c1ae4f`; that file is no longer dirty and the obsolete hunk is deliberately excluded here.
- No alert source/helper changes belong to this theme task. No netplay, Dolphin, CodeSigning or shipping project-file edits belong to it.

## Validation completed

On 2026-10-29, built `Provenance-Dev-Coreless` from `Provenance-Dev.xcworkspace` using Xcode 27.1 and ran it on iPhone 18 Pro / iOS 27.0 and the dedicated tvOS 27.0 simulator. Both final builds succeeded:

- `build/theme-review/validation/tvos-library-build.log` (20:17:42 EDT).
- `build/theme-review/validation/ios-compatibility-build.log` (20:27:27 EDT).

Visually inspected Green, light Cyan and RetroWave in Settings/picker and populated libraries, using a synthetic Atari 2600 ROM. Corrected unreadable white-on-light labels, prompt/chip/banner contrast, title glows, heavy sidebar shadow and the light vignette. RetroWave persisted after relaunch on both platforms. SwiftLint reported warnings but no errors on the additionally changed views; `git diff --check` passed. Initial implementation passed 18 ThemeOption tests, and native UIKit probes passed text/accent contrast checks for all ten palettes.

Evidence (ignored build artifacts; preserve outside build cleanup if needed):

- `build/theme-review/ios-green-library-after.png`
- `build/theme-review/ios-cyan-library-after.png`
- `build/theme-review/ios-cyan-settings-after.png`
- `build/theme-review/tvos-cyan-library-after.png`
- `build/theme-review/tvos-cyan-settings-after.png`
- `build/theme-review/tvos-retrowave-settings-after.png`
- `build/theme-review/native-palette-checks.txt`
- `build/theme-review/validation/README.md`

## Deferred consolidated checks

- Full shipping/Lite iOS and tvOS builds were not run; the completed app builds were focused Coreless UI builds.
- The full PVThemes XCTest suite was not executed; native UIKit probes exercised its main contrast assumptions.
- Visual review covered Green, Cyan and RetroWave, not every color variant.
- The passing builds predate later alert/cleanup and netplay edits. They do not validate the current `UIViewController+Alerts.swift` localization calls or later deletions.
- After integration, switch Green/Cyan/RetroWave on both platforms and check Settings prompt/category/banner text; library titles, headings and View All; TV focus borders and light sidebar edge. Select RetroWave, relaunch and confirm it stays selected separately from Dark. Optionally exercise Random, which should choose one coherent palette.

No remaining theme implementation blocker is known. Preserve other owners' source and index entries during integration.

## Exact reference hunks for the shared UI

This is an ownership record against the earlier baseline, not an instruction to reapply changes to the current checkout. Trailing whitespace is normalized for Markdown; use it to identify owned lines, not as an applyable patch.

<details>
<summary>Expand the theme-owned shared UI reference patch (13 files)</summary>

```diff
diff --git a/PVUI/Sources/PVSwiftUI/Home/HomeView.swift b/PVUI/Sources/PVSwiftUI/Home/HomeView.swift
index f616f7a070..abda65820a 100644
--- a/PVUI/Sources/PVSwiftUI/Home/HomeView.swift
+++ b/PVUI/Sources/PVSwiftUI/Home/HomeView.swift
@@ -246,7 +246,7 @@ struct HomeView: SwiftUI.View {
                             mostPlayedSection()
                             if usesCompactChrome && !allGames.isEmpty {
                                 Text(String(localized: "All Games").uppercased())
-                                    .foregroundStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(RetroPauseChrome.sectionTitleMutedOpacity))
+                                    .foregroundStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.72))
                                     .retroPauseSectionHeaderTypography()
                                     .frame(maxWidth: .infinity, alignment: .leading)
                                     .padding(.horizontal, 10)
@@ -1112,7 +1112,7 @@ struct HomeView: SwiftUI.View {
                 // Section header with title and "Show All" button
                 HStack {
                     Text(String(localized: "RECENT SAVES"))
-                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(RetroPauseChrome.sectionTitleMutedOpacity))
+                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.72))
                         .retroPauseSectionHeaderTypography()
                     Spacer()
                     if usesCompactChrome {
diff --git a/PVUI/Sources/PVSwiftUI/RootView/PVLibraryRootView.swift b/PVUI/Sources/PVSwiftUI/RootView/PVLibraryRootView.swift
index 8682c29f70..464bf72ef1 100644
--- a/PVUI/Sources/PVSwiftUI/RootView/PVLibraryRootView.swift
+++ b/PVUI/Sources/PVSwiftUI/RootView/PVLibraryRootView.swift
@@ -15,6 +15,7 @@ import FreemiumKit

 /// The paged library's SwiftUI navigation and presentation root.
 public struct PVLibraryRootView: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     @Environment(\.openURL) private var openURL
     @Environment(\.scenePhase) private var scenePhase
     @StateObject private var navigation: PVLibraryNavigation
@@ -27,6 +28,7 @@ public struct PVLibraryRootView: View {

     public var body: some View {
         libraryContent
+            .tint(Color(themeManager.currentPalette.defaultTintColor))
             .sheet(item: $navigation.sheet, onDismiss: navigation.didDismissSheet) { sheet in
                 NavigationStack {
                     sheetContent(sheet)
diff --git a/PVUI/Sources/PVSwiftUI/Settings/Components/ThemeSelectionView.swift b/PVUI/Sources/PVSwiftUI/Settings/Components/ThemeSelectionView.swift
index 6b70c9078c..28a61bbe30 100644
--- a/PVUI/Sources/PVSwiftUI/Settings/Components/ThemeSelectionView.swift
+++ b/PVUI/Sources/PVSwiftUI/Settings/Components/ThemeSelectionView.swift
@@ -75,7 +75,7 @@ private struct ThemeButtonContent: View {
         } else if isSelected {
             return AnyShapeStyle(RetroTheme.retroPink)
         } else {
-            return AnyShapeStyle(accentColor.opacity(0.7))
+            return AnyShapeStyle(accentColor.opacity(0.18))
         }
     }

@@ -87,13 +87,13 @@ private struct ThemeButtonContent: View {

     private var scaleEffect: CGFloat {
         if configuration.isPressed { return 0.98 }
-        if isFocused { return 1.04 }
+        if isFocused { return 1.01 }
         return 1.0
     }

     private var shadowColor: Color {
-        if isFocused { return RetroTheme.retroPink.opacity(0.6) }
-        if isSelected { return RetroTheme.retroPink.opacity(0.5) }
+        if isFocused { return RetroTheme.retroPink.opacity(0.18) }
+        if isSelected { return RetroTheme.retroPink.opacity(0.06) }
         return .clear
     }

@@ -190,7 +190,7 @@ struct CGAThemeRow: View {
                 }
             }
         }
-        .buttonStyle(ThemeButtonStyle(isSelected: isSelected, accentColor: RetroTheme.retroPurple))
+        .buttonStyle(ThemeButtonStyle(isSelected: isSelected, accentColor: Color(cgaTheme.palette.defaultTintColor)))
         #if os(tvOS)
         .tvOSDisableFocusEffect()
         #endif
@@ -216,24 +216,8 @@ struct CGAThemeRow: View {

     // Get appropriate colors for each CGA theme
     private var cgaThemeColors: [Color] {
-        switch cgaTheme {
-        case .blue:
-            return [Color(UIColor.CGA.blue), Color(UIColor.CGA.blueShadow)]
-        case .cyan:
-            return [Color(UIColor.CGA.cyan), Color(UIColor.CGA.cyanShadow)]
-        case .green:
-            return [Color(UIColor.CGA.green), Color(UIColor.CGA.greenShadow)]
-        case .magenta:
-            return [Color(UIColor.CGA.magenta), Color(UIColor.CGA.magentaShadow)]
-        case .red:
-            return [Color(UIColor.CGA.red), Color(UIColor.CGA.redShadow)]
-        case .yellow:
-            return [Color(UIColor.CGA.yellow), Color(UIColor.CGA.yellowShadow)]
-        case .purple:
-            return [Color(UIColor.CGA.purple), Color(UIColor.CGA.purpleShadow)]
-        case .rainbow, .random:
-            return [Color.red, Color.green, Color.blue]
-        }
+        let palette = cgaTheme.palette
+        return [Color(palette.gameLibraryBackground), Color(palette.gameLibraryCellBackground ?? palette.gameLibraryBackground), Color(palette.defaultTintColor)]
     }
 }

@@ -244,20 +228,15 @@ struct RetroWaveThemeRow: View {
     let isSelected: Bool
     let action: () -> Void
     @ObservedObject private var themeManager = ThemeManager.shared
-    #if os(tvOS)
-    @Environment(\.isFocused) private var isFocused: Bool
-    #else
-    private var isFocused: Bool { false }
-    #endif

     var body: some View {
         Button(action: action) {
             HStack {
-                // Retrowave preview with animated gradient
+                // Preview the RetroWave palette independently of the current theme.
                 HStack(spacing: 10) {
-                    // Animated color preview
+                    // Palette preview
                     LinearGradient(
-                        gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroPurple, RetroTheme.retroBlue]),
+                        gradient: Gradient(colors: [Color(ProvenanceThemes.retrowave.palette.defaultTintColor), Color(ProvenanceThemes.retrowave.palette.gameLibraryHeaderText)]),
                         startPoint: .leading,
                         endPoint: .trailing
                     )
@@ -279,26 +258,10 @@ struct RetroWaveThemeRow: View {
                 }
             }
         }
-        .buttonStyle(ThemeButtonStyle(isSelected: isSelected, accentColor: Color.clear))
+        .buttonStyle(ThemeButtonStyle(isSelected: isSelected, accentColor: Color(ProvenanceThemes.retrowave.palette.defaultTintColor)))
         #if os(tvOS)
         .tvOSDisableFocusEffect()
         #endif
-        .background(
-            RoundedRectangle(cornerRadius: 8)
-                .fill(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground).opacity(isFocused ? 0.8 : 0.6))
-                .overlay(
-                    RoundedRectangle(cornerRadius: 8)
-                        .strokeBorder(
-                            RetroTheme.retroGradient,
-                            lineWidth: isFocused ? 3 : 2
-                        )
-                )
-        )
-        .scaleEffect(isFocused ? 1.04 : 1.0)
-        .shadow(color: RetroTheme.retroPurple.opacity(isFocused ? 0.7 : 0.5), radius: isFocused ? 12 : 8)
-        #if os(tvOS)
-        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
-        #endif
         .padding(.horizontal)
     }
 }
@@ -320,36 +283,13 @@ struct ThemeSection<Content: View>: View {
     var body: some View {
         VStack(alignment: .leading, spacing: 12) {
             Text(title)
-                .font(.system(size: 18, weight: .bold, design: .rounded))
+                .font(.system(size: 18, weight: .semibold))
                 .foregroundColor(titleColor)
                 .padding(.horizontal)

             content
         }
-        .padding(.bottom, 20)
-        .modifier(RetroTheme.RetroSectionStyle())
-    }
-}
-
-// MARK: - Title View
-
-/// The animated title for the theme selection view
-struct ThemeSelectionTitleView: View {
-    @Binding var glowOpacity: Double
-    @Binding var isAnimating: Bool
-
-    var body: some View {
-        Text("THEME SELECTION")
-            .font(.system(size: 28, weight: .bold, design: .rounded))
-            .foregroundStyle(RetroTheme.retroHorizontalGradient)
-            .padding(.top, 20)
-            .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 10, x: 0, y: 0)
-            .onAppear {
-                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
-                    glowOpacity = 0.7
-                    isAnimating = true
-                }
-            }
+        .padding(.vertical, 16)
     }
 }

@@ -405,10 +345,6 @@ struct ThemeSelectionView: View {
     /// Current system color scheme (light/dark)
     @Environment(\.colorScheme) private var colorScheme

-    // Animation states for retrowave effects
-    @State private var isAnimating = false
-    @State private var glowOpacity = 0.0
-
     // MARK: - Background Components

     /// Background view with retrowave grid
@@ -429,7 +365,7 @@ struct ThemeSelectionView: View {

     /// Standard themes section
     private var standardThemesSection: some View {
-        ThemeSection(title: "STANDARD THEMES", titleColor: RetroTheme.retroBlue) {
+        ThemeSection(title: "Appearance", titleColor: RetroTheme.retroBlue) {
             ForEach(ThemeOptionsStandard.allCases, id: \.self) { option in
                 let isSelected = (currentTheme == .standard(option))

@@ -450,7 +386,7 @@ struct ThemeSelectionView: View {
     private var cgaThemesSection: some View {
         #if canImport(FreemiumKit)
         PaidFeatureView {
-            ThemeSection(title: "CGA THEMES", titleColor: RetroTheme.retroPink) {
+            ThemeSection(title: "Color themes", titleColor: RetroTheme.retroPink) {
                 ForEach(CGAThemes.allCases, id: \.self) { cgaTheme in
                     let isSelected = (currentTheme == .cga(ThemeOptionsCGA(rawValue: cgaTheme.rawValue) ?? .blue))

@@ -464,7 +400,7 @@ struct ThemeSelectionView: View {
             }
         } lockedView: {
             // Show themes but locked with overlay
-            ThemeSection(title: "CGA THEMES", titleColor: RetroTheme.retroPink) {
+            ThemeSection(title: "Color themes", titleColor: RetroTheme.retroPink) {
                 ForEach(CGAThemes.allCases.prefix(4), id: \.self) { cgaTheme in
                     CGAThemeRow(
                         cgaTheme: cgaTheme,
@@ -509,7 +445,7 @@ struct ThemeSelectionView: View {
         }
         .freemiumKitColorReset()
         #else
-        ThemeSection(title: "CGA THEMES", titleColor: RetroTheme.retroPink) {
+        ThemeSection(title: "Color themes", titleColor: RetroTheme.retroPink) {
             ForEach(CGAThemes.allCases, id: \.self) { cgaTheme in
                 let isSelected = (currentTheme == .cga(ThemeOptionsCGA(rawValue: cgaTheme.rawValue) ?? .blue))

@@ -530,14 +466,14 @@ struct ThemeSelectionView: View {
     private var retroWaveThemeSection: some View {
         #if canImport(FreemiumKit)
         PaidFeatureView {
-            ThemeSection(title: "RETROWAVE THEME", titleColor: RetroTheme.retroPurple) {
-                let isRetrowaveSelected = (currentTheme == .standard(.dark))
+            ThemeSection(title: "RetroWave", titleColor: RetroTheme.retroPurple) {
+                let isRetrowaveSelected = (currentTheme == .retrowave)
                 RetroWaveThemeRow(isSelected: isRetrowaveSelected) {
                     applyRetroWaveTheme()
                 }
             }
         } lockedView: {
-            ThemeSection(title: "RETROWAVE THEME", titleColor: RetroTheme.retroPurple) {
+            ThemeSection(title: "RetroWave", titleColor: RetroTheme.retroPurple) {
                 RetroWaveThemeRow(isSelected: false) { }

                 HStack {
@@ -574,8 +510,8 @@ struct ThemeSelectionView: View {
         }
         .freemiumKitColorReset()
         #else
-        ThemeSection(title: "RETROWAVE THEME", titleColor: RetroTheme.retroPurple) {
-            let isRetrowaveSelected = (currentTheme == .standard(.dark))
+        ThemeSection(title: "RetroWave", titleColor: RetroTheme.retroPurple) {
+            let isRetrowaveSelected = (currentTheme == .retrowave)
             RetroWaveThemeRow(isSelected: isRetrowaveSelected) {
                 applyRetroWaveTheme()
             }
@@ -588,9 +524,6 @@ struct ThemeSelectionView: View {
     /// Main content container
     private var contentView: some View {
         VStack(spacing: 20) {
-            // Title
-            ThemeSelectionTitleView(glowOpacity: $glowOpacity, isAnimating: $isAnimating)
-
             // Theme sections
             standardThemesSection
             cgaThemesSection
@@ -605,6 +538,12 @@ struct ThemeSelectionView: View {
             }
         }
         .padding()
+        #if os(tvOS)
+        .frame(maxWidth: 1100)
+        #else
+        .frame(maxWidth: 700)
+        #endif
+        .frame(maxWidth: .infinity)
     }

     var body: some View {
@@ -615,7 +554,11 @@ struct ThemeSelectionView: View {
                 contentView
             }
         }
-        .navigationTitle("Select Theme")
+        .navigationTitle("Theme")
+        .toolbarColorScheme(themeManager.currentPalette.dark ? .dark : .light, for: .navigationBar)
+        #if os(iOS)
+        .navigationBarTitleDisplayMode(.inline)
+        #endif
         #if os(tvOS)
         .focusSection()
         .onExitCommand { dismiss() }
@@ -627,12 +570,7 @@ struct ThemeSelectionView: View {

     /// Apply a standard theme
     private func applyStandardTheme(_ option: ThemeOptionsStandard) {
-        // Determine if dark theme should be applied
-        let darkTheme = (option == .auto && colorScheme == .dark) || option == .dark
-        let newPalette = darkTheme ? ProvenanceThemes.dark.palette : ProvenanceThemes.light.palette
-
         // Apply the selected theme
-        ThemeManager.shared.setCurrentPalette(newPalette)
         currentTheme = .standard(option)
         ThemeManager.applySavedTheme()
         dismiss()
@@ -641,8 +579,6 @@ struct ThemeSelectionView: View {
     /// Apply a CGA theme
     private func applyCGATheme(_ cgaTheme: CGAThemes) {
         // Apply selected CGA theme
-        let palette = cgaTheme.palette
-        ThemeManager.shared.setCurrentPalette(palette)
         let themeOptionCGA = ThemeOptionsCGA(rawValue: cgaTheme.rawValue) ?? .blue
         currentTheme = .cga(themeOptionCGA)
         ThemeManager.applySavedTheme()
@@ -652,9 +588,8 @@ struct ThemeSelectionView: View {
     /// Apply the RetroWave theme
     private func applyRetroWaveTheme() {
         // Apply the official RetroWave theme
-        ThemeManager.shared.setCurrentPalette(ProvenanceThemes.retrowave.palette)
-        // Set the theme to retrowave (using standard dark as fallback for now)
-        currentTheme = .standard(.dark)
+        // Persist RetroWave independently of the standard dark appearance.
+        currentTheme = .retrowave
         ThemeManager.applySavedTheme()
         dismiss()
     }
diff --git a/PVUI/Sources/PVSwiftUI/Settings/SettingsSearchViews.swift b/PVUI/Sources/PVSwiftUI/Settings/SettingsSearchViews.swift
index 42dddb6709..c66c825689 100644
--- a/PVUI/Sources/PVSwiftUI/Settings/SettingsSearchViews.swift
+++ b/PVUI/Sources/PVSwiftUI/Settings/SettingsSearchViews.swift
@@ -36,7 +36,7 @@ struct SettingsSearchField: View {
                     )
                 )

-            TextField("Search settings", text: $text)
+            TextField("Search settings", text: $text, prompt: Text("Search settings").foregroundColor(textColor.opacity(0.65)))
                 .focused(isFocused)
                 .textInputAutocapitalization(.never)
                 .autocorrectionDisabled()
diff --git a/PVUI/Sources/PVSwiftUI/Settings/SettingsSidebarContainer.swift b/PVUI/Sources/PVSwiftUI/Settings/SettingsSidebarContainer.swift
index d18112d85c..7456ed5d17 100644
--- a/PVUI/Sources/PVSwiftUI/Settings/SettingsSidebarContainer.swift
+++ b/PVUI/Sources/PVSwiftUI/Settings/SettingsSidebarContainer.swift
@@ -198,7 +198,7 @@ struct SettingsSidebarContainer<PaneContent: View>: View {
                 .padding(.horizontal, 16)
                 .padding(.vertical, 8)
             }
-            .background(.ultraThinMaterial)
+            .background(Color(themeManager.currentPalette.settingsHeaderBackground ?? themeManager.currentPalette.gameLibraryBackground))
             .onAppear { proxy.scrollTo(selectedPane, anchor: .center) }
             .onChange(of: selectedPane) { _, pane in
                 withAnimation { proxy.scrollTo(pane, anchor: .center) }
@@ -216,10 +216,9 @@ struct SettingsSidebarContainer<PaneContent: View>: View {
         }
         .padding(.horizontal, 14)
         .padding(.vertical, 8)
-        .foregroundColor(isSelected ? .white : textColor)
-        // Purple, not pink, under the white label: retroPink is too light for 12pt white text.
+        .foregroundColor(isSelected ? Color(themeManager.currentPalette.gameLibraryBackground) : textColor)
         .background(
-            Capsule().fill(isSelected ? AnyShapeStyle(Color.retroPurple) : AnyShapeStyle(.ultraThinMaterial))
+            Capsule().fill(isSelected ? Color.retroPink : surfaceColor)
         )
         .overlay(
             Capsule().strokeBorder(isSelected ? Color.retroPink : Color.clear, lineWidth: 1.5)
diff --git a/PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift b/PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift
index 13618e0080..fbf09c13c3 100644
--- a/PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift
+++ b/PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift
@@ -219,14 +219,15 @@ extension View {
 #if os(tvOS)
 /// Cinematic background for tvOS settings matching the Media UI aesthetic
 struct TVOSSettingsBackground: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     var body: some View {
         ZStack {
-            // Deep space gradient
+            // Layer the selected palette across the settings canvas.
             LinearGradient(
                 colors: [
-                    Color(red: 0.02, green: 0.02, blue: 0.06),
-                    Color(red: 0.05, green: 0.03, blue: 0.10),
-                    Color(red: 0.03, green: 0.02, blue: 0.08)
+                    Color(themeManager.currentPalette.gameLibraryBackground),
+                    Color(themeManager.currentPalette.gameLibraryHeaderBackground),
+                    Color(themeManager.currentPalette.gameLibraryBackground)
                 ],
                 startPoint: .top,
                 endPoint: .bottom
@@ -303,6 +304,7 @@ struct TVOSSettingsScanlines: View {

 /// Premium header for tvOS settings
 struct TVOSSettingsHeader: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     var body: some View {
         VStack(alignment: .leading, spacing: 16) {
             HStack(spacing: 20) {
@@ -330,7 +332,7 @@ struct TVOSSettingsHeader: View {
                         .tracking(4)
                         .foregroundStyle(
                             LinearGradient(
-                                colors: [.white, Color.retroBlue.opacity(0.9)],
+                                colors: [Color(themeManager.currentPalette.gameLibraryText), Color.retroBlue.opacity(0.9)],
                                 startPoint: .leading,
                                 endPoint: .trailing
                             )
@@ -340,7 +342,7 @@ struct TVOSSettingsHeader: View {
                     Text("settings.subtitle", bundle: .module)
                         .font(.system(size: 14, weight: .medium, design: .default))
                         .tracking(3)
-                        .foregroundStyle(Color.retroPink.opacity(0.7))
+                        .foregroundStyle(Color(themeManager.currentPalette.settingsCellTextDetail ?? themeManager.currentPalette.gameLibraryText))
                 }

                 Spacer()
@@ -403,6 +405,7 @@ extension EnvironmentValues {
 ///
 /// Collapsed sections do not build their rows, which keeps the long single-page layout cheap to scroll with a remote.
 struct TVOSSettingsSection<Content: View>: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let title: String
     let icon: String
     @ViewBuilder let content: () -> Content
@@ -447,11 +450,11 @@ struct TVOSSettingsSection<Content: View>: View {
                             .foregroundStyle(
                                 headerFocused ?
                                     AnyShapeStyle(LinearGradient(
-                                        colors: [.white, Color.retroBlue],
+                                        colors: [Color(themeManager.currentPalette.gameLibraryText), Color.retroBlue],
                                         startPoint: .top,
                                         endPoint: .bottom
                                     )) :
-                                    AnyShapeStyle(Color.white.opacity(0.6))
+                                    AnyShapeStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.6))
                             )
                             .shadow(color: headerFocused ? Color.retroPink.opacity(0.6) : .clear, radius: 8)
                     }
@@ -463,11 +466,11 @@ struct TVOSSettingsSection<Content: View>: View {
                         .foregroundStyle(
                             headerFocused ?
                                 AnyShapeStyle(LinearGradient(
-                                    colors: [.white, Color.retroBlue.opacity(0.9)],
+                                    colors: [Color(themeManager.currentPalette.gameLibraryText), Color.retroBlue.opacity(0.9)],
                                     startPoint: .leading,
                                     endPoint: .trailing
                                 )) :
-                                AnyShapeStyle(Color.white.opacity(0.85))
+                                AnyShapeStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.85))
                         )

                     Spacer()
@@ -478,7 +481,7 @@ struct TVOSSettingsSection<Content: View>: View {
                         .foregroundStyle(
                             headerFocused ?
                                 AnyShapeStyle(Color.retroPink) :
-                                AnyShapeStyle(Color.white.opacity(0.4))
+                                AnyShapeStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.4))
                         )
                         .animation(.spring(response: 0.3), value: isExpanded)
                 }
@@ -494,7 +497,7 @@ struct TVOSSettingsSection<Content: View>: View {
                                     endPoint: .bottomTrailing
                                 ) :
                                 LinearGradient(
-                                    colors: [Color.white.opacity(0.04), Color.white.opacity(0.02)],
+                                    colors: [Color(themeManager.currentPalette.gameLibraryText).opacity(0.04), Color(themeManager.currentPalette.gameLibraryText).opacity(0.02)],
                                     startPoint: .top,
                                     endPoint: .bottom
                                 )
@@ -510,7 +513,7 @@ struct TVOSSettingsSection<Content: View>: View {
                                     endPoint: .bottomTrailing
                                 ) :
                                 LinearGradient(
-                                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
+                                    colors: [Color(themeManager.currentPalette.gameLibraryText).opacity(0.08), Color(themeManager.currentPalette.gameLibraryText).opacity(0.04)],
                                     startPoint: .top,
                                     endPoint: .bottom
                                 ),
@@ -741,6 +744,7 @@ public struct PVSettingsView: View {
             }
         }
         .navigationViewStyle(StackNavigationViewStyle())
+        .environment(\.colorScheme, themeManager.currentPalette.dark ? .dark : .light)
         #if os(tvOS)
         .environment(\.settingsSubpageDepth, $settingsSubpageDepth)
         .onChange(of: settingsSubpageDepth) { depth in
@@ -1015,7 +1019,7 @@ struct SettingsRow: View {
                 Text(title)
                     #if os(tvOS)
                     .font(.system(size: 20, weight: .medium))
-                    .foregroundStyle(isFocused ? .white : Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText))
+                    .foregroundStyle(isFocused ? Color(themeManager.currentPalette.gameLibraryText) : Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText))
                     #else
                     .font(.headline)
                     .foregroundColor(Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText))
@@ -1025,10 +1029,10 @@ struct SettingsRow: View {
                     Text(subtitle)
                         #if os(tvOS)
                         .font(.system(size: 15))
-                        .foregroundStyle(isFocused ? .white.opacity(0.8) : Color(themeManager.currentPalette.settingsCellTextDetail ?? themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText).opacity(0.7))
+                        .foregroundStyle(Color(themeManager.currentPalette.settingsCellTextDetail ?? themeManager.currentPalette.gameLibraryText))
                         #else
                         .font(.footnote)
-                        .foregroundColor(Color(themeManager.currentPalette.settingsCellTextDetail ?? themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText).opacity(0.8))
+                        .foregroundColor(Color(themeManager.currentPalette.settingsCellTextDetail ?? themeManager.currentPalette.gameLibraryText))
                         #endif
                         .lineLimit(effectiveSubtitleLineLimit)
                         .multilineTextAlignment(.leading)
@@ -1083,7 +1087,7 @@ struct SettingsRow: View {
             if showChevron {
                 Image(systemName: "chevron.right")
                     .font(.system(size: 16, weight: .semibold))
-                    .foregroundStyle(isFocused ? Color.retroPink : Color.white.opacity(0.3))
+                    .foregroundStyle(isFocused ? Color.retroPink : Color(themeManager.currentPalette.gameLibraryText).opacity(0.3))
             }
             #endif
         }
@@ -1101,7 +1105,7 @@ struct SettingsRow: View {
                             endPoint: .bottomTrailing
                         ) :
                         LinearGradient(
-                            colors: [Color.white.opacity(0.03), Color.white.opacity(0.01)],
+                            colors: [Color(themeManager.currentPalette.gameLibraryText).opacity(0.03), Color(themeManager.currentPalette.gameLibraryText).opacity(0.01)],
                             startPoint: .top,
                             endPoint: .bottom
                         )
@@ -1117,7 +1121,7 @@ struct SettingsRow: View {
                             endPoint: .bottomTrailing
                         ) :
                         LinearGradient(
-                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
+                            colors: [Color(themeManager.currentPalette.gameLibraryText).opacity(0.06), Color(themeManager.currentPalette.gameLibraryText).opacity(0.02)],
                             startPoint: .top,
                             endPoint: .bottom
                         ),
@@ -1304,6 +1308,7 @@ private struct CoreOptionsSection: View {
 /// RetroWave-styled single-choice list for tvOS, replacing the clipped default Picker.
 /// Picking a row stores it and pops back to Settings.
 private struct TVOSSettingsChoiceView<Value: Hashable>: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let title: String
     let icon: String
     let choices: [Value]
@@ -1320,7 +1325,7 @@ private struct TVOSSettingsChoiceView<Value: Hashable>: View {
             .padding(.horizontal, 48)
             .padding(.vertical, 24)
         }
-        .background(Color.black)
+        .background(Color(themeManager.currentPalette.gameLibraryBackground))
         .focusSection()
         .onExitCommand { dismiss() }
         .settingsSubpageTracking()
@@ -1358,7 +1363,7 @@ private struct TVOSSettingsChoiceView<Value: Hashable>: View {
         .padding(12)
         .background(
             RoundedRectangle(cornerRadius: 12)
-                .fill(Color.white.opacity(0.03))
+                .fill(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground))
                 .overlay(
                     RoundedRectangle(cornerRadius: 12)
                         .strokeBorder(Color.retroPurple.opacity(0.15), lineWidth: 1)
@@ -1369,6 +1374,7 @@ private struct TVOSSettingsChoiceView<Value: Hashable>: View {

 /// Individual row in a `TVOSSettingsChoiceView` with RetroWave focus styling
 private struct TVOSSettingsChoiceRow: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let title: String
     let isSelected: Bool
     let action: () -> Void
@@ -1378,7 +1384,7 @@ private struct TVOSSettingsChoiceRow: View {
             HStack(spacing: 14) {
                 Text(title)
                     .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
-                    .foregroundColor(isSelected ? .white : .white.opacity(0.75))
+                    .foregroundColor(Color(themeManager.currentPalette.settingsCellText ?? themeManager.currentPalette.gameLibraryText).opacity(isSelected ? 1 : 0.85))
                     .lineLimit(1)

                 Spacer()
@@ -3054,6 +3060,8 @@ private struct RetroAchievementsSection: View {
 #if canImport(FreemiumKit)
 @available(iOS 15.0, tvOS 15.0, macOS 12.0, *)
 struct PlusStatusBanner: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
+
     var body: some View {
         PaidFeatureView {
             // Subscriber view
@@ -3080,7 +3088,7 @@ struct PlusStatusBanner: View {
                         )
                     Text("settings.plus.thank_you", bundle: .module)
                         .font(.system(size: 12))
-                        .foregroundColor(.gray)
+                        .foregroundColor(Color(themeManager.currentPalette.settingsCellTextDetail ?? themeManager.currentPalette.gameLibraryText))
                 }

                 Spacer()
@@ -3093,7 +3101,7 @@ struct PlusStatusBanner: View {
             .padding(.vertical, 14)
             .background(
                 RoundedRectangle(cornerRadius: 14)
-                    .fill(Color.black.opacity(0.5))
+                    .fill(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground))
                     .overlay(
                         RoundedRectangle(cornerRadius: 14)
                             .strokeBorder(
@@ -3135,7 +3143,7 @@ struct PlusStatusBanner: View {
                         )
                     Text("settings.plus.upgrade_description", bundle: .module)
                         .font(.system(size: 12))
-                        .foregroundColor(.gray)
+                        .foregroundColor(Color(themeManager.currentPalette.settingsCellTextDetail ?? themeManager.currentPalette.gameLibraryText))
                 }

                 Spacer()
@@ -3148,7 +3156,7 @@ struct PlusStatusBanner: View {
             .padding(.vertical, 14)
             .background(
                 RoundedRectangle(cornerRadius: 14)
-                    .fill(Color.black.opacity(0.5))
+                    .fill(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryBackground))
                     .overlay(
                         RoundedRectangle(cornerRadius: 14)
                             .strokeBorder(
diff --git a/PVUI/Sources/PVSwiftUI/tvOS Media UI/TVMediaGameTileView.swift b/PVUI/Sources/PVSwiftUI/tvOS Media UI/TVMediaGameTileView.swift
index be933ca18b..fa617f2e53 100644
--- a/PVUI/Sources/PVSwiftUI/tvOS Media UI/TVMediaGameTileView.swift
+++ b/PVUI/Sources/PVSwiftUI/tvOS Media UI/TVMediaGameTileView.swift
@@ -11,6 +11,7 @@ import Defaults
 /// Scales elegantly on focus with neon glow effects
 @available(tvOS 16.0, *)
 struct TVMediaGameTileView<MenuContent: View>: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let game: PVGame
     let titleFont: Font
     let onPlay: () -> Void
@@ -147,15 +148,7 @@ struct TVMediaGameTileView<MenuContent: View>: View {
                 Text(game.title)
                     .font(.system(size: 15, weight: isFocused ? .semibold : .medium, design: .default))
                     .tracking(0.3)
-                    .foregroundStyle(
-                        isFocused ?
-                            AnyShapeStyle(LinearGradient(
-                                colors: [.white, .white.opacity(0.9)],
-                                startPoint: .top,
-                                endPoint: .bottom
-                            )) :
-                            AnyShapeStyle(Color.white.opacity(0.8))
-                    )
+                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryCellText).opacity(isFocused ? 1 : 0.85))
                     .lineLimit(2)
                     .multilineTextAlignment(.center)
                     .frame(width: tileWidth)
diff --git a/PVUI/Sources/PVSwiftUI/tvOS Media UI/TVMediaMainView.swift b/PVUI/Sources/PVSwiftUI/tvOS Media UI/TVMediaMainView.swift
index 4f71a90076..0c0d01599c 100644
--- a/PVUI/Sources/PVSwiftUI/tvOS Media UI/TVMediaMainView.swift
+++ b/PVUI/Sources/PVSwiftUI/tvOS Media UI/TVMediaMainView.swift
@@ -163,6 +163,7 @@ struct TVMediaMainView: View {
             modalContent: { modal in modalContent(for: modal) },
             renameAlertContent: { renameAlertContent }
         )
+        .tint(Color(themeManager.currentPalette.defaultTintColor))
 #if !os(tvOS)
         // tvOS's default UI is this same TVMediaMainView, and TVMediaRouter.navigate(to:)
         // resets navigationPath + return destinations — on tvOS that would jump to Settings
@@ -1514,6 +1515,7 @@ struct TVMediaLogsView: View {
 // MARK: - Empty State View
 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaEmptyStateView: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let title: String
     let subtitle: String
     /// When true a compact controller-tip row is shown below the subtitle.
@@ -1554,12 +1556,12 @@ struct TVMediaEmptyStateView: View {

             Text(title)
                 .font(.title2.weight(.semibold))
-                .foregroundStyle(.white)
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))
                 .shadow(color: Color.retroPink.opacity(0.3), radius: 6)

             Text(subtitle)
                 .font(.callout)
-                .foregroundStyle(.white.opacity(0.7))
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.7))
                 .multilineTextAlignment(.center)
                 .frame(maxWidth: 520)

@@ -1575,7 +1577,7 @@ struct TVMediaEmptyStateView: View {
                 Text("tv_media.hint.swipe_navigation", bundle: .module)
                     .font(.caption)
             }
-            .foregroundStyle(.white.opacity(0.35))
+            .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
             .padding(.top, showControllerTip ? 8 : 16)
         }
         .frame(maxWidth: .infinity, maxHeight: .infinity)
@@ -1764,6 +1766,7 @@ struct VisibleSectionPreferenceKey: PreferenceKey {
 /// Also shows current scroll position indicator
 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaScrollIndexRail: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let systems: [PVSystem]
     let hasFavorites: Bool
     /// Currently visible/focused section in the main content
@@ -2004,6 +2007,7 @@ struct TVMediaScrollIndexRail: View {

 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaSavesView: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     @ObservedObject var model: TVMediaLibraryModel
     @ObservedObject var saveStatesStore: RetroSaveStatesStore
     @ObservedObject var router: TVMediaRouter
@@ -2152,17 +2156,17 @@ struct TVMediaSavesView: View {
         VStack(spacing: 14) {
             Image(systemName: "rectangle.stack.badge.play")
                 .font(.system(size: 44, weight: .light))
-                .foregroundStyle(.white.opacity(0.4))
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))

             Text(selectedSystems.isEmpty ? "No Save States" : "No Saves for Selection")
                 .font(.title3.weight(.semibold))
-                .foregroundStyle(.white)
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))

             Text(selectedSystems.isEmpty ?
                  "Play some games and create save states to see them here." :
                  "No save states found for the selected systems.")
                 .font(.callout)
-                .foregroundStyle(.white.opacity(0.7))
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.7))
                 .multilineTextAlignment(.center)
                 .frame(maxWidth: 480)

@@ -2192,7 +2196,7 @@ struct TVMediaSavesView: View {
                 Text("tv_media.hint.swipe_navigation", bundle: .module)
                     .font(.caption)
             }
-            .foregroundStyle(.white.opacity(0.35))
+            .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
             .padding(.top, 16)
         }
         .frame(maxWidth: .infinity, minHeight: 300)
@@ -2341,6 +2345,7 @@ struct TVMediaSavesView: View {
 /// Multi-select system filter picker for saves
 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaSystemFilterPicker: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let availableSystemIDs: [String]
     @Binding var selectedSystems: Set<String>
     @ObservedObject var model: TVMediaLibraryModel
@@ -2384,12 +2389,12 @@ struct TVMediaSystemFilterPicker: View {
                 Text("tv_media.filter.by_system", bundle: .module)
                     .font(.system(size: 28, weight: .bold, design: .default))
                     .tracking(2)
-                    .foregroundStyle(.white)
+                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))
                     .shadow(color: Color.retroPink.opacity(0.4), radius: 8)

                 Text("tv_media.filter.select_systems", bundle: .module)
                     .font(.system(size: 15, weight: .medium))
-                    .foregroundStyle(.white.opacity(0.6))
+                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.6))
             }

             Spacer()
@@ -2456,13 +2461,13 @@ struct TVMediaSystemFilterPicker: View {
                 VStack(alignment: .leading, spacing: 4) {
                     Text(systemName)
                         .font(.system(size: 18, weight: .semibold))
-                        .foregroundStyle(.white)
+                        .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))

                     if !shortName.isEmpty && shortName != systemName {
                         Text(shortName.uppercased())
                             .font(.system(size: 12, weight: .medium))
                             .tracking(0.8)
-                            .foregroundStyle(.white.opacity(0.5))
+                            .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
                     }
                 }

@@ -2662,6 +2667,7 @@ private struct TVMediaSaveStateTileButton: View {

 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaHomeView: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     @ObservedObject var model: TVMediaLibraryModel
     @ObservedObject var saveStatesStore: RetroSaveStatesStore
     @ObservedObject var gameActions: TVMediaGameActions
@@ -2912,7 +2918,7 @@ struct TVMediaHomeView: View {
             Text("tv_media.library.loading", bundle: .module)
                 .font(.system(size: 14, weight: .semibold, design: .default))
                 .tracking(2)
-                .foregroundStyle(.white.opacity(0.6))
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.6))
         }
         .frame(maxWidth: .infinity)
         .padding(.vertical, 100)
@@ -2949,12 +2955,12 @@ struct TVMediaHomeView: View {
                 Text("tv_media.library.no_games", bundle: .module)
                     .font(.system(size: 24, weight: .bold, design: .default))
                     .tracking(2)
-                    .foregroundStyle(.white)
+                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))
                     .shadow(color: Color.retroPink.opacity(0.4), radius: 8)

                 Text("tv_media.library.add_roms_hint", bundle: .module)
                     .font(.system(size: 16, weight: .medium))
-                    .foregroundStyle(.white.opacity(0.6))
+                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.6))
                     .multilineTextAlignment(.center)
                     .frame(maxWidth: 500)
 #if canImport(PVWebServer)
@@ -2993,7 +2999,7 @@ struct TVMediaHomeView: View {
                     Text("Swipe left or press Menu for navigation")
                         .font(.caption)
                 }
-                .foregroundStyle(.white.opacity(0.35))
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
             }
             .padding(.top, 16)

@@ -3076,6 +3082,7 @@ struct TVMediaHomeView: View {

 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaSystemsView: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     @ObservedObject var model: TVMediaLibraryModel
     @ObservedObject var router: TVMediaRouter

@@ -3249,10 +3256,10 @@ struct TVMediaSystemsView: View {

             Text("NO SYSTEMS YET")
                 .font(.title2.weight(.semibold))
-                .foregroundStyle(.white)
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))

             Text("Add games to see their systems here.")
-                .foregroundStyle(.white.opacity(0.7))
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.7))
                 .multilineTextAlignment(.center)

             TVMediaEmptyLibraryActionButtons(
@@ -3291,6 +3298,7 @@ struct TVMediaSystemsView: View {

 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaSystemCard: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let system: PVSystem
     let icon: Image?
     let gameCount: Int
@@ -3368,8 +3376,8 @@ struct TVMediaSystemCard: View {
                                 .foregroundStyle(
                                     LinearGradient(
                                         colors: isFocused ?
-                                            [.white, Color.retroBlue.opacity(0.85)] :
-                                            [.white.opacity(0.7), .white.opacity(0.5)],
+                                            [Color(themeManager.currentPalette.gameLibraryText), Color.retroBlue.opacity(0.85)] :
+                                            [Color(themeManager.currentPalette.gameLibraryText).opacity(0.7), Color(themeManager.currentPalette.gameLibraryText).opacity(0.72)],
                                         startPoint: .top,
                                         endPoint: .bottom
                                     )
@@ -3382,8 +3390,8 @@ struct TVMediaSystemCard: View {
                                 .foregroundStyle(
                                     LinearGradient(
                                         colors: isFocused ?
-                                            [.white, Color.retroBlue.opacity(0.8)] :
-                                            [.white.opacity(0.4), .white.opacity(0.3)],
+                                            [Color(themeManager.currentPalette.gameLibraryText), Color.retroBlue.opacity(0.8)] :
+                                            [Color(themeManager.currentPalette.gameLibraryText).opacity(0.72), Color(themeManager.currentPalette.gameLibraryText).opacity(0.3)],
                                         startPoint: .top,
                                         endPoint: .bottom
                                     )
@@ -3396,7 +3404,7 @@ struct TVMediaSystemCard: View {
                     Text(system.name.uppercased())
                         .font(.system(size: 15, weight: .bold, design: .default))
                         .tracking(0.6)
-                        .foregroundStyle(isFocused ? .white : .white.opacity(0.9))
+                        .foregroundStyle(isFocused ? Color(themeManager.currentPalette.gameLibraryText) : Color(themeManager.currentPalette.gameLibraryText).opacity(0.9))
                         .multilineTextAlignment(.center)
                         .lineLimit(2)
                         .minimumScaleFactor(0.7)
@@ -3407,18 +3415,18 @@ struct TVMediaSystemCard: View {
                     HStack(spacing: 6) {
                         Text(verbatim: "\(gameCount)")
                             .font(.system(size: 14, weight: .semibold, design: .monospaced))
-                            .foregroundStyle(isFocused ? Color.retroBlue : .white.opacity(0.6))
+                            .foregroundStyle(isFocused ? Color.retroBlue : Color(themeManager.currentPalette.gameLibraryText).opacity(0.6))
                         Text("tv_media.games", bundle: .module)
                             .font(.system(size: 10, weight: .medium, design: .default))
                             .tracking(1)
-                            .foregroundStyle(.white.opacity(0.45))
+                            .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
                     }

                     if !system.manufacturer.isEmpty || system.releaseYear > 0 {
                         Text(systemMetadataFull(system).uppercased())
                             .font(.system(size: 10, weight: .medium, design: .default))
                             .tracking(0.6)
-                            .foregroundStyle(.white.opacity(0.35))
+                            .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
                             .lineLimit(1)
                             .multilineTextAlignment(.center)
                             .frame(maxWidth: .infinity)
@@ -3456,8 +3464,8 @@ struct TVMediaSystemCard: View {
                                     .foregroundStyle(
                                         LinearGradient(
                                             colors: isFocused ?
-                                                [.white, Color.retroBlue.opacity(0.85)] :
-                                                [.white.opacity(0.7), .white.opacity(0.5)],
+                                                [Color(themeManager.currentPalette.gameLibraryText), Color.retroBlue.opacity(0.85)] :
+                                                [Color(themeManager.currentPalette.gameLibraryText).opacity(0.7), Color(themeManager.currentPalette.gameLibraryText).opacity(0.72)],
                                             startPoint: .top,
                                             endPoint: .bottom
                                         )
@@ -3470,8 +3478,8 @@ struct TVMediaSystemCard: View {
                                     .foregroundStyle(
                                         LinearGradient(
                                             colors: isFocused ?
-                                                [.white, Color.retroBlue.opacity(0.8)] :
-                                                [.white.opacity(0.4), .white.opacity(0.3)],
+                                                [Color(themeManager.currentPalette.gameLibraryText), Color.retroBlue.opacity(0.8)] :
+                                                [Color(themeManager.currentPalette.gameLibraryText).opacity(0.72), Color(themeManager.currentPalette.gameLibraryText).opacity(0.3)],
                                             startPoint: .top,
                                             endPoint: .bottom
                                         )
@@ -3486,7 +3494,7 @@ struct TVMediaSystemCard: View {
                             Text(system.name.uppercased())
                                 .font(.system(size: 17, weight: .bold, design: .default))
                                 .tracking(0.8)
-                                .foregroundStyle(isFocused ? .white : .white.opacity(0.85))
+                                .foregroundStyle(isFocused ? Color(themeManager.currentPalette.gameLibraryText) : Color(themeManager.currentPalette.gameLibraryText).opacity(0.85))
                                 .lineLimit(2)
                                 .minimumScaleFactor(0.8)
                                 .fixedSize(horizontal: false, vertical: true)
@@ -3496,11 +3504,11 @@ struct TVMediaSystemCard: View {
                             HStack(spacing: 6) {
                                 Text(verbatim: "\(gameCount)")
                                     .font(.system(size: 15, weight: .semibold, design: .monospaced))
-                                    .foregroundStyle(isFocused ? Color.retroBlue : .white.opacity(0.6))
+                                    .foregroundStyle(isFocused ? Color.retroBlue : Color(themeManager.currentPalette.gameLibraryText).opacity(0.6))
                                 Text("tv_media.games", bundle: .module)
                                     .font(.system(size: 11, weight: .medium, design: .default))
                                     .tracking(1)
-                                    .foregroundStyle(.white.opacity(0.45))
+                                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
                             }
                         }

@@ -3516,7 +3524,7 @@ struct TVMediaSystemCard: View {
                                         startPoint: .top,
                                         endPoint: .bottom
                                     )) :
-                                    AnyShapeStyle(Color.white.opacity(0.2))
+                                    AnyShapeStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.2))
                             )
                             .shadow(color: isFocused ? Color.retroBlue.opacity(0.5) : .clear, radius: 6)
                     }
@@ -3526,7 +3534,7 @@ struct TVMediaSystemCard: View {
                         Text(systemMetadataFull(system).uppercased())
                             .font(.system(size: 11, weight: .medium, design: .default))
                             .tracking(0.8)
-                            .foregroundStyle(.white.opacity(0.35))
+                            .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
                             .lineLimit(1)
                             .padding(.top, 12)
                             .padding(.leading, 100) // Align with text
@@ -3570,7 +3578,7 @@ struct TVMediaSystemCard: View {
                         endPoint: .bottomTrailing
                     ) :
                     LinearGradient(
-                        colors: [Color.white.opacity(0.02), Color.white.opacity(0.01)],
+                        colors: [Color(themeManager.currentPalette.gameLibraryText).opacity(0.02), Color(themeManager.currentPalette.gameLibraryText).opacity(0.01)],
                         startPoint: .leading,
                         endPoint: .trailing
                     )
@@ -3591,7 +3599,7 @@ struct TVMediaSystemCard: View {
                         endPoint: .bottomTrailing
                     ) :
                     LinearGradient(
-                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)],
+                        colors: [Color(themeManager.currentPalette.gameLibraryText).opacity(0.06), Color(themeManager.currentPalette.gameLibraryText).opacity(0.03)],
                         startPoint: .leading,
                         endPoint: .trailing
                     ),
@@ -3640,6 +3648,7 @@ struct TVMediaFlatButtonStyle: ButtonStyle {
 /// View All card that appears at the end of horizontal shelves
 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaViewAllCard: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let title: String
     let subtitle: String
     let action: () -> Void
@@ -3672,11 +3681,11 @@ struct TVMediaViewAllCard: View {
                         .foregroundStyle(
                             isFocused ?
                                 AnyShapeStyle(LinearGradient(
-                                    colors: [.white, Color.retroBlue.opacity(0.9)],
+                                    colors: [Color(themeManager.currentPalette.gameLibraryText), Color.retroBlue.opacity(0.9)],
                                     startPoint: .top,
                                     endPoint: .bottom
                                 )) :
-                                AnyShapeStyle(Color.white.opacity(0.5))
+                                AnyShapeStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
                         )
                         .shadow(color: isFocused ? Color.retroPink.opacity(0.6) : .clear, radius: 10)
                 }
@@ -3685,11 +3694,11 @@ struct TVMediaViewAllCard: View {
                     Text(title.uppercased())
                         .font(.system(size: 15, weight: .semibold, design: .default))
                         .tracking(1)
-                        .foregroundStyle(isFocused ? .white : .white.opacity(0.8))
+                        .foregroundStyle(isFocused ? Color(themeManager.currentPalette.gameLibraryText) : Color(themeManager.currentPalette.gameLibraryText).opacity(0.8))

                     Text(subtitle)
                         .font(.system(size: 12, weight: .medium, design: .default))
-                        .foregroundStyle(.white.opacity(0.5))
+                        .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
                 }
             }
             .frame(width: cardWidth, height: cardHeight)
@@ -3703,7 +3712,7 @@ struct TVMediaViewAllCard: View {
                                 endPoint: .bottomTrailing
                             ) :
                             LinearGradient(
-                                colors: [Color.white.opacity(0.03), Color.white.opacity(0.01)],
+                                colors: [Color(themeManager.currentPalette.gameLibraryText).opacity(0.03), Color(themeManager.currentPalette.gameLibraryText).opacity(0.01)],
                                 startPoint: .top,
                                 endPoint: .bottom
                             )
@@ -3719,7 +3728,7 @@ struct TVMediaViewAllCard: View {
                                 endPoint: .bottomTrailing
                             ) :
                             LinearGradient(
-                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
+                                colors: [Color(themeManager.currentPalette.gameLibraryText).opacity(0.08), Color(themeManager.currentPalette.gameLibraryText).opacity(0.04)],
                                 startPoint: .top,
                                 endPoint: .bottom
                             ),
@@ -3739,6 +3748,7 @@ struct TVMediaViewAllCard: View {
 /// View All card for save states shelf
 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaSaveStatesViewAllCard: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let count: Int
     let action: () -> Void

@@ -3769,11 +3779,11 @@ struct TVMediaSaveStatesViewAllCard: View {
                         .foregroundStyle(
                             isFocused ?
                                 AnyShapeStyle(LinearGradient(
-                                    colors: [.white, Color.retroBlue.opacity(0.9)],
+                                    colors: [Color(themeManager.currentPalette.gameLibraryText), Color.retroBlue.opacity(0.9)],
                                     startPoint: .top,
                                     endPoint: .bottom
                                 )) :
-                                AnyShapeStyle(Color.white.opacity(0.5))
+                                AnyShapeStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
                         )
                         .shadow(color: isFocused ? Color.retroBlue.opacity(0.6) : .clear, radius: 8)
                 }
@@ -3782,11 +3792,11 @@ struct TVMediaSaveStatesViewAllCard: View {
                     Text("tv_media.saves.view_all", bundle: .module)
                         .font(.system(size: 13, weight: .semibold, design: .default))
                         .tracking(1)
-                        .foregroundStyle(isFocused ? .white : .white.opacity(0.8))
+                        .foregroundStyle(isFocused ? Color(themeManager.currentPalette.gameLibraryText) : Color(themeManager.currentPalette.gameLibraryText).opacity(0.8))

                     Text(verbatim: String.localizedStringWithFormat(NSLocalizedString("tv_media.saves.count", bundle: .module, comment: ""), count))
                         .font(.system(size: 11, weight: .medium, design: .default))
-                        .foregroundStyle(.white.opacity(0.5))
+                        .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
                 }
             }
             .frame(width: cardWidth, height: cardHeight)
@@ -3800,7 +3810,7 @@ struct TVMediaSaveStatesViewAllCard: View {
                                 endPoint: .bottomTrailing
                             ) :
                             LinearGradient(
-                                colors: [Color.white.opacity(0.03), Color.white.opacity(0.01)],
+                                colors: [Color(themeManager.currentPalette.gameLibraryText).opacity(0.03), Color(themeManager.currentPalette.gameLibraryText).opacity(0.01)],
                                 startPoint: .top,
                                 endPoint: .bottom
                             )
@@ -3816,7 +3826,7 @@ struct TVMediaSaveStatesViewAllCard: View {
                                 endPoint: .bottomTrailing
                             ) :
                             LinearGradient(
-                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
+                                colors: [Color(themeManager.currentPalette.gameLibraryText).opacity(0.08), Color(themeManager.currentPalette.gameLibraryText).opacity(0.04)],
                                 startPoint: .top,
                                 endPoint: .bottom
                             ),
@@ -3837,6 +3847,7 @@ struct TVMediaSaveStatesViewAllCard: View {

 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaSystemGamesView: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let system: PVSystem
     @ObservedObject var model: TVMediaLibraryModel
     @ObservedObject var saveStatesStore: RetroSaveStatesStore
@@ -3861,7 +3872,7 @@ struct TVMediaSystemGamesView: View {
                         ProgressView("Loading...")
                             .controlSize(.large)
                             .frame(maxWidth: .infinity, minHeight: 200)
-                            .foregroundStyle(.white.opacity(0.7))
+                            .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.7))
                     } else {
                         // Recently played shelf
                         if !recentGames.isEmpty {
@@ -3904,7 +3915,7 @@ struct TVMediaSystemGamesView: View {
                                 Text("tv_media.all_system_games \(system.shortName.uppercased())", bundle: .module)
                                     .font(.system(size: 18, weight: .semibold, design: .default))
                                     .tracking(1.2)
-                                    .foregroundStyle(.white.opacity(0.95))
+                                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.95))

                                 Spacer()

@@ -3912,7 +3923,7 @@ struct TVMediaSystemGamesView: View {
                                 Text(verbatim: String.localizedStringWithFormat(NSLocalizedString("tv_media.games_count", bundle: .module, comment: ""), gameCount))
                                     .font(.system(size: 13, weight: .medium, design: .default))
                                     .tracking(0.8)
-                                    .foregroundStyle(.white.opacity(0.4))
+                                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
                             }

                             TVMediaAllGamesGrid(
@@ -3963,6 +3974,7 @@ struct TVMediaSystemGamesView: View {

 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaSystemHeader: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let system: PVSystem

     var body: some View {
@@ -3974,17 +3986,17 @@ struct TVMediaSystemHeader: View {
                 size: 52,
                 placeholder: "gamecontroller.fill"
             )
-            .foregroundStyle(.white.opacity(0.85))
+            .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.85))
             .frame(width: 80, height: 80)

             VStack(alignment: .leading, spacing: 6) {
                 Text(system.name)
                     .font(.largeTitle.weight(.bold))
-                    .foregroundStyle(.white)
+                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))

                 Text(systemMetadataLine(system))
                     .font(.subheadline.weight(.medium))
-                    .foregroundStyle(.white.opacity(0.6))
+                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.6))
                     .lineLimit(1)
             }

@@ -4127,6 +4139,7 @@ struct TVMediaAllGamesGrid: View {

 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaSearchView: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     @ObservedObject var model: TVMediaLibraryModel
     @ObservedObject var gameActions: TVMediaGameActions

@@ -4310,7 +4323,7 @@ struct TVMediaSearchView: View {
             TextField("Search games…", text: $text)
                 .textInputAutocapitalization(.never)
                 .disableAutocorrection(true)
-                .foregroundStyle(.white)
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))
                 .font(.system(size: 24, weight: .medium))
                 .focused($isSearchFieldFocused)
                 .onChange(of: text) { _ in
@@ -4471,7 +4484,7 @@ struct TVMediaSearchView: View {
                 Text("tv_media.search.recent_searches", bundle: .module)
                     .font(.system(size: 13, weight: .semibold, design: .default))
                     .tracking(1.2)
-                    .foregroundStyle(.white.opacity(0.7))
+                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.7))

                 Spacer()

@@ -4660,12 +4673,12 @@ struct TVMediaSearchView: View {
                 Text("tv_media.search.prompt", bundle: .module)
                     .font(.system(size: 18, weight: .bold, design: .default))
                     .tracking(1.5)
-                    .foregroundStyle(.white)
+                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))
                     .shadow(color: Color.retroPink.opacity(0.3), radius: 6)

                 Text("tv_media.search.type_hint", bundle: .module)
                     .font(.system(size: 14, weight: .medium))
-                    .foregroundStyle(.white.opacity(0.5))
+                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
             }

             // Navigation hint
@@ -4675,7 +4688,7 @@ struct TVMediaSearchView: View {
                 Text("tv_media.hint.swipe_navigation", bundle: .module)
                     .font(.caption)
             }
-            .foregroundStyle(.white.opacity(0.35))
+            .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
             .padding(.top, 16)
         }
         .frame(maxWidth: .infinity, minHeight: 280)
@@ -4711,11 +4724,11 @@ struct TVMediaSearchView: View {
                 Text("tv_media.search.no_results", bundle: .module)
                     .font(.system(size: 18, weight: .bold, design: .default))
                     .tracking(1.5)
-                    .foregroundStyle(.white)
+                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))

                 Text("No games found for \"\(text)\"")
                     .font(.system(size: 14, weight: .medium))
-                .foregroundStyle(.white.opacity(0.6))
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.6))
         }

             // Suggestion to try different search
@@ -4768,6 +4781,7 @@ struct TVMediaSearchView: View {

 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaFavoritesView: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     @ObservedObject var model: TVMediaLibraryModel
     @ObservedObject var gameActions: TVMediaGameActions

@@ -4803,15 +4817,15 @@ struct TVMediaFavoritesView: View {
         VStack(spacing: 14) {
             Image(systemName: "heart")
                 .font(.system(size: 44, weight: .light))
-                .foregroundStyle(.white.opacity(0.4))
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))

             Text("tv_media.favorites.no_favorites", bundle: .module)
                 .font(.title3.weight(.semibold))
-                .foregroundStyle(.white)
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))

             Text("tv_media.favorites.mark_hint", bundle: .module)
                 .font(.callout)
-                .foregroundStyle(.white.opacity(0.7))
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.7))
                 .multilineTextAlignment(.center)
                 .frame(maxWidth: 480)

@@ -4822,7 +4836,7 @@ struct TVMediaFavoritesView: View {
                 Text("tv_media.hint.swipe_navigation", bundle: .module)
                     .font(.caption)
             }
-            .foregroundStyle(.white.opacity(0.35))
+            .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
             .padding(.top, 16)
         }
         .frame(maxWidth: .infinity, minHeight: 300)
@@ -4833,6 +4847,7 @@ struct TVMediaFavoritesView: View {
 // MARK: - Top Bar

 struct TVMediaTopBar: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let title: String

     var body: some View {
@@ -4869,7 +4884,7 @@ struct TVMediaTopBar: View {
                 .tracking(2)
                 .foregroundStyle(
                     LinearGradient(
-                        colors: [.white, .white.opacity(0.85)],
+                        colors: [Color(themeManager.currentPalette.gameLibraryText), Color(themeManager.currentPalette.gameLibraryText).opacity(0.85)],
                         startPoint: .leading,
                         endPoint: .trailing
                     )
@@ -4920,6 +4935,7 @@ private struct TVMediaSystemIconView: View {

 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaShelf: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let title: String
     let items: [PVGame]
     @ObservedObject var gameActions: TVMediaGameActions
@@ -4961,7 +4977,7 @@ struct TVMediaShelf: View {
                 Text(title.uppercased())
                     .font(.system(size: 16, weight: .semibold, design: .default))
                     .tracking(1.2)
-                    .foregroundStyle(.white.opacity(0.9))
+                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.9))
                     .shadow(color: Color.retroPink.opacity(0.3), radius: 4)
             }

@@ -4988,6 +5004,7 @@ struct TVMediaShelf: View {

 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaSystemShelfRow: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let system: PVSystem
     let games: [PVGame]
     @ObservedObject var gameActions: TVMediaGameActions
@@ -5024,7 +5041,7 @@ struct TVMediaSystemShelfRow: View {
                 TVMediaSystemIconView(systemIdentifier: system.identifier, size: 30)
                     .foregroundStyle(
                         LinearGradient(
-                            colors: [.white.opacity(0.9), Color.retroBlue.opacity(0.7)],
+                            colors: [Color(themeManager.currentPalette.gameLibraryText).opacity(0.9), Color.retroBlue.opacity(0.7)],
                             startPoint: .top,
                             endPoint: .bottom
                         )
@@ -5034,7 +5051,7 @@ struct TVMediaSystemShelfRow: View {
                 Text(system.name.uppercased())
                     .font(.system(size: 17, weight: .semibold, design: .default))
                     .tracking(1)
-                    .foregroundStyle(.white.opacity(0.95))
+                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.95))
                     .shadow(color: Color.retroPink.opacity(0.2), radius: 4)

                 Spacer()
@@ -5043,7 +5060,7 @@ struct TVMediaSystemShelfRow: View {
                 Text(verbatim: "\(games.count) GAMES")
                     .font(.system(size: 12, weight: .medium, design: .default))
                     .tracking(0.8)
-                    .foregroundStyle(.white.opacity(0.4))
+                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
             }

             // Horizontal scroll with games + View All card at the end
@@ -5083,6 +5100,7 @@ struct TVMediaSystemShelfRow: View {

 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaSaveStatesShelfRow: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let title: String
     let items: [RetroSaveStateItem]
     @ObservedObject var store: RetroSaveStatesStore
@@ -5111,7 +5129,7 @@ struct TVMediaSaveStatesShelfRow: View {
                 Text(title.uppercased())
                     .font(.system(size: 13, weight: .semibold, design: .default))
                     .tracking(1.2)
-                    .foregroundStyle(.white.opacity(0.65))
+                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.65))
             }

             ScrollView(.horizontal, showsIndicators: false) {
@@ -5314,16 +5332,17 @@ struct TVMediaSearchResultsGrid: View {
 // MARK: - Background

 struct TVMediaBackground: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     var body: some View {
         ZStack {
-            // Deep base - true black with subtle blue tint
-            Color(red: 0.01, green: 0.01, blue: 0.03)
+            // The library surface carries the selected theme across the full TV canvas.
+            Color(themeManager.currentPalette.gameLibraryBackground)

             // Radial gradient for depth
             RadialGradient(
                 colors: [
-                    Color(red: 0.03, green: 0.02, blue: 0.06),
-                    Color(red: 0.01, green: 0.01, blue: 0.02)
+                    Color(themeManager.currentPalette.gameLibraryHeaderBackground),
+                    Color(themeManager.currentPalette.gameLibraryBackground)
                 ],
                 center: .topLeading,
                 startRadius: 100,
@@ -5386,7 +5405,7 @@ struct TVMediaBackground: View {

             // Subtle vignette
             RadialGradient(
-                colors: [.clear, .black.opacity(0.4)],
+                colors: [.clear, .black.opacity(themeManager.currentPalette.dark ? 0.4 : 0.03)],
                 center: .center,
                 startRadius: 400,
                 endRadius: 1200
@@ -5830,6 +5849,7 @@ struct TVMediaImportStatusToaster: View {
 /// RetroWave-themed view showing how to add ROMs via various methods
 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaROMInstructionsView: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     let onDismiss: () -> Void

     #if canImport(PVWebServer)
@@ -5917,7 +5937,7 @@ struct TVMediaROMInstructionsView: View {

     var body: some View {
         ZStack {
-            Color(red: 0.04, green: 0.04, blue: 0.08)
+            Color(themeManager.currentPalette.gameLibraryBackground)
                 .ignoresSafeArea()

             ScrollView {
@@ -5971,12 +5991,12 @@ struct TVMediaROMInstructionsView: View {

             Text("tv_media.roms.adding", bundle: .module)
                 .font(.system(size: titleFontSize, weight: .bold))
-                .foregroundStyle(.white)
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))
                 .shadow(color: .retroBlue.opacity(0.6), radius: 8)

             Text("tv_media.roms.several_ways", bundle: .module)
                 .font(.system(size: subtitleFontSize))
-                .foregroundStyle(.white.opacity(0.7))
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.7))
                 .multilineTextAlignment(.center)
         }
         .padding(.bottom, 8)
@@ -6009,7 +6029,7 @@ struct TVMediaROMInstructionsView: View {
             } else {
                 Text("tv_media.roms.start_web_server", bundle: .module)
                     .font(.system(size: cardSubtitleFontSize))
-                    .foregroundStyle(.white.opacity(0.5))
+                    .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.72))
                     .italic()
             }
             #endif
@@ -6079,7 +6099,7 @@ struct TVMediaROMInstructionsView: View {
                 VStack(alignment: .leading, spacing: 4) {
                     Text("tv_media.roms.full_documentation", bundle: .module)
                         .font(.system(size: cardTitleFontSize, weight: .bold))
-                        .foregroundStyle(.white)
+                        .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))

                     Text(wikiURL)
                         .font(.system(size: cardSubtitleFontSize, design: .monospaced))
@@ -6147,7 +6167,7 @@ struct TVMediaROMInstructionsView: View {
                 VStack(alignment: .leading, spacing: 4) {
                     Text(title)
                         .font(.system(size: cardTitleFontSize, weight: .bold))
-                        .foregroundStyle(.white)
+                        .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))
                         .shadow(color: accentColor.opacity(0.4), radius: 4)

                     Text(subtitle)
@@ -6160,7 +6180,7 @@ struct TVMediaROMInstructionsView: View {

             Text(description)
                 .font(.system(size: cardDescriptionFontSize))
-                .foregroundStyle(.white.opacity(0.75))
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText).opacity(0.75))
                 .lineSpacing(4)

             extras()
diff --git a/PVUI/Sources/PVSwiftUI/tvOS Media UI/TVMediaSidebarRail.swift b/PVUI/Sources/PVSwiftUI/tvOS Media UI/TVMediaSidebarRail.swift
index 89c4c51677..2979d5dcf8 100644
--- a/PVUI/Sources/PVSwiftUI/tvOS Media UI/TVMediaSidebarRail.swift
+++ b/PVUI/Sources/PVSwiftUI/tvOS Media UI/TVMediaSidebarRail.swift
@@ -11,6 +11,7 @@ import PVSettings
 /// Icon-only rail that expands elegantly on focus
 @available(tvOS 16.0, iOS 17.0, *)
 struct TVMediaSidebarRail: View {
+    @ObservedObject private var themeManager = ThemeManager.shared
     @Binding var destination: TVMediaDestination
     @ObservedObject var focusCoordinator: TVMediaFocusCoordinator
     @ObservedObject var router: TVMediaRouter
@@ -247,7 +248,7 @@ struct TVMediaSidebarRail: View {
                         .tracking(2)
                         .foregroundStyle(
                             LinearGradient(
-                                colors: [.white, Color.retroBlue.opacity(0.8)],
+                                colors: [Color(themeManager.currentPalette.menuText), Color.retroBlue.opacity(0.8)],
                                 startPoint: .leading,
                                 endPoint: .trailing
                             )
@@ -350,11 +351,11 @@ struct TVMediaSidebarRail: View {
                         .foregroundStyle(
                             isFocused ?
                                 AnyShapeStyle(LinearGradient(
-                                    colors: [.white, Color.retroBlue.opacity(0.9)],
+                                    colors: [Color(themeManager.currentPalette.menuText), Color.retroBlue.opacity(0.9)],
                                     startPoint: .top,
                                     endPoint: .bottom
                                 )) :
-                                AnyShapeStyle(isSelected ? Color.white : Color.white.opacity(0.5))
+                                AnyShapeStyle(isSelected ? Color(themeManager.currentPalette.menuText) : Color(themeManager.currentPalette.menuText).opacity(0.5))
                         )
                         .frame(width: 32, height: 32)
                         .shadow(color: isFocused ? Color.retroPink.opacity(0.8) : .clear, radius: 8)
@@ -366,8 +367,8 @@ struct TVMediaSidebarRail: View {
                         .font(.system(size: 14, weight: isFocused ? .semibold : .medium, design: .default))
                         .tracking(1.5) // Refined letter spacing
                         .foregroundStyle(
-                            isFocused ? .white :
-                            (isSelected ? .white.opacity(0.9) : .white.opacity(0.6))
+                            isFocused ? Color(themeManager.currentPalette.menuText) :
+                            (isSelected ? Color(themeManager.currentPalette.menuText).opacity(0.9) : Color(themeManager.currentPalette.menuText).opacity(0.6))
                         )
                         .shadow(color: isFocused ? Color.retroPink.opacity(0.5) : .clear, radius: 6)
                         .transition(.asymmetric(
@@ -414,7 +415,7 @@ struct TVMediaSidebarRail: View {
                     ) :
                     (isSelected ?
                         LinearGradient(
-                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)],
+                            colors: [Color(themeManager.currentPalette.menuText).opacity(0.06), Color(themeManager.currentPalette.menuText).opacity(0.03)],
                             startPoint: .leading,
                             endPoint: .trailing
                         ) :
@@ -467,9 +468,9 @@ struct TVMediaSidebarRail: View {

     private var sidebarBackground: some View {
         ZStack {
-            // Deep dark base
+            // Palette surface
             Rectangle()
-                .fill(Color(red: 0.02, green: 0.02, blue: 0.04))
+                .fill(Color(themeManager.currentPalette.menuBackground))

             // Subtle gradient overlay
             LinearGradient(
@@ -506,7 +507,7 @@ struct TVMediaSidebarRail: View {
                 .opacity(0.03)
         }
         .shadow(color: Color.retroPink.opacity(0.1), radius: 30, x: 8, y: 0)
-        .shadow(color: .black.opacity(0.9), radius: 50, x: 15, y: 0)
+        .shadow(color: .black.opacity(themeManager.currentPalette.dark ? 0.45 : 0.08), radius: 24, x: 6, y: 0)
     }

     private var scanlineOverlay: some View {
@@ -514,7 +515,7 @@ struct TVMediaSidebarRail: View {
             VStack(spacing: 0) {
                 ForEach(0..<Int(geo.size.height / 3), id: \.self) { _ in
                     Color.clear.frame(height: 2)
-                    Color.white.frame(height: 1)
+                    Color(themeManager.currentPalette.menuText).frame(height: 1)
                 }
             }
         }
diff --git a/PVUI/Sources/PVUIBase/SwiftUI/Components/RetroWave/RetroTheme.swift b/PVUI/Sources/PVUIBase/SwiftUI/Components/RetroWave/RetroTheme.swift
index ff7e8e3ae3..608bf2f785 100644
--- a/PVUI/Sources/PVUIBase/SwiftUI/Components/RetroWave/RetroTheme.swift
+++ b/PVUI/Sources/PVUIBase/SwiftUI/Components/RetroWave/RetroTheme.swift
@@ -5,13 +5,13 @@ import PVThemes
 /// RetroTheme provides retrowave styling elements for the Settings UI
 public struct RetroTheme {
     // MARK: - Colors
-    public static let retroPink = Color.retroPink
-    public static let retroPurple = Color.retroPurple
-    public static let retroBlue = Color.retroBlue
-    public static let retroDarkBlue = Color.retroDarkBlue
-    public static let retroBlack = Color.retroBlack
-    public static let retroBlackClear = Color.retroBlackClear
-    public static let retroGreen = Color.retroGreen
+    public static var retroPink: Color { Color.retroPink }
+    public static var retroPurple: Color { Color.retroPurple }
+    public static var retroBlue: Color { Color.retroBlue }
+    public static var retroDarkBlue: Color { Color.retroDarkBlue }
+    public static var retroBlack: Color { Color.retroBlack }
+    public static var retroBlackClear: Color { Color.retroBlackClear }
+    public static var retroGreen: Color { Color.retroGreen }

     // MARK: - Gradients
     public static let retroGradient = LinearGradient(
@@ -78,25 +78,27 @@ public struct RetroTheme {

     // MARK: - Button Styles
     public struct RetroButtonStyle: ButtonStyle {
+        @ObservedObject private var themeManager = ThemeManager.shared
         public func makeBody(configuration: Configuration) -> some View {
             configuration.label
                 .padding(.vertical, 10)
                 .padding(.horizontal, 20)
                 .background(
                     RoundedRectangle(cornerRadius: RetroPauseChrome.radiusSM)
-                        .fill(Color.black.opacity(0.6))
+                        .fill(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryHeaderBackground))
                         .overlay(
                             RoundedRectangle(cornerRadius: RetroPauseChrome.radiusSM)
                                 .strokeBorder(RetroTheme.retroPink, lineWidth: 2)
                         )
                 )
                 .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
-                .foregroundColor(.white)
+                .foregroundStyle(Color(themeManager.currentPalette.gameLibraryText))
         }
     }

     // MARK: - Section Styles
     public struct RetroSectionStyle: ViewModifier {
+        @ObservedObject private var themeManager = ThemeManager.shared

         public init() {}

@@ -105,13 +107,13 @@ public struct RetroTheme {
                 .padding()
                 .background(
                     RoundedRectangle(cornerRadius: RetroPauseChrome.radiusMD)
-                        .fill(Color.black.opacity(0.6))
+                        .fill(Color(themeManager.currentPalette.settingsCellBackground ?? themeManager.currentPalette.gameLibraryHeaderBackground))
                         .overlay(
                             RoundedRectangle(cornerRadius: RetroPauseChrome.radiusMD)
                                 .strokeBorder(RetroTheme.retroGradient, lineWidth: 1)
                         )
                 )
-                .shadow(color: RetroTheme.retroPurple.opacity(0.3), radius: 10, x: 0, y: 5)
+                .shadow(color: RetroTheme.retroPurple.opacity(0.06), radius: 10, x: 0, y: 5)
         }
     }
diff --git a/PVUI/Sources/PVUIBase/SwiftUI/Components/RetroWave/RetroWaveColors.swift b/PVUI/Sources/PVUIBase/SwiftUI/Components/RetroWave/RetroWaveColors.swift
index a16a90af3a..097a97549c 100644
--- a/PVUI/Sources/PVUIBase/SwiftUI/Components/RetroWave/RetroWaveColors.swift
+++ b/PVUI/Sources/PVUIBase/SwiftUI/Components/RetroWave/RetroWaveColors.swift
@@ -6,22 +6,37 @@
 //

 import SwiftUI
+import UIKit
+import PVThemes

 // MARK: - Retrowave Design System

 // Retrowave color palette
 public extension Color {
-    public static let retroPink = Color(red: 0.98, green: 0.2, blue: 0.6)
-    public static let retroPurple = Color(red: 0.5, green: 0.0, blue: 0.8)
-    public static let retroBlue = Color(red: 0.0, green: 0.8, blue: 0.95)
-    public static let retroDarkBlue = Color(red: 0.05, green: 0.05, blue: 0.2)
+    /// Legacy accent names resolve through the active palette so shared controls follow paid themes.
+    public static var retroPink: Color { paletteColor { $0.defaultTintColor } }
+    public static var retroPurple: Color {
+        paletteColor { palette in
+            palette is RetroWaveThemePalette ? UIColor(red: 0.69, green: 0.55, blue: 0.91, alpha: 1) : palette.defaultTintColor
+        }
+    }
+    public static var retroBlue: Color {
+        paletteColor { palette in
+            palette is RetroWaveThemePalette ? UIColor(red: 0.40, green: 0.80, blue: 0.90, alpha: 1) : palette.defaultTintColor
+        }
+    }
+    public static var retroDarkBlue: Color { paletteColor { $0.gameLibraryCellBackground ?? $0.gameLibraryHeaderBackground } }
     public static let retroGreen = Color(red: 0.0, green: 0.95, blue: 0.8)
     public static let retroYellow = Color(red: 0.98, green: 0.84, blue: 0.2)
     public static let retroOrange = Color(red: 0.98, green: 0.5, blue: 0.2)
-    public static let retroBlack = Color(red: 0.05, green: 0.05, blue: 0.1)
+    public static var retroBlack: Color { paletteColor { $0.gameLibraryBackground } }
     public static let retroCyan = Color(red: 0.0, green: 0.95, blue: 0.95)
     public static let retroBlackClear = Color.black.opacity(0.001)

+    private static func paletteColor(_ color: @escaping @Sendable (any UXThemePalette) -> UIColor) -> Color {
+        Color(UIColor { _ in color(ThemeManager.shared.paletteForColorResolution) })
+    }
+
     // Gradient helpers
     public static let retroSunset = LinearGradient(
         gradient: Gradient(colors: [.retroYellow, .retroPink, .retroPurple]),
diff --git a/PVUI/Sources/PVUIBase/SwiftUI/GameItem/GameItemViewCell.swift b/PVUI/Sources/PVUIBase/SwiftUI/GameItem/GameItemViewCell.swift
index c5a17e1824..c70a1731ab 100644
--- a/PVUI/Sources/PVUIBase/SwiftUI/GameItem/GameItemViewCell.swift
+++ b/PVUI/Sources/PVUIBase/SwiftUI/GameItem/GameItemViewCell.swift
@@ -110,14 +110,7 @@ struct GameItemViewCell<Presentable: GameItemPresentable>: View, Equatable {
     }

     private var glowColor: Color {
-        switch themeManager.currentPalette {
-        case is DarkThemePalette:
-            return .cyan
-        case is LightThemePalette:
-            return .blue
-        default:
-            return .purple
-        }
+        Color(themeManager.currentPalette.defaultTintColor)
     }

     var body: some View {
@@ -291,7 +284,6 @@ struct GameItemViewCell<Presentable: GameItemPresentable>: View, Equatable {
                     }
                 }
                 .foregroundColor(textColor)
-                .shadow(color: glowColor, radius: 3, x: 0, y: 0)
                 .frame(maxWidth: textMaxWidth, alignment: .leading)
                 .padding(.bottom, -2) /// Negative padding to remove default spacing
             } else {
diff --git a/PVUI/Sources/PVUIBase/SwiftUI/GameItem/GameItemViewRow.swift b/PVUI/Sources/PVUIBase/SwiftUI/GameItem/GameItemViewRow.swift
index 8c95f60fb2..63e78ca1ed 100644
--- a/PVUI/Sources/PVUIBase/SwiftUI/GameItem/GameItemViewRow.swift
+++ b/PVUI/Sources/PVUIBase/SwiftUI/GameItem/GameItemViewRow.swift
@@ -146,7 +146,6 @@ struct GameItemViewRow<Presentable: GameItemPresentable>: SwiftUI.View, Equatabl
                                 speed: 50.0,
                                 loop: true)
                         .foregroundColor(textColor)
-                        .shadow(color: glowColor.opacity(0.7), radius: 2, x: 1, y: 1)
                         .frame(maxWidth: .infinity, alignment: .leading)

                     // Game metadata row
```

</details>
