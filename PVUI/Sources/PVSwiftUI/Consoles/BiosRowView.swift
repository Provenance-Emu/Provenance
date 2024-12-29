//
//  BiosRowView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/28/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import PVPrimitives
import PVThemes
import PVRealm
import PVUIBase

extension BIOSStatus.State {
    var biosStatusImageName: String {
        switch self {
        case .missing: return "bios_empty"
        case .mismatch:  return "bios_empty"
        case .match: return "bios_filled"
        }
    }
}

struct BiosRowView: SwiftUI.View {
    /// Primary key of the BIOS
    let biosFilename: String

    /// Observed BIOS object fetched from Realm
    @ObservedRealmObject private var bios: PVBIOS

    @MainActor
    @State private var biosState: BIOSStatus.State? = nil
    @State private var showMD5Alert = false
    @ObservedObject private var themeManager = ThemeManager.shared

    /// Computed property to get the current BIOS state
    private var currentBiosState: BIOSStatus.State {
        (bios as BIOSStatusProvider).status.state
    }

    init?(biosFilename: String) {
        self.biosFilename = biosFilename
        let config = Realm.Configuration.defaultConfiguration
        guard let realm = try? Realm(configuration: config),
              let bios = realm.object(ofType: PVBIOS.self, forPrimaryKey: biosFilename) else {
            return nil
        }
        _bios = ObservedRealmObject(wrappedValue: bios)

    }

    /// Action to copy MD5 to clipboard
    private func copyMD5() {
        #if !os(tvOS)
        UIPasteboard.general.string = bios.expectedMD5
        showMD5Alert = true
        #endif
    }

    /// Action to delete BIOS
    private func deleteBIOS() {
        do {
            try RomDatabase.sharedInstance.delete(bios: bios)
            // Update the biosState after deletion
            Task { @MainActor in
                let biosStatus = (bios as BIOSStatusProvider).status
                self.biosState = biosStatus.state
            }
        } catch {
            ELOG("Failed to delete BIOS: \(error.localizedDescription)")
        }
    }

    var body: some SwiftUI.View {
        Group {
            HStack(alignment: .center, spacing: 0) {
                Image(biosState?.biosStatusImageName ?? BIOSStatus.State.missing.biosStatusImageName, bundle: PVUIBase.BundleLoader.myBundle).resizable().scaledToFit()
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                VStack(alignment: .leading) {
                    Text("\(bios.descriptionText)")
                        .font(.footnote)
                        .foregroundColor(themeManager.currentPalette.settingsCellTextDetail?.swiftUIColor)
                    Text("\(bios.expectedMD5.uppercased()) : \(bios.expectedSize) bytes")
                        .font(.caption2)
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                }
                Spacer()
                HStack(alignment: .center, spacing: 4) {
                    switch biosState {
                    case .match:
                        Image(systemName: "checkmark")
                            .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                            .font(.footnote.weight(.light))
                    case .missing:
                        if bios.optional {
                            Text("Optional")
                                .font(.caption)
                                .foregroundColor(Color.gray)
                            Image(systemName: "info.circle")
                                .foregroundColor(Color.gray)
                                .font(.caption.weight(.light))
                        } else {
                            Text("Missing")
                                .font(.caption)
                                .foregroundColor(Color.red)
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color.red)
                                .font(.caption.weight(.light))
                        }
                    case .mismatch(_):
                        Text("Mismatch")
                            .font(.caption)
                            .foregroundColor(Color.yellow)
                            .border(Color.yellow)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color.yellow)
                            .font(.caption.weight(.medium))
                    case .none:
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(Color.red)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color.red)
                            .font(.caption.weight(.medium))
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 40)
            .onAppear { @MainActor in
                // Update biosState whenever the view appears or bios changes
                biosState = currentBiosState
            }
            .task { @MainActor in
                // Update biosState whenever the view appears or bios changes
                biosState = currentBiosState
            }
            .onChange(of: bios.file) { _ in
                // Update biosState whenever the file property changes
                biosState = currentBiosState
            }
#if !os(tvOS)
//            .onTapGesture {
//                if case .missing = biosState {
//                    copyMD5()
//                }
//            }
            .contextMenu {
                Button(action: copyMD5) {
                    Label("Copy MD5", systemImage: "doc.on.doc")
                }

                if bios.file != nil {
                    Button(role: .destructive, action: deleteBIOS) {
                        Label("Delete BIOS", systemImage: "trash")
                    }
                }
            }
            #else
            .contextMenu {
                if bios.file != nil {
                    Button(role: .destructive, action: deleteBIOS) {
                        Label("Delete BIOS", systemImage: "trash")
                    }
                }
            }
#endif
            .uiKitAlert("MD5 Copied",
                        message: "The MD5 for \(bios.expectedFilename) has been copied to the pasteboard",
                        isPresented: $showMD5Alert,
                        buttons: {
                UIAlertAction(title: "OK", style: .default, handler: { _ in
                    showMD5Alert = false
                })
            })
        }
    }
}
#endif
