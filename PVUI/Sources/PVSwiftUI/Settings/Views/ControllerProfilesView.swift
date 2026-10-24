//
//  ControllerProfilesView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/2/2026.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import SwiftUI
import GameController
import PVCoreBridge
import PVLibrary
import PVRealm
import PVLogging
import PVThemes
import PVUIBase

/// Manages controller mapping profiles for a given `GCController`.
///
/// Displays all persisted `PVControllerProfile` objects scoped to this controller
/// and lets the user activate, rename, or delete them.  A floating action button
/// lets the user save the controller's *current* in-memory mappings as a new named
/// profile.
struct ControllerProfilesView: View {

    // MARK: - Inputs

    let controller: GCController

    // MARK: - State

    // Frozen Realm objects are safe to store in @State; mutation goes through RomDatabase helpers.
    @State private var profiles: [PVControllerProfile] = []
    @State private var showNewProfileAlert = false
    @State private var newProfileName = ""
    /// Frozen `PVControllerProfile` staged for rename. Must be frozen (see `reloadProfiles`) so it
    /// is safe to hold across async boundaries and in SwiftUI `@State`. The live object is
    /// re-fetched via `db.controllerProfile(withID:)` before any write in `commitRename`.
    @State private var profileToRename: PVControllerProfile?
    @State private var renameText = ""
    @State private var showRenameAlert = false
    @State private var errorMessage: String?
    @State private var showError = false

    // MARK: - Theme

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared

    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor ?? .accentColor
    }

    /// DualSense / DualShock 4 expose `light`; other pads do not.
    private var controllerSupportsLightBar: Bool {
        controller.light != nil
    }

    // MARK: - Body

    var body: some View {
        content
            .navigationTitle(controller.vendorName ?? "Controller Profiles")
            #if os(tvOS)
            .onExitCommand { dismiss() }
            #else
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            #endif
            .onAppear(perform: reloadProfiles)
            .alert("New Profile", isPresented: $showNewProfileAlert) {
                TextField("Profile name", text: $newProfileName)
                Button("Save", action: saveNewProfile)
                Button("Cancel", role: .cancel) { newProfileName = "" }
            } message: {
                Text("Enter a name for this button mapping profile.")
            }
            .alert("Rename Profile", isPresented: $showRenameAlert) {
                TextField("Profile name", text: $renameText)
                Button("Rename", action: commitRename)
                Button("Cancel", role: .cancel) { profileToRename = nil }
            } message: {
                Text("Enter a new name.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
            .settingsSubpageTracking()
    }

    // MARK: - Content

    private var emptyStateText: some View {
        Text("No saved profiles yet. Use the button below to save your current button mappings as a named profile.")
    }

    #if os(tvOS)
    private var content: some View {
        ZStack {
            RetroSettingsBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if profiles.isEmpty {
                        emptyStateText
                            .font(.retroSettingsRowSubtitle)
                            .foregroundColor(.secondary)
                    } else {
                        RetroSettingsSectionHeader(icon: "person.crop.rectangle.stack", title: "Saved Profiles")

                        ForEach(profiles, id: \.id) { profile in
                            profileRow(profile)
                        }

                        Text("Select a profile to activate it. Only one profile can be active per scope.")
                            .font(.retroSettingsRowSubtitle)
                            .foregroundColor(.secondary)
                    }

                    RetroSettingsDivider()

                    RetroSettingsActionButton(
                        title: "Save Current Mappings as Profile\u{2026}",
                        icon: "plus.circle",
                        color: accentColor
                    ) {
                        showNewProfileAlert = true
                    }
                }
                .tvOSSettingsHorizontalPadding()
                .padding(.vertical, 24)
            }
        }
        .focusSection()
    }
    #else
    private var content: some View {
        List {
            if profiles.isEmpty {
                Section {
                    emptyStateText
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
            } else {
                Section {
                    ForEach(profiles, id: \.id) { profile in
                        profileRow(profile)
                    }
                    .onDelete(perform: deleteProfiles)
                } header: {
                    Text("Saved Profiles")
                } footer: {
                    Text("Tap a profile to activate it. Only one profile can be active per scope. Swipe left to delete.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button(action: { showNewProfileAlert = true }) {
                    Label("Save Current Mappings as Profile\u{2026}", systemImage: "plus.circle")
                        .foregroundColor(accentColor)
                }
            }
        }
    }
    #endif

    // MARK: - Row

    private var primaryTextColor: Color {
        #if os(tvOS)
        themeManager.currentPalette.settingsCellText?.swiftUIColor
            ?? themeManager.currentPalette.gameLibraryText.swiftUIColor
        #else
        .primary
        #endif
    }

    private var rowTitleFont: Font {
        #if os(tvOS)
        .retroSettingsRowTitle
        #else
        .body
        #endif
    }

    private var rowDetailFont: Font {
        #if os(tvOS)
        .retroSettingsRowSubtitle
        #else
        .caption
        #endif
    }

    private var rowMetaFont: Font {
        #if os(tvOS)
        .retroSettingsRowSubtitle
        #else
        .caption2
        #endif
    }

    @ViewBuilder
    private func profileRow(_ profile: PVControllerProfile) -> some View {
        HStack(spacing: 12) {
            Button(action: { toggleActive(profile) }) {
                HStack(spacing: 12) {
                    Image(systemName: profile.isActive ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(profile.isActive ? accentColor : .secondary)
                        .imageScale(.large)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(rowTitleFont)
                            .foregroundColor(primaryTextColor)

                        Text(scopeLabel(for: profile))
                            .font(rowDetailFont)
                            .foregroundColor(.secondary)

                        Text("\(profile.mappings.count) mapping\(profile.mappings.count == 1 ? "" : "s")")
                            .font(rowMetaFont)
                            .foregroundColor(.secondary)

                        if let hex = profile.lightBarColorHex?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty {
                            Text("Light: \(hex)")
                                .font(rowMetaFont)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer(minLength: 8)

                    Text(profile.lastModifiedDate, style: .relative)
                        .font(rowMetaFont)
                        .foregroundColor(.secondary)
                }
                .tvOSRowInset()
                .contentShape(Rectangle())
            }
            .retroFocusButtonStyle(focusScale: 1.03, focusBorderWidth: 2.5, cornerRadius: 12)
            #if os(tvOS)
            .contextMenu {
                Button("Rename") { startRename(profile) }
                Button("Delete", role: .destructive) { delete(profile) }
            }
            #endif

            if controllerSupportsLightBar {
                NavigationLink {
                    ControllerProfileLightBarEditorView(controller: controller, profileID: profile.id, onSaved: reloadProfiles)
                } label: {
                    Image(systemName: "light.max")
                        .foregroundColor(accentColor)
                        .accessibilityLabel(String(localized: "Light bar color"))
                        .tvOSRowInset()
                }
                .retroFocusButtonStyle(focusScale: 1.08, focusBorderWidth: 2.5, cornerRadius: 12)
            }
        }
        #if os(tvOS)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
        #else
        .swipeActions(edge: .leading) {
            Button("Rename") { startRename(profile) }
                .tint(accentColor)
        }
        #endif
    }

    // MARK: - Helpers

    private func scopeLabel(for profile: PVControllerProfile) -> String {
        if let gameID = profile.gameID, !gameID.isEmpty {
            return "Game-specific"
        }
        if let systemID = profile.systemIdentifier, !systemID.isEmpty {
            return "System: \(systemID)"
        }
        return "Global (all systems)"
    }

    // MARK: - Actions

    private func reloadProfiles() {
        guard let vendorName = controller.vendorName else { return }
        let db = RomDatabase.sharedInstance
        // Snapshot to plain array so SwiftUI owns the data lifecycle.
        profiles = Array(db.controllerProfiles(forVendor: vendorName))
            .map { $0.isFrozen ? $0 : $0.freeze() }
    }

    private func toggleActive(_ profile: PVControllerProfile) {
        let db = RomDatabase.sharedInstance
        do {
            // Resolve the live (unfrozen) object via the RomDatabase helper.
            guard let live = db.controllerProfile(withID: profile.id) else { return }
            if live.isActive {
                try db.deactivateControllerProfile(live)
                if #available(iOS 14.0, tvOS 14.0, *) {
                    ControllerLightBarManager.shared.setProfileLightBarOverride(controller: controller, hex: nil)
                }
            } else {
                try db.activateControllerProfile(live)
                // Apply to in-memory controller immediately.
                let wrapper = getRemappableControllerWrapper(for: controller)
                wrapper.apply(profile: live.freeze())
            }
            reloadProfiles()
        } catch {
            showProfileError(error)
        }
    }

    #if os(tvOS)
    private func delete(_ profile: PVControllerProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        deleteProfiles(at: IndexSet(integer: index))
    }
    #endif

    private func deleteProfiles(at offsets: IndexSet) {
        let db = RomDatabase.sharedInstance
        var clearedLightBarOverride = false
        for index in offsets {
            guard let live = db.controllerProfile(withID: profiles[index].id) else { continue }
            let wasActive = live.isActive
            do {
                try db.deleteControllerProfile(live)
                if wasActive { clearedLightBarOverride = true }
            } catch {
                showProfileError(error)
            }
        }
        if clearedLightBarOverride {
            if #available(iOS 14.0, tvOS 14.0, *) {
                ControllerLightBarManager.shared.setProfileLightBarOverride(controller: controller, hex: nil)
            }
        }
        reloadProfiles()
    }

    private func saveNewProfile() {
        let name = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        newProfileName = ""
        guard !name.isEmpty else { return }

        let wrapper = getRemappableControllerWrapper(for: controller)
        if wrapper.saveCurrentMappingsAsProfile(name: name, makeActive: true) != nil {
            reloadProfiles()
        } else {
            errorMessage = "No button mappings are currently configured. Remap at least one button before saving a profile."
            showError = true
        }
    }

    private func startRename(_ profile: PVControllerProfile) {
        profileToRename = profile
        renameText = profile.name
        showRenameAlert = true
    }

    private func commitRename() {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        renameText = ""
        guard !name.isEmpty, let frozen = profileToRename else {
            profileToRename = nil
            return
        }
        profileToRename = nil
        let db = RomDatabase.sharedInstance
        guard let live = db.controllerProfile(withID: frozen.id) else { return }
        do {
            try db.renameControllerProfile(live, to: name)
            reloadProfiles()
        } catch {
            showProfileError(error)
        }
    }

    private func showProfileError(_ error: Error) {
        ELOG("ControllerProfilesView: \(error)")
        errorMessage = error.localizedDescription
        showError = true
    }
}

#if DEBUG
struct ControllerProfilesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            Text("No controller available in preview")
                .navigationTitle("Controller Profiles")
        }
    }
}
#endif
