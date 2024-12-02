//
//  SystemSettingsView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import PVLibrary
import Combine
import RealmSwift
import PVPrimitives

struct SystemSettingsView: View {
    @ObservedResults(PVSystem.self) private var systems
//    private let systems: [PVSystem] = PVEmulatorConfiguration.systems
    @State private var searchText = ""
    var isAppStore: Bool = {
        AppState.shared.isAppStore
    }()
    
    var filteredSystems: [PVSystem] {
        if searchText.isEmpty {
            return systems
                .filter { system in
                    !system.cores.isEmpty && !(isAppStore && system.appStoreDisabled)
                }
                .sorted(by: { $0.identifier < $1.identifier })
        }
        return systems.filter { system in
            !system.cores.isEmpty &&
            !(isAppStore && system.appStoreDisabled) &&
            system.name.localizedCaseInsensitiveContains(searchText) ||
            system.manufacturer.localizedCaseInsensitiveContains(searchText) ||
            system.cores.contains { core in
                core.projectName.localizedCaseInsensitiveContains(searchText)
            } ||
            (system.BIOSes?.contains { bios in
                bios.descriptionText.localizedCaseInsensitiveContains(searchText)
            } ?? false)
        }
        .sorted(by: { $0.identifier < $1.identifier })
    }

    var body: some View {
        List {
            ForEach(filteredSystems) { system in
                SystemSection(system: system)
            }
        }
        .searchable(text: $searchText, prompt: "Search systems, cores, or BIOSes")
        .listStyle(GroupedListStyle())
        .navigationTitle("Systems")
    }
}

struct SystemSection: View {
    let system: PVSystem
    @ObservedResults(PVCore.self) private var cores

    var body: some View {
        Section(header: Text(system.name)) {
            // Games count
            SettingsRow(title: "Games",
                       value: "\(system.games.count)")

            // Cores
            SettingsRow(title: "Cores",
                       value: system.cores.map { $0.projectName }.joined(separator: ", "))

            // BIOSes
            if let bioses = system.BIOSes, !bioses.isEmpty {
                Text("BIOSES")
                    .font(.headline)
                #if !os(tvOS)
                    .listRowBackground(Color(.systemBackground.withAlphaComponent(0.9)))
                #endif
                ForEach(bioses) { bios in
                    BIOSRow(bios: bios)
                }
            }
        }
    }
}

struct BIOSRow: View {
    let bios: PVBIOS
    @State private var biosStatus: BIOSStatus?
    @State private var showCopiedAlert = false

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(bios.descriptionText)
                Text("\(bios.expectedMD5.uppercased()) : \(bios.expectedSize) bytes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let status = biosStatus {
                statusIndicator(for: status)
            }
        }
        .listRowBackground(backgroundColor(for: biosStatus))
        .contentShape(Rectangle()) // Makes entire row tappable
#if !os(tvOS)
        .onTapGesture {
            if case .match = biosStatus?.state {
                return // Don't do anything for matched BIOSes
            }
            UIPasteboard.general.string = bios.expectedMD5.uppercased()
            showCopiedAlert = true
        }
#endif
        .task {
            biosStatus = await (bios as BIOSStatusProvider).status
        }
        .uiKitAlert("MD5 Copied",
                    message: "The MD5 for \(bios.expectedFilename) has been copied to the pasteboard",
                    isPresented: $showCopiedAlert,
                    buttons: {
            UIAlertAction(title: "OK", style: .default, handler: {
                _ in
                showCopiedAlert = false
            })
        })
    }

    @ViewBuilder
    private func statusIndicator(for status: BIOSStatus) -> some View {
        switch status.state {
        case .match:
            Image(systemName: "checkmark")
        case .missing:
            EmptyView()
        case let .mismatch(mismatches):
            Text(mismatches.map { $0.description }.joined(separator: ", "))
                .font(.caption)
                .foregroundColor(.red)
        }
    }

    private func backgroundColor(for status: BIOSStatus?) -> Color {
        guard let status = status else { return .clear }

        switch status.state {
        case .match:
            return .clear
        case .missing:
            return Color(status.required ? UIColor.systemRed : UIColor.systemYellow)
        case .mismatch:
            return Color(UIColor.systemOrange)
        }
    }
}
