//
//  InSessionProfilePickerView.swift
//  PVUI
//
//  Created by Claude on 3/17/26.
//  Part of #705 — in-session controller profile swap
//

import SwiftUI
import GameController
import PVLibrary
import PVRealm
import PVLogging

// MARK: - InSessionProfilePickerView

/// A row of profiles grouped by controller, with a stable `Identifiable` ID
/// derived from the controller's `ObjectIdentifier` so ForEach diffing is reliable
/// even when `vendorName` is nil or shared across multiple controllers.
private struct ControllerEntry: Identifiable {
    let id: ObjectIdentifier
    let controller: GCController
    let profiles: [PVControllerProfile]

    init(controller: GCController, profiles: [PVControllerProfile]) {
        self.id = ObjectIdentifier(controller)
        self.controller = controller
        self.profiles = profiles
    }
}

/// Compact sheet shown from the tile-based pause menu that lets players switch
/// saved controller profiles without leaving the game.  Activating a profile
/// applies its button remappings immediately to the live in-memory controller.
struct InSessionProfilePickerView: View {

    // MARK: Inputs

    let emulatorVC: PVEmulatorViewController
    let onDismiss: () -> Void

    // MARK: State

    /// Per-controller profile lists with stable identifiers.
    @State private var entries: [ControllerEntry] = []
    @State private var errorMessage: String?
    @State private var showError = false

    // MARK: Body

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No Profiles",
                        systemImage: "gamecontroller",
                        description: Text("Save a profile in Settings › Controllers › Button Remapping to see it here.")
                    )
                } else {
                    List {
                        ForEach(entries) { entry in
                            Section(header: Text(entry.controller.vendorName ?? "Controller")) {
                                if entry.profiles.isEmpty {
                                    Text("No saved profiles.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(entry.profiles, id: \.id) { profile in
                                        profileRow(profile, controller: entry.controller)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Switch Profile")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                }
            }
            #endif
        }
        .onAppear(perform: loadEntries)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An error occurred.")
        }
    }

    // MARK: Row

    @ViewBuilder
    private func profileRow(_ profile: PVControllerProfile, controller: GCController) -> some View {
        Button(action: { apply(profile, to: controller) }) {
            HStack(spacing: 12) {
                Image(systemName: profile.isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(profile.isActive ? .accentColor : .secondary)
                    .imageScale(.large)

                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.name)
                        .foregroundColor(.primary)
                    Text("\(profile.mappings.count) mapping\(profile.mappings.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if profile.isActive {
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func loadEntries() {
        let db = RomDatabase.sharedInstance
        let controllers = PVControllerManager.shared.controllers
        entries = controllers.compactMap { controller in
            guard let vendorName = controller.vendorName else { return nil }
            let profiles = Array(db.controllerProfiles(forVendor: vendorName))
                .map { $0.isFrozen ? $0 : $0.freeze() }
            return ControllerEntry(controller: controller, profiles: profiles)
        }
    }

    @MainActor
    private func apply(_ profile: PVControllerProfile, to controller: GCController) {
        let db = RomDatabase.sharedInstance
        guard let live = db.controllerProfile(withID: profile.id) else {
            ELOG("InSessionProfilePicker: profile \(profile.id) not found in Realm")
            return
        }
        do {
            try db.activateControllerProfile(live)
            let wrapper = getRemappableControllerWrapper(for: controller)
            wrapper.apply(profile: live.freeze())
            ILOG("InSessionProfilePicker: applied profile '\(profile.name)' to \(controller.vendorName ?? "?")")
            loadEntries()
        } catch {
            ELOG("InSessionProfilePicker: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
