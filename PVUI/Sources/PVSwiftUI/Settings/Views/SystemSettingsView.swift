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
import PVThemes

struct SystemSettingsView: View {
    @ObservedResults(PVSystem.self) private var systems
    @State private var searchText = ""
    @Default(.unsupportedCores) private var unsupportedCores

    var isAppStore: Bool = {
        AppState.shared.isAppStore
    }()
    
    var filteredSystems: [PVSystem] {
        if searchText.isEmpty {
            return systems
                .filter { system in
                    !system.cores.isEmpty && !(isAppStore && system.appStoreDisabled && !Defaults[.unsupportedCores])
                }
                .sorted(by: { $0.identifier < $1.identifier })
        }
        return systems.filter { system in
            !system.cores.isEmpty &&
            !(isAppStore && system.appStoreDisabled && !Defaults[.unsupportedCores]) &&
            system.name.localizedCaseInsensitiveContains(searchText) ||
            system.manufacturer.localizedCaseInsensitiveContains(searchText) ||
            system.cores.contains { core in
                core.projectName.localizedCaseInsensitiveContains(searchText)
            } ||
            (system.BIOSes?.contains { bios in
                bios.descriptionText.localizedCaseInsensitiveContains(searchText)
            } ?? false)

            // Only show systems with no cores if unsupportedCores is true
            return (unsupportedCores ? hasValidCores : (hasValidCores && system.cores.count > 0)) && meetsSearchCriteria
        }
        .sorted(by: { $0.identifier < $1.identifier })
    }

    var body: some View {
        #if os(tvOS)
        VStack {
            // Search field at the top
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search systems, cores, or BIOSes", text: $searchText)
                    .padding(8)
//                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .padding()

            // Scrollable list
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(filteredSystems) { system in
                        SystemSection(system: system)
                            .focusable(true)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Systems")
        #else
        List {
            ForEach(filteredSystems) { system in
                SystemSection(system: system)
            }
        }
        .searchable(text: $searchText, prompt: "Search systems, cores, or BIOSes")
        .listStyle(GroupedListStyle())
        .navigationTitle("Systems")
        #endif
    }
}

struct SystemSection: View {
    let system: PVSystem
    @ObservedResults(PVCore.self) private var cores
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        Section {
            // Games count
            SettingsRow(title: "Games",
                       value: "\(system.games.count)")

            // Cores
            Text("Cores")
                .font(.headline)
            #if !os(tvOS)
                .listRowBackground(Color(.systemBackground.withAlphaComponent(0.9)))
            #endif

            ForEach(system.cores.filter { core in
                !(AppState.shared.isAppStore && core.appStoreDisabled && !Defaults[.unsupportedCores])
            }, id: \.identifier) { core in
                Text(core.projectName)
                    .padding(.leading)
                }

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
        } header: {
            HStack {
                Image(system.iconName, bundle: PVUIBase.BundleLoader.myBundle)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .tint(themeManager.currentPalette.menuHeaderText.swiftUIColor)
                    .foregroundColor(themeManager.currentPalette.menuHeaderText.swiftUIColor)

                Text(system.name)
                    .font(.title2.bold())
                    .foregroundColor(themeManager.currentPalette.menuHeaderText.swiftUIColor)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            // .background(themeManager.currentPalette.menuHeaderBackground.swiftUIColor)
        }
    }
}

struct BIOSRow: View {
    let bios: PVBIOS
    @State private var biosStatus: BIOSStatus?
    @State private var showCopiedAlert = false

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator circle
            Circle()
                .fill(statusColor(for: biosStatus))
                .frame(width: 12, height: 12)

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
        .padding(.leading, 4) // Add padding for the circle
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

    private func statusColor(for status: BIOSStatus?) -> Color {
        guard let status = status else { return .gray }

        switch status.state {
        case .match:
            return .green
        case .missing:
            return status.required ? .red : .yellow
        case .mismatch:
            return .orange
        }
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
}
