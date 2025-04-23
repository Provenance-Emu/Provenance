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
    @State private var isHovered = false

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                // Header with retrowave styling
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(core.projectName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroPink, .retroPurple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        if !core.projectVersion.isEmpty {
                            Text("v\(core.projectVersion)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.retroBlue)
                        }
                    }
                    
                    Spacer()
                    
                    if core.disabled {
                        Text("DISABLED")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.black.opacity(0.6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .strokeBorder(Color.red, lineWidth: 1)
                                    )
                            )
                            .foregroundColor(.red)
                    }
                }

                // Project URL with retrowave styling
                if !core.projectURL.isEmpty {
                    Link(destination: URL(string: core.projectURL)!) {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Project Website")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                }

                // Systems with retrowave styling
                if !systems.isEmpty {
                    #if !os(tvOS)
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: { withAnimation { isExpanded.toggle() } }) {
                            HStack {
                                Text("Supported Systems (\(systems.count))")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
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
                        
                        if isExpanded {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(systems.sorted(by: { $0.name < $1.name }), id: \.self) { system in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color.retroPink.opacity(0.7))
                                            .frame(width: 6, height: 6)
                                        
                                        Text(system.name)
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
                    #else
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Supported Systems")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.bottom, 4)
                        
                        ForEach(systems.sorted(by: { $0.name < $1.name }), id: \.self) { system in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.retroPink.opacity(0.7))
                                    .frame(width: 6, height: 6)
                                
                                Text(system.name)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(.leading, 12)
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(6)
                    #endif
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
                                    gradient: Gradient(colors: core.disabled ? 
                                                     [.gray.opacity(0.3), .gray.opacity(0.5)] : 
                                                     [.retroPink.opacity(0.5), .retroBlue.opacity(0.5)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: core.disabled ? .black.opacity(0.1) : .retroPink.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}
