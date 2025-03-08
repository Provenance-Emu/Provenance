import SwiftUI
import PVSettings
import Defaults

struct FilterSettingsView: View {
    @Default(.metalFilterMode) var metalFilterMode
    @Default(.openGLFilterMode) var openGLFilterMode

    var body: some View {
        Form {
            MetalFilterSection(metalFilterMode: $metalFilterMode)
            OpenGLFilterSection(openGLFilterMode: $openGLFilterMode)
        }
        .navigationTitle("Display Filters")
        
        Text("Metal filters provided by Mr. J & Mame4iOS.")
            .font(.caption)
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

    var body: some View {
        Section(header: Text("Metal Filters")) {
            Picker("Filter Mode", selection: $metalFilterMode) {
                Text("Off").tag(MetalFilterModeOption.none)
                Text("Auto").tag(MetalFilterModeOption.auto(crt: selectedCRTFilter, lcd: selectedLCDFilter))
                Text("Always").tag(MetalFilterModeOption.always(filter: selectedAlwaysFilter))
            }

            switch metalFilterMode {
            case .auto:
                VStack {
                    Picker("CRT Filter Type", selection: $selectedCRTFilter) {
                        ForEach([MetalFilterSelectionOption.simpleCRT, .complexCRT], id: \.self) { filter in
                            Text(filter.description).tag(filter)
                        }
                    }
                    .onChange(of: selectedCRTFilter) { newValue in
                        metalFilterMode = .auto(crt: newValue, lcd: selectedLCDFilter)
                    }

                    Picker("LCD Filter Type", selection: $selectedLCDFilter) {
                        ForEach([MetalFilterSelectionOption.lcd], id: \.self) { filter in
                            Text(filter.description).tag(filter)
                        }
                    }
                    .onChange(of: selectedLCDFilter) { newValue in
                        metalFilterMode = .auto(crt: selectedCRTFilter, lcd: newValue)
                    }
                }

            case .always:
                Picker("Filter Type", selection: $selectedAlwaysFilter) {
                    ForEach(MetalFilterSelectionOption.allCases, id: \.self) { filter in
                        Text(filter.description).tag(filter)
                    }
                }
                .onChange(of: selectedAlwaysFilter) { newValue in
                    metalFilterMode = .always(filter: newValue)
                }

            case .none:
                EmptyView()
            }
        }
    }
}

private struct OpenGLFilterSection: View {
    @Binding var openGLFilterMode: OpenGLFilterModeOption

    var body: some View {
        Section(header: Text("OpenGL Filters")) {
            Picker("Filter Type", selection: $openGLFilterMode) {
                ForEach(OpenGLFilterModeOption.allCases, id: \.self) { filter in
                    Text(filter.description).tag(filter)
                }
            }
        }
    }
}
