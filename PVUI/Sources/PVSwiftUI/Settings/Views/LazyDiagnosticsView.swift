//
//  LazyDiagnosticsView.swift
//  PVSwiftUI
//
//  Created by Joseph Mattiello on 4/27/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVUIBase
import PVLogging

/// A view that displays diagnostics information with lazy loading
public struct LazyDiagnosticsView: View {
    /// The view model
    @ObservedObject var viewModel: UnifiedCloudSyncViewModel
    
    /// Whether the view is expanded
    @State private var isExpanded = false
    
    /// Whether reduced motion is enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with expand/collapse button
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
#if !os(tvOS)
                HapticFeedbackService.shared.playSelection()
                #endif
            }) {
                HStack {
                    Text("Diagnostics")
                        .retroSectionHeader()
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.retroPink)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                // Container info
                diagnosticSection(title: "iCloud Container", content: viewModel.containerInfo)
                
                // Entitlement info
                diagnosticSection(title: "Entitlements", content: viewModel.entitlementInfo)
                
                // Info.plist info
                diagnosticSection(title: "Info.plist", content: viewModel.infoPlistInfo)
                
                // Refresh info
                diagnosticSection(title: "Refresh Status", content: viewModel.refreshInfo)
                
                // Actions
                HStack {
                    Button(action: {
                        // Copy all diagnostics to clipboard
                        let allDiagnostics = """
                        === CONTAINER INFO ===
                        \(viewModel.containerInfo)
                        
                        === ENTITLEMENTS ===
                        \(viewModel.entitlementInfo)
                        
                        === INFO.PLIST ===
                        \(viewModel.infoPlistInfo)
                        
                        === REFRESH STATUS ===
                        \(viewModel.refreshInfo)
                        """
                        
#if !os(tvOS)
                        UIPasteboard.general.string = allDiagnostics
                        HapticFeedbackService.shared.playSuccess()
                        #endif
                    }) {
                        Label("Copy All", systemImage: "doc.on.doc")
                    }
                    .retroButton(colors: [.retroBlue])
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.loadDiagnosticInfo()
#if !os(tvOS)
                        HapticFeedbackService.shared.playSelection()
                        #endif
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .retroButton(colors: [.retroPurple])
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.retroBlack.opacity(0.3))
        .cornerRadius(10)
        .animateWithReducedMotion(.easeInOut, value: isExpanded)
    }
    
    /// Create a diagnostic section
    /// - Parameters:
    ///   - title: The title of the section
    ///   - content: The content of the section
    /// - Returns: A view
    private func diagnosticSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.retroBlue)
            
            ScrollView {
                Text(content)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 100)
            .background(Color.retroBlack.opacity(0.5))
            .cornerRadius(6)
        }
        .transitionWithReducedMotion(
            .move(edge: .top).combined(with: .opacity),
            fallbackTransition: .opacity
        )
    }
}

#Preview {
    LazyDiagnosticsView(viewModel: UnifiedCloudSyncViewModel())
        .preferredColorScheme(.dark)
        .padding()
        .background(Color.black)
}
