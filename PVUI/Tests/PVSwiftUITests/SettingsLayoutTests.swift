import Testing
@testable import PVSwiftUI

/// Locks the Settings sidebar: pane order, display names, icons, which pane holds each section, and which
/// arrangement each container gets. Modelled on iFly's `SettingsTabLayoutTests`, so a reorg has to update
/// these deliberately.
@Suite("SettingsLayout")
struct SettingsLayoutTests {

    // MARK: Panes

    @Test("Pane order and display names")
    func paneOrderAndTitles() {
        #expect(SettingsPane.allCases.map(\.title) == [
            "General", "Library", "Emulation", "Audio & Video", "Controllers",
            "Touch Controls", "RetroAchievements", "Advanced", "About"
        ])
    }

    @Test("Pane icons")
    func paneIcons() {
        #expect(SettingsPane.allCases.map(\.icon) == [
            "gearshape.fill", "books.vertical.fill", "cpu", "tv.fill", "gamecontroller.fill",
            "hand.tap.fill", "trophy.fill", "wrench.and.screwdriver.fill", "info.circle.fill"
        ])
    }

    @Test("Every section title belongs to exactly one pane")
    func sectionsCoveredExactlyOnce() {
        let placed = SettingsPane.allCases.flatMap(\.sections)
        #expect(Set(placed) == SettingsSectionTitle.all)
        #expect(placed.count == SettingsSectionTitle.all.count, "a section is listed in two panes")
    }

    @Test("Every search entry opens a pane that lists its section")
    func searchEntriesResolveToPanes() {
        for entry in SettingsSearchIndex.entries {
            let pane = SettingsPane(section: entry.section)
            #expect(pane != nil, "\(entry.id) has no pane")
            #expect(pane?.sections.contains(entry.section) == true)
        }
    }

    @Test("Unknown section titles resolve to no pane")
    func unknownSection() {
        #expect(SettingsPane(section: "Nope") == nil)
        // The tvOS-only "About" title is not an iOS section.
        #expect(SettingsPane(section: SettingsSectionTitle.tvOSAbout) == nil)
    }

    @Test("Section placement for the panes that split the old tabs")
    func sectionPlacement() {
        #expect(SettingsPane(section: SettingsSectionTitle.retroAchievements) == .achievements)
        #expect(SettingsPane(section: SettingsSectionTitle.onScreenControls) == .touchControls)
        #expect(SettingsPane(section: SettingsSectionTitle.deltaSkins) == .touchControls)
        #expect(SettingsPane(section: SettingsSectionTitle.hapticsRumble) == .controllers)
        #expect(SettingsPane(section: SettingsSectionTitle.libraryManagement) == .library)
        #expect(SettingsPane(section: SettingsSectionTitle.video) == .audioVideo)
    }

    @Test("Legacy tab deep links open the pane holding that tab's first section")
    func legacyTabMapping() {
        #expect(SettingsPane(tab: .general) == .general)
        #expect(SettingsPane(tab: .emulation) == .emulation)
        #expect(SettingsPane(tab: .controller) == .controllers)
        #expect(SettingsPane(tab: .advanced) == .advanced)
        #expect(SettingsPane(tab: .about) == .about)
    }

    @Test("Search breadcrumbs name the pane, and drop the section when it repeats the pane")
    func breadcrumbs() {
        #expect(SettingsPane.breadcrumb(forSection: SettingsSectionTitle.hapticsRumble) == "Controllers › Haptics & Rumble")
        #expect(SettingsPane.breadcrumb(forSection: SettingsSectionTitle.advanced) == "Advanced")
        #expect(SettingsPane.breadcrumb(forSection: SettingsSectionTitle.retroAchievements) == "RetroAchievements")
        #expect(SettingsPane.breadcrumb(forSection: "Nope") == "Nope")
    }

    // MARK: Arrangement

    @Test("tvOS keeps its own layout at any width")
    func tvOSUnchanged() {
        for widthClass in [SettingsWidthClass.compact, .regular, .unknown] {
            #expect(SettingsLayoutRules.arrangement(platform: .tvOS, widthClass: widthClass, containerWidth: 1920) == .tvOSSections)
        }
    }

    @Test("Regular width gets the sidebar unless the container is too narrow for it")
    func regularWidth() {
        // iPad full screen, iPad page sheet, iPad form sheet.
        #expect(SettingsLayoutRules.arrangement(platform: .iOS, widthClass: .regular, containerWidth: 1180) == .sidebar)
        #expect(SettingsLayoutRules.arrangement(platform: .iOS, widthClass: .regular, containerWidth: 704) == .sidebar)
        #expect(SettingsLayoutRules.arrangement(platform: .iOS, widthClass: .regular, containerWidth: 540) == .tabStrip)
        #expect(SettingsLayoutRules.arrangement(
            platform: .iOS, widthClass: .regular, containerWidth: SettingsLayoutRules.regularSidebarMinimumWidth) == .sidebar)
    }

    @Test("Compact width gets the tab strip, except a landscape phone wide enough for the sidebar")
    func compactWidth() {
        // iPhone portrait, iPhone SE landscape, notched iPhone landscape (safe area excluded).
        #expect(SettingsLayoutRules.arrangement(platform: .iOS, widthClass: .compact, containerWidth: 393) == .tabStrip)
        #expect(SettingsLayoutRules.arrangement(platform: .iOS, widthClass: .compact, containerWidth: 667) == .tabStrip)
        #expect(SettingsLayoutRules.arrangement(platform: .iOS, widthClass: .compact, containerWidth: 750) == .sidebar)
        #expect(SettingsLayoutRules.arrangement(
            platform: .iOS, widthClass: .compact, containerWidth: SettingsLayoutRules.compactSidebarMinimumWidth) == .sidebar)
    }

    @Test("An unresolved size class never picks the sidebar")
    func unknownWidthClass() {
        #expect(SettingsLayoutRules.arrangement(platform: .iOS, widthClass: .unknown, containerWidth: 1366) == .tabStrip)
    }

    @Test("The sidebar always leaves room for the content column")
    func sidebarLeavesRoom() {
        #expect(SettingsLayoutRules.regularSidebarMinimumWidth - SettingsLayoutRules.sidebarWidth >= 360)
        #expect(SettingsLayoutRules.compactSidebarMinimumWidth >= SettingsLayoutRules.regularSidebarMinimumWidth)
    }
}
