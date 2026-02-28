import SwiftUI
import PVSettings
import Defaults
import PVThemes

struct FilterSettingsView: View {
    @Default(.metalFilterMode) var metalFilterMode
    @Default(.openGLFilterMode) var openGLFilterMode

    var body: some View {
        Form {
            MetalFilterSection(metalFilterMode: $metalFilterMode)
            OpenGLFilterSection(openGLFilterMode: $openGLFilterMode)
        }
        #if os(tvOS)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color.retroPurple.opacity(0.1),
                    Color.retroPink.opacity(0.05)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        #else
        // .scrollContentBackground(.hidden)
        #endif
        .navigationTitle("Display Filters")

        Text("Metal filters provided by Mr. J & Mame4iOS.")
            .font(.caption)
            #if os(tvOS)
            .foregroundColor(.retroBlue)
            #endif
    }
}

private struct MetalFilterSection: View {
    @Binding var metalFilterMode: MetalFilterModeOption

    // State for auto mode settings
    @State private var selectedCRTFilter: MetalFilterSelectionOption
    @State private var selectedLCDFilter: MetalFilterSelectionOption

    // State for always mode setting
    @State private var selectedAlwaysFilter: MetalFilterSelectionOption

    init(metalFilterMode: Binding<MetalFilterModeOption>) {
        _metalFilterMode = metalFilterMode

        switch metalFilterMode.wrappedValue {
        case .auto(let crt, let lcd):
            _selectedCRTFilter = State(initialValue: crt)
            _selectedLCDFilter = State(initialValue: lcd)
            _selectedAlwaysFilter = State(initialValue: .defaultValue)
        case .always(let filter):
            _selectedAlwaysFilter = State(initialValue: filter)
            _selectedCRTFilter = State(initialValue: .defaultValue)
            _selectedLCDFilter = State(initialValue: .defaultValue)
        case .none:
            _selectedCRTFilter = State(initialValue: .defaultValue)
            _selectedLCDFilter = State(initialValue: .defaultValue)
            _selectedAlwaysFilter = State(initialValue: .defaultValue)
        }
    }

    /// Returns the active CRT filter selection, if any.
    private var activeCRTFilter: MetalFilterSelectionOption? {
        switch metalFilterMode {
        case .auto(let crt, _):
            return crt == .none ? nil : crt
        case .always(let filter):
            return (filter == .simpleCRT || filter == .complexCRT) ? filter : nil
        case .none:
            return nil
        }
    }

    var body: some View {
        Section(header:
            Text("Metal Filters")
                #if os(tvOS)
                .foregroundColor(.retroPink)
                .font(.headline)
                #endif
        ) {
            Picker("Filter Mode", selection: $metalFilterMode) {
                Text("Off").tag(MetalFilterModeOption.none)
                Text("Auto").tag(MetalFilterModeOption.auto(crt: selectedCRTFilter, lcd: selectedLCDFilter))
                Text("Always").tag(MetalFilterModeOption.always(filter: selectedAlwaysFilter))
            }
            #if os(tvOS)
            .pickerStyle(.automatic)
            .tint(.retroBlue)
            #endif

            switch metalFilterMode {
            case .auto:
                Picker("CRT Filter Type", selection: $selectedCRTFilter) {
                    ForEach([MetalFilterSelectionOption.simpleCRT, .complexCRT], id: \.self) { filter in
                        Text(filter.description).tag(filter)
                    }
                }
                #if os(tvOS)
                .tint(.retroPurple)
                #endif
                .onChange(of: selectedCRTFilter) { newValue in
                    metalFilterMode = .auto(crt: newValue, lcd: selectedLCDFilter)
                }

                Picker("LCD Filter Type", selection: $selectedLCDFilter) {
                    ForEach([MetalFilterSelectionOption.lcd], id: \.self) { filter in
                        Text(filter.description).tag(filter)
                    }
                }
                #if os(tvOS)
                .tint(.retroPurple)
                #endif
                .onChange(of: selectedLCDFilter) { newValue in
                    metalFilterMode = .auto(crt: selectedCRTFilter, lcd: newValue)
                }

            case .always:
                Picker("Filter Type", selection: $selectedAlwaysFilter) {
                    ForEach(MetalFilterSelectionOption.allCases, id: \.self) { filter in
                        Text(filter.description).tag(filter)
                    }
                }
                #if os(tvOS)
                .tint(.retroPink)
                #endif
                .onChange(of: selectedAlwaysFilter) { newValue in
                    metalFilterMode = .always(filter: newValue)
                }

            case .none:
                EmptyView()
            }
        }

        // Show CRT parameter controls when a CRT filter is active
        if let crtFilter = activeCRTFilter {
            switch crtFilter {
            case .simpleCRT:
                SimpleCRTParametersSection()
            case .complexCRT:
                ComplexCRTParametersSection()
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Simple CRT Parameters

private struct SimpleCRTParametersSection: View {
    @Default(.simpleCRTCurvVert) var curvVert
    @Default(.simpleCRTCurvHoriz) var curvHoriz
    @Default(.simpleCRTCurvStrength) var curvStrength
    @Default(.simpleCRTLightBoost) var lightBoost
    @Default(.simpleCRTVignStrength) var vignStrength
    @Default(.simpleCRTZoomOut) var zoomOut
    @Default(.simpleCRTBrightness) var brightness

    var body: some View {
        Section(header:
            Text("Simple CRT Parameters")
                #if os(tvOS)
                .foregroundColor(.retroPink)
                .font(.headline)
                #endif
        ) {
            ShaderSliderRow(
                label: "Curvature (Vertical)",
                value: $curvVert,
                range: 1.0...10.0,
                defaultValue: 5.0
            )
            ShaderSliderRow(
                label: "Curvature (Horizontal)",
                value: $curvHoriz,
                range: 1.0...10.0,
                defaultValue: 4.0
            )
            ShaderSliderRow(
                label: "Curvature Strength",
                value: $curvStrength,
                range: 0.0...1.0,
                defaultValue: 0.25
            )
            ShaderSliderRow(
                label: "Light Boost",
                value: $lightBoost,
                range: 0.1...3.0,
                defaultValue: 1.3
            )
            ShaderSliderRow(
                label: "Vignette",
                value: $vignStrength,
                range: 0.0...1.0,
                defaultValue: 0.05
            )
            ShaderSliderRow(
                label: "Zoom Out",
                value: $zoomOut,
                range: 0.5...2.0,
                defaultValue: 1.1
            )
            ShaderSliderRow(
                label: "Brightness",
                value: $brightness,
                range: 0.5...1.5,
                defaultValue: 1.0
            )

            Button("Reset to Defaults") {
                curvVert = 5.0
                curvHoriz = 4.0
                curvStrength = 0.25
                lightBoost = 1.3
                vignStrength = 0.05
                zoomOut = 1.1
                brightness = 1.0
            }
            .foregroundColor(.red)
        }
    }
}

// MARK: - Complex CRT Parameters

private struct ComplexCRTParametersSection: View {
    @Default(.complexCRTUseScanlines) var useScanlines
    @Default(.complexCRTUseShadowMask) var useShadowMask
    @Default(.complexCRTUseWarp) var useWarp
    @Default(.complexCRTBloomAmount) var bloomAmount
    @Default(.complexCRTScanlineHardness) var scanlineHardness
    @Default(.complexCRTShadowMaskHardness) var shadowMaskHardness
    @Default(.complexCRTRowsOfResolution) var rowsOfResolution
    @Default(.complexCRTTVL) var tvl
    @Default(.complexCRTWarpX) var warpX
    @Default(.complexCRTWarpY) var warpY
    @Default(.complexCRTDisplayGamma) var displayGamma

    var body: some View {
        Section(header:
            Text("Complex CRT Parameters")
                #if os(tvOS)
                .foregroundColor(.retroPink)
                .font(.headline)
                #endif
        ) {
            Toggle("Scanlines", isOn: $useScanlines)
            Toggle("Shadow Mask", isOn: $useShadowMask)
            Toggle("Screen Warp", isOn: $useWarp)

            ShaderSliderRow(
                label: "Bloom Amount",
                value: $bloomAmount,
                range: 0.0...6.0,
                defaultValue: 2.0
            )

            if useScanlines {
                ShaderSliderRow(
                    label: "Scanline Hardness",
                    value: $scanlineHardness,
                    range: 1.0...12.0,
                    defaultValue: 4.0
                )
                ShaderSliderRow(
                    label: "CRT Resolution (lines)",
                    value: $rowsOfResolution,
                    range: 240.0...1080.0,
                    defaultValue: 480.0
                )
            }

            if useShadowMask {
                ShaderSliderRow(
                    label: "Shadow Mask Hardness",
                    value: $shadowMaskHardness,
                    range: 4.0...32.0,
                    defaultValue: 16.0
                )
                ShaderSliderRow(
                    label: "TV Lines (mask density)",
                    value: $tvl,
                    range: 400.0...1200.0,
                    defaultValue: 800.0
                )
            }

            if useWarp {
                ShaderSliderRow(
                    label: "Warp Horizontal",
                    value: $warpX,
                    range: 0.0...0.05,
                    defaultValue: 1.0 / 96.0
                )
                ShaderSliderRow(
                    label: "Warp Vertical",
                    value: $warpY,
                    range: 0.0...0.1,
                    defaultValue: 1.0 / 36.0
                )
            }

            ShaderSliderRow(
                label: "Display Gamma",
                value: $displayGamma,
                range: 1.8...2.6,
                defaultValue: 2.2
            )

            Button("Reset to Defaults") {
                useScanlines = true
                useShadowMask = true
                useWarp = true
                bloomAmount = 2.0
                scanlineHardness = 4.0
                shadowMaskHardness = 16.0
                rowsOfResolution = 480.0
                tvl = 800.0
                warpX = 1.0 / 96.0
                warpY = 1.0 / 36.0
                displayGamma = 2.2
            }
            .foregroundColor(.red)
        }
    }
}

// MARK: - Shared Slider Row

/// A reusable row showing a label, a value readout, and a slider.
private struct ShaderSliderRow: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let defaultValue: Float

    private var formattedValue: String {
        if range.upperBound - range.lowerBound >= 10 {
            return String(format: "%.0f", value)
        } else if range.upperBound - range.lowerBound >= 1 {
            return String(format: "%.2f", value)
        } else {
            return String(format: "%.3f", value)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(formattedValue)
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            Slider(value: $value, in: range)
                #if os(tvOS)
                .tint(.retroBlue)
                #endif
        }
        .padding(.vertical, 2)
    }
}

private struct OpenGLFilterSection: View {
    @Binding var openGLFilterMode: OpenGLFilterModeOption

    var body: some View {
        Section(header:
            Text("OpenGL Filters")
                #if os(tvOS)
                .foregroundColor(.retroPink)
                .font(.headline)
                #endif
        ) {
            Picker("Filter Type", selection: $openGLFilterMode) {
                ForEach(OpenGLFilterModeOption.allCases, id: \.self) { filter in
                    Text(filter.description).tag(filter)
                }
            }
            #if os(tvOS)
            .pickerStyle(.automatic)
            .tint(.retroBlue)
            #endif
        }
    }
}
