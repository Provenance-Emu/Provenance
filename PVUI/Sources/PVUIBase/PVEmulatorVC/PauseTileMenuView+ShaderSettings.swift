//
//  PauseTileMenuView+ShaderSettings.swift
//  PVUI
//
//  Shader parameter editor sheet for the tile-based pause menu.
//  Reuses the filter-specific parameter views from RetroMenuView+ShaderParameters.swift.
//  Only shown when the active Metal filter has adjustable parameters.
//

import SwiftUI
import PVSettings
import PVThemes

// MARK: - ShaderSettingsPauseSheet

/// Sheet that shows the shader parameter sliders for the currently active Metal filter.
/// Displayed when the user taps the "Shader Settings" tile in PauseTileMenuView.
struct ShaderSettingsPauseSheet: View {
    @Default(.metalFilterMode) private var metalFilterMode
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    private var palette: UXThemePalette { themeManager.currentPalette }

    private var currentFilter: MetalFilterSelectionOption {
        MetalFilterModeOption.parseCurrentFilter(from: metalFilterMode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Filter preview bar
                    if currentFilter != .none {
                        FilterPreviewBarsView(filter: currentFilter, palette: palette)
                            .frame(height: 80)
                            .padding(.horizontal)
                    }

                    // Parameter sliders
                    if currentFilter.hasEditableParameters {
                        parameterView(for: currentFilter)
                            .padding(.horizontal)
                    } else {
                        Text(String(localized: "No adjustable parameters for this filter."))
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(palette.gameLibraryBackground).ignoresSafeArea())
            .navigationTitle(currentFilter == .none ? String(localized: "Shader Settings") : currentFilter.description)
            .navigationBarTitleDisplayMode(.inline)
        }
        #if os(tvOS)
        // On tvOS the hardware Menu button is the standard way to dismiss sheets.
        .onExitCommand { dismiss() }
        #endif
    }

    @ViewBuilder
    private func parameterView(for filter: MetalFilterSelectionOption) -> some View {
        switch filter {
        case .simpleCRT:  SimpleCRTParametersView(palette: palette)
        case .complexCRT: ComplexCRTParametersView(palette: palette)
        case .lcd:        LCDParametersView(palette: palette)
        case .megaTron:   MegaTronParametersView(palette: palette)
        case .ulTron:     UlTronParametersView(palette: palette)
        case .gameBoy:    GameBoyParametersView(palette: palette)
        case .vhs:        VHSParametersView(palette: palette)
        case .none:       EmptyView()
        }
    }
}
