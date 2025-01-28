import SwiftUI
import PVLogging

/// View for testing DeltaSkin layouts and configurations
public struct DeltaSkinTestView: View {
    let skin: DeltaSkinProtocol

    @State private var selectedDevice: DeltaSkinDevice
    @State private var selectedDisplayType: DeltaSkinDisplayType
    @State private var showDebugOverlay = false
    @State private var showHitTestOverlay = false
    @State private var selectedFilters: Set<TestPatternEffect> = []
    @State private var showFullscreen = false
    @State private var fullscreenOrientation: DeltaSkinOrientation = .portrait
    @State private var showingFullscreenPreview = false
    @State private var selectedTraits: DeltaSkinTraits
    @State private var screenAspectRatio: CGFloat?

    public init(skin: DeltaSkinProtocol) {
        self.skin = skin

        // Set initial traits based on current orientation
        let isLandscape = UIDevice.current.orientation.isLandscape
        let orientation: DeltaSkinOrientation = isLandscape ? .landscape : .portrait
        let device: DeltaSkinDevice = UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone

        let traits = DeltaSkinTraits(
            device: device,
            displayType: .standard,
            orientation: orientation
        )

        _selectedTraits = State(initialValue: traits)

        // Find first supported device
        _selectedDevice = State(initialValue: device)

        // Find first supported display type for the device
        _selectedDisplayType = State(initialValue: .standard)

        DLOG("Initializing test view for skin: \(skin.name)")
    }

    private func makeTraits(orientation: DeltaSkinOrientation) -> DeltaSkinTraits {
        // Try standard first
        let standardTraits = DeltaSkinTraits(
            device: selectedDevice,
            displayType: .standard,
            orientation: orientation
        )

        // Try selected display type
        let selectedTraits = DeltaSkinTraits(
            device: selectedDevice,
            displayType: selectedDisplayType,
            orientation: orientation
        )

        // Use selected display type if supported, otherwise try standard, then edge to edge
        if skin.supports(selectedTraits) {
            return selectedTraits
        } else if skin.supports(standardTraits) {
            return standardTraits
        }

        // Fallback to edge to edge
        return DeltaSkinTraits(
            device: selectedDevice,
            displayType: .edgeToEdge,
            orientation: orientation
        )
    }

    private var supportsLandscape: Bool {
        let landscapeTraits = DeltaSkinTraits(
            device: selectedDevice,
            displayType: selectedDisplayType,
            orientation: .landscape
        )
        return skin.supports(landscapeTraits)
    }

    // Computed properties for supported configurations
    private var supportedDevices: [DeltaSkinDevice] {
        DeltaSkinDevice.allCases.filter { device in
            DeltaSkinDisplayType.allCases.contains { displayType in
                DeltaSkinOrientation.allCases.contains { orientation in
                    let traits = DeltaSkinTraits(
                        device: device,
                        displayType: displayType,
                        orientation: orientation
                    )
                    return skin.supports(traits)
                }
            }
        }
    }

    private var supportedDisplayTypes: [DeltaSkinDisplayType] {
        DeltaSkinDisplayType.allCases.filter { type in
            let traits = DeltaSkinTraits(
                device: selectedDevice,
                displayType: type,
                orientation: .portrait  // Use portrait as reference
            )
            return skin.supports(traits)
        }
    }

    private func cycleDisplayType() {
        guard !supportedDisplayTypes.isEmpty else { return }

        // Find current index
        let currentIndex = supportedDisplayTypes.firstIndex(of: selectedDisplayType) ?? 0

        // Get next supported display type
        let nextIndex = (currentIndex + 1) % supportedDisplayTypes.count
        let nextType = supportedDisplayTypes[nextIndex]

        withAnimation {
            selectedDisplayType = nextType
        }
    }

    private func showFullscreenPreview(orientation: DeltaSkinOrientation) {
        // Update traits for the selected orientation
        selectedTraits = DeltaSkinTraits(
            device: selectedDevice,
            displayType: selectedDisplayType,
            orientation: orientation
        )
        showingFullscreenPreview = true
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                controlBar
                previewArea(geometry: geometry)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(skin.name)
        .fullScreenCover(isPresented: $showingFullscreenPreview) {
            DeltaSkinFullscreenPagerView(
                skins: [skin],
                traits: selectedTraits,
                screenAspectRatio: screenAspectRatio
            )
        }
    }

    // MARK: - Control Bar
    @ViewBuilder
    private var controlBar: some View {
        HStack(spacing: 16) {
            devicePicker
            displayTypeCycleButton
            Spacer()
            controlButtons
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
        )
    }

    @ViewBuilder
    private var devicePicker: some View {
        Menu {
            ForEach(supportedDevices, id: \.self) { device in
                Button {
                    selectedDevice = device
                    if !supportedDisplayTypes.contains(selectedDisplayType) {
                        selectedDisplayType = supportedDisplayTypes.first ?? .standard
                    }
                } label: {
                    Label(device.rawValue, systemImage: deviceIcon(for: device))
                        .foregroundColor(.primary)
                }
            }
        } label: {
            Label(selectedDevice.rawValue, systemImage: deviceIcon(for: selectedDevice))
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private var displayTypeCycleButton: some View {
        Button {
            cycleDisplayType()
        } label: {
            Label(selectedDisplayType.rawValue, systemImage: displayIcon(for: selectedDisplayType))
                .font(.subheadline)
                .symbolVariant(supportedDisplayTypes.count > 1 ? .circle.fill : .circle)
        }
        .disabled(supportedDisplayTypes.count <= 1)
    }

    @ViewBuilder
    private var controlButtons: some View {
        HStack(spacing: 16) {
            filtersMenu
            debugButtons
            fullscreenButton
        }
    }

    @ViewBuilder
    private var filtersMenu: some View {
        Menu {
            ForEach(TestPatternEffect.allCases, id: \.self) { effect in
                Toggle(effect.displayName, isOn: effectBinding(for: effect))
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .symbolVariant(selectedFilters.isEmpty ? .none : .fill)
        }
    }

    @ViewBuilder
    private var debugButtons: some View {
        Button {
            showDebugOverlay.toggle()
        } label: {
            Image(systemName: showDebugOverlay ? "viewfinder.circle.fill" : "viewfinder.circle")
        }

        Button {
            showHitTestOverlay.toggle()
        } label: {
            Image(systemName: showHitTestOverlay ? "square.grid.2x2.fill" : "square.grid.2x2")
        }
    }

    @ViewBuilder
    private var fullscreenButton: some View {
        Button {
            showingFullscreenPreview = true
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
        }
    }

    // MARK: - Preview Area
    @ViewBuilder
    private func previewArea(geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                portraitPreview(geometry: geometry)
                if supportsLandscape {
                    landscapePreview(geometry: geometry)
                }
                MetadataGrid(skin: skin)
            }
            .padding(.vertical)
        }
    }

    @ViewBuilder
    private func portraitPreview(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Portrait")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            DeltaSkinView(
                skin: skin,
                traits: makeTraits(orientation: .portrait),
                filters: selectedFilters,
                showDebugOverlay: showDebugOverlay,
                showHitTestOverlay: showHitTestOverlay
            )
            .allowsHitTesting(false)
            .frame(
                width: geometry.size.width - 32,
                height: (geometry.size.width - 32) * 1.5
            )
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                showFullscreenPreview(orientation: .portrait)
            }
        }
    }

    @ViewBuilder
    private func landscapePreview(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Landscape")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            let deviceScreen = DeltaSkinDefaults.screenSize(for: selectedDevice)
            let containerWidth = geometry.size.width - 32
            let rotatedHeight = deviceScreen.height
            let rotatedWidth = deviceScreen.width
            let scale = containerWidth / rotatedHeight

            ZStack {
                DeltaSkinView(
                    skin: skin,
                    traits: makeTraits(orientation: .landscape),
                    filters: selectedFilters,
                    showDebugOverlay: showDebugOverlay,
                    showHitTestOverlay: showHitTestOverlay
                )
                .allowsHitTesting(false)
                .frame(
                    width: rotatedWidth * scale,
                    height: rotatedHeight * scale
                )
                .rotationEffect(.degrees(90))
            }
            .frame(
                width: containerWidth,
                height: rotatedWidth * scale
            )
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                showFullscreenPreview(orientation: .landscape)
            }
        }
    }

    private func deviceIcon(for device: DeltaSkinDevice) -> String {
        switch device {
        case .iphone: return "iphone"
        case .ipad: return "ipad"
        }
    }

    private func displayIcon(for type: DeltaSkinDisplayType) -> String {
        switch type {
        case .standard: return "rectangle"
        case .edgeToEdge: return "rectangle.inset.bottomright.filled"
        case .splitView: return "rectangle.split.2x1"
        case .stageManager: return "rectangle.split.3x1"
        case .externalDisplay: return "rectangle.connected.to.line.below"
        }
    }

    private func effectBinding(for effect: TestPatternEffect) -> Binding<Bool> {
        Binding(
            get: { selectedFilters.contains(effect) },
            set: { isEnabled in
                if isEnabled {
                    selectedFilters.insert(effect)
                } else {
                    selectedFilters.remove(effect)
                }
            }
        )
    }
}

#Preview {
    NavigationView {
        DeltaSkinTestView(skin: MockDeltaSkin())
    }
}

// Helper extension for filter names
extension TestPatternEffect {
    var displayName: String {
        switch self {
        case .lcd: return "LCD"
        case .scanlines: return "Scanlines"
        case .subpixel: return "Subpixel"
        case .pixelated: return "Pixelated"
        }
    }
}

/// Info cell for displaying skin metadata
private struct MetadataCell: View {
    let title: String
    let value: String
    let systemImage: String
    var lineLimit: Int? = 1  // Make line limit optional

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .lineLimit(lineLimit)  // Optional line limit will work here
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Grid of metadata cells
private struct MetadataGrid: View {
    let skin: DeltaSkinProtocol
    @State private var showCopiedAlert = false

    private var supportedTraits: String {
        // Group traits by device
        var deviceGroups: [String: [(displayType: DeltaSkinDisplayType, orientation: DeltaSkinOrientation)]] = [:]

        for device in DeltaSkinDevice.allCases {
            var deviceTraits: [(DeltaSkinDisplayType, DeltaSkinOrientation)] = []

            for displayType in DeltaSkinDisplayType.allCases {
                for orientation in DeltaSkinOrientation.allCases {
                    let trait = DeltaSkinTraits(
                        device: device,
                        displayType: displayType,
                        orientation: orientation
                    )
                    if skin.supports(trait) {
                        deviceTraits.append((displayType, orientation))
                    }
                }
            }

            if !deviceTraits.isEmpty {
                deviceGroups[device.rawValue] = deviceTraits
            }
        }

        // Format the output
        if deviceGroups.isEmpty {
            return "None"
        }

        return deviceGroups
            .sorted(by: { $0.key < $1.key })
            .map { device, traits -> String in
                // Device header
                let header = "📱 \(device)"

                // Group traits by display type
                let displayTypes = Dictionary(grouping: traits) { $0.displayType }
                    .sorted(by: { $0.key.rawValue < $1.key.rawValue })
                    .map { displayType, orientations -> String in
                        let orientationList = orientations
                            .map { $0.orientation.rawValue }
                            .sorted()
                            .joined(separator: ", ")
                        return "  • \(displayType.rawValue)\n    \(orientationList)"
                    }
                    .joined(separator: "\n")

                return "\(header)\n\(displayTypes)"
            }
            .joined(separator: "\n\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Skin Information")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12)  // Single column for better readability
            ], spacing: 12) {
                MetadataCell(
                    title: "Name",
                    value: skin.name,
                    systemImage: "tag",
                    lineLimit: 2
                )

                MetadataCell(
                    title: "Game Type",
                    value: skin.gameType.systemIdentifier?.fullName ?? skin.gameType.rawValue,
                    systemImage: "gamecontroller",
                    lineLimit: 2
                )

                MetadataCell(
                    title: "File",
                    value: skin.fileURL.lastPathComponent,
                    systemImage: "folder",
                    lineLimit: 2
                )

                MetadataCell(
                    title: "Supported Traits",
                    value: supportedTraits,
                    systemImage: "list.bullet",
                    lineLimit: nil  // Allow unlimited lines
                )

                Button {
                    if let jsonData = try? JSONSerialization.data(withJSONObject: skin.jsonRepresentation, options: .prettyPrinted),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        UIPasteboard.general.string = jsonString
                        showCopiedAlert = true
                    }
                } label: {
                    Label("Copy JSON", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
        .overlay {
            if showCopiedAlert {
                Text("JSON Copied!")
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showCopiedAlert = false
                            }
                        }
                    }
            }
        }
    }
}
