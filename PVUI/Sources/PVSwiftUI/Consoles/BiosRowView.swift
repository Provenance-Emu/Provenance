//
//  BiosRowView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/28/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
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
                // BIOS status icon with retrowave glow
                Image(biosState?.biosStatusImageName ?? BIOSStatus.State.missing.biosStatusImageName, bundle: PVUIBase.BundleLoader.myBundle)
                    .resizable()
                    .scaledToFit()
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .shadow(color: getStatusColor().opacity(0.7), radius: 3)
                
                // BIOS information with retrowave styling
                VStack(alignment: .leading) {
                    Text("\(bios.descriptionText)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    
                    Text("\(bios.expectedMD5.uppercased()) : \(bios.expectedSize) bytes")
                        .font(.system(size: 10, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    themeManager.currentPalette.gameLibraryText.swiftUIColor ?? .white,
                                    RetroTheme.retroBlue.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                Spacer()
                HStack(alignment: .center, spacing: 4) {
                    switch biosState {
                    case .match:
                        // Retrowave-styled success indicator
                        Text("Installed")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .font(.system(size: 14, weight: .medium))
                            .shadow(color: RetroTheme.retroBlue.opacity(0.7), radius: 2)
                            
                    case .missing:
                        if bios.optional {
                            // Retrowave-styled optional indicator
                            Text("Optional")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.gray, Color.white.opacity(0.7)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.gray, Color.white.opacity(0.7)]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                            
                            Image(systemName: "info.circle")
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.gray, Color.white.opacity(0.7)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .font(.system(size: 14, weight: .medium))
                                .shadow(color: Color.gray.opacity(0.5), radius: 2)
                        } else {
                            // Retrowave-styled missing indicator
                            Text("Missing")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [RetroTheme.retroPink, Color.red]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [RetroTheme.retroPink, Color.red]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                            
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [RetroTheme.retroPink, Color.red]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .font(.system(size: 14, weight: .medium))
                                .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 2)
                        }
                    case .mismatch(_):
                        // Retrowave-styled mismatch indicator
                        Text("Mismatch")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.yellow, Color.orange]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.yellow, Color.orange]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.yellow, Color.orange]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .font(.system(size: 14, weight: .medium))
                            .shadow(color: Color.yellow.opacity(0.7), radius: 2)
                    case .none:
                        // Retrowave-styled loading indicator
                        Text("Loading...")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [RetroTheme.retroPink, Color.red]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Image(systemName: "hourglass")
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [RetroTheme.retroPink, Color.red]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .font(.system(size: 14, weight: .medium))
                            .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 2)
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
    
    // Helper function to get status color for glow effects
    private func getStatusColor() -> Color {
        switch biosState {
        case .match:
            return RetroTheme.retroBlue
        case .missing:
            return bios.optional ? Color.gray : RetroTheme.retroPink
        case .mismatch(_):
            return Color.yellow
        case .none:
            return RetroTheme.retroPink
        }
    }
}
