//
//  ControllerProfilesView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/2/2026.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import SwiftUI
import GameController
import PVLibrary
import PVRealm
import PVLogging
import PVThemes

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

    @State private var profiles: [PVControllerProfile] = []
    @State private var showNewProfileAlert = false
    @State private var newProfileName = ""
    @State private var profileToRename: PVControllerProfile?
    @State private var renameText = ""
    @State private var showRenameAlert = false
    @State private var errorMessage: String?
    @State private var showError = false

    // MARK: - Theme

    @ObservedObject private var themeManager = ThemeManager.shared

    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor ?? .accentColor
    }

    // MARK: - Body

    var body: some View {
        List {
            if profiles.isEmpty {
                Section {
                    Text("No saved profiles yet. Use the button below to save your current button mappings as a named profile.")
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
        .navigationTitle(controller.vendorName ?? "Controller Profiles")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
    }

    // MARK: - Row

    @ViewBuilder
    private func profileRow(_ profile: PVControllerProfile) -> some View {
        Button(action: { toggleActive(profile) }) {
            HStack(spacing: 12) {
                // Active indicator
                Image(systemName: profile.isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(profile.isActive ? accentColor : .secondary)
                    .imageScale(.large)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(scopeLabel(for: profile))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(profile.mappings.count) mapping\(profile.mappings.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Last modified
                Text(profile.lastModifiedDate, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button("Rename") { startRename(profile) }
                .tint(accentColor)
        }
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
            // Work with the live (unfrozen) object from Realm.
            guard let live = db.realm.object(ofType: PVControllerProfile.self, forPrimaryKey: profile.id) else {
                return
            }
            if live.isActive {
                try db.deactivateControllerProfile(live)
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

    private func deleteProfiles(at offsets: IndexSet) {
        let db = RomDatabase.sharedInstance
        for index in offsets {
            let frozen = profiles[index]
            guard let live = db.realm.object(ofType: PVControllerProfile.self, forPrimaryKey: frozen.id) else {
                continue
            }
            do {
                try db.deleteControllerProfile(live)
            } catch {
                showProfileError(error)
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
        guard let live = db.realm.object(ofType: PVControllerProfile.self, forPrimaryKey: frozen.id) else {
            return
        }
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
        NavigationView {
            Text("No controller available in preview")
                .navigationTitle("Controller Profiles")
        }
    }
}
#endif
