//
//  CoreSection.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import PVThemes
import PVLibrary

struct CoreSection: View {
    let core: PVCore
    let systems: [PVSystem]
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isExpanded = false

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text(core.projectName)
                        .font(.headline)
                    if !core.projectVersion.isEmpty {
                        Text("v\(core.projectVersion)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if core.disabled {
                        Text("Disabled")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // Project URL
                if !core.projectURL.isEmpty {
                    Link(destination: URL(string: core.projectURL)!) {
                        HStack {
                            Image(systemName: "link")
                            Text("Project Website")
                        }
                        .foregroundColor(themeManager.currentPalette.settingsCellText?.swiftUIColor ?? .secondary)
                    }
                }

                // Systems
                if !systems.isEmpty {
                    #if !os(tvOS)
                    DisclosureGroup(isExpanded: $isExpanded) {
                        ForEach(systems.sorted(by: { $0.name < $1.name }), id: \.self) { system in
                            Text("• \(system.name)")
                                .padding(.leading, 4)
                                .padding(.vertical, 2)
                        }
                    } label: {
                        Text("Supported Systems (\(systems.count))")
                    }
                    #else
                    List {
                        ForEach(systems.sorted(by: { $0.name < $1.name }), id: \.self) { system in
                            Text("• \(system.name)")
                                .padding(.leading, 4)
                                .padding(.vertical, 2)
                        }
                    }
                    #endif
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(core.disabled ? Color.gray.opacity(0.1) : Color.clear)
    }
}
