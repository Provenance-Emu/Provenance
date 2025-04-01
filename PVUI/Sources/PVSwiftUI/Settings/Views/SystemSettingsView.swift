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
        let filteredSystems = systems.filter { system in
            // Filter cores for this system
            let validCores = system.cores.filter { core in
                // Keep core if:
                // 1. It's not disabled, OR unsupportedCores is true
                // 2. AND (It's not app store disabled, OR we're not in the app store, OR unsupportedCores is true)
                (!core.disabled || unsupportedCores) &&
                (!core.appStoreDisabled || !isAppStore || unsupportedCores)
            }
            
            // System is valid if:
            // 1. It has valid cores (or unsupportedCores is true)
            // 2. AND (It's not app store disabled, OR we're not in the app store, OR unsupportedCores is true)
            let hasValidCores = !validCores.isEmpty || unsupportedCores
            let isSystemValid = hasValidCores && (!system.appStoreDisabled || !isAppStore || unsupportedCores)
            
            if searchText.isEmpty {
                return isSystemValid
            } else {
                // Additional search criteria
                let meetsSearchCriteria = system.name.localizedCaseInsensitiveContains(searchText) ||
                system.manufacturer.localizedCaseInsensitiveContains(searchText) ||
                system.cores.contains { core in
                    core.projectName.localizedCaseInsensitiveContains(searchText)
                } ||
                (system.BIOSes?.contains { bios in
                    bios.descriptionText.localizedCaseInsensitiveContains(searchText)
                } ?? false)
                
                return isSystemValid && meetsSearchCriteria
            }
        }
        
        return filteredSystems.sorted(by: { $0.identifier < $1.identifier })
    }
    
    
    var body: some View {
#if os(tvOS)
        ZStack {
            // Retrowave background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Grid background
            RetroGrid()
                .edgesIgnoringSafeArea(.all)
                .opacity(0.3)
            
            VStack {
                // Search field with retrowave styling
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    TextField("Search systems, cores, or BIOSes", text: $searchText)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                        )
                }
                .padding()
                
                // Title with retrowave styling
                Text("SYSTEMS")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.bottom, 20)
                    .shadow(color: .retroPink.opacity(0.5), radius: 10, x: 0, y: 0)
                
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
        }
#else
        ZStack {
            // Retrowave background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Grid background
            RetroGrid()
                .edgesIgnoringSafeArea(.all)
                .opacity(0.3)
            
            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    // Title with retrowave styling
                    Text("SYSTEMS")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        .shadow(color: .retroPink.opacity(0.5), radius: 10, x: 0, y: 0)
                    
                    // Search field with retrowave styling
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroPink, .retroPurple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        TextField("Search systems, cores, or BIOSes", text: $searchText)
                            .foregroundColor(.white)
                            .padding(10)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // Systems list
                    VStack(spacing: 16) {
                        ForEach(filteredSystems) { system in
                            SystemSection(system: system)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
#endif
    }
}

struct SystemSection: View {
    let system: PVSystem
    @ObservedResults(PVCore.self) private var cores
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isCoresExpanded = false
    @State private var isBiosesExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with system icon and name
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: .retroPink.opacity(0.3), radius: 5)
                    
                    Image(system.iconName, bundle: PVUIBase.BundleLoader.myBundle)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.white, .retroBlue.opacity(0.8)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(system.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    // Games count with retrowave styling
                    HStack(spacing: 6) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.retroBlue)
                        
                        Text("\(system.games.count) Games")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            
            // Cores section with retrowave styling
            VStack(alignment: .leading, spacing: 8) {
                Button(action: { withAnimation { isCoresExpanded.toggle() } }) {
                    HStack {
                        Text("CORES")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Spacer()
                        
                        Image(systemName: isCoresExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroBlue, .retroPink]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .font(.system(size: 12))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.4))
                    )
                }
                
                if isCoresExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(system.cores.filter { core in
                            !(AppState.shared.isAppStore && core.appStoreDisabled)
                        }, id: \.identifier) { core in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.retroBlue.opacity(0.7))
                                    .frame(width: 6, height: 6)
                                
                                Text(core.projectName)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(.leading, 12)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(6)
                    .transition(.opacity)
                }
            }
            
            // BIOSes section with retrowave styling
            if let bioses = system.BIOSes, !bioses.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: { withAnimation { isBiosesExpanded.toggle() } }) {
                        HStack {
                            Text("BIOSES")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Spacer()
                            
                            Image(systemName: isBiosesExpanded ? "chevron.up" : "chevron.down")
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.retroBlue, .retroPink]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .font(.system(size: 12))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.4))
                        )
                    }
                    
                    if isBiosesExpanded {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(bioses) { bios in
                                BIOSRow(bios: bios)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(6)
                        .transition(.opacity)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink.opacity(0.5), .retroBlue.opacity(0.5)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .retroPink.opacity(0.2), radius: 8, x: 0, y: 4)
        // .background(themeManager.currentPalette.menuHeaderBackground.swiftUIColor)
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
            biosStatus = (bios as BIOSStatusProvider).status
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
