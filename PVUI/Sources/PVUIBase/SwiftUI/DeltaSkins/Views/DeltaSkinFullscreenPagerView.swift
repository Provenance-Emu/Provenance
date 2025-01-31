import SwiftUI

/// Wrapper view for fullscreen controller display that supports paging between skins
public struct DeltaSkinFullscreenPagerView: View {
    let skins: [DeltaSkinProtocol]
    let initialTraits: DeltaSkinTraits
    let screenAspectRatio: CGFloat?

    @Environment(\.dismiss) private var dismiss
    @State private var currentPage: Int = 0
    @State private var currentTraits: DeltaSkinTraits
    @State private var showDebugOverlay = false
    @State private var showHitTestOverlay = false
    @State private var selectedFilters: Set<TestPatternEffect> = []
    @State private var showControls = true
    @GestureState private var dragOffset: CGFloat = 0

    public init(
        skins: [DeltaSkinProtocol],
        traits: DeltaSkinTraits,
        screenAspectRatio: CGFloat? = nil
    ) {
        self.skins = skins
        self.initialTraits = traits
        self.screenAspectRatio = screenAspectRatio

        // Find supported traits for initial state
        var validTraits = traits
        let firstSkin = skins[0]

        // First try the provided traits
        if !firstSkin.supports(traits) {
            // Try all display types with current orientation
            for displayType in DeltaSkinDisplayType.allCases {
                let testTraits = DeltaSkinTraits(
                    device: traits.device,
                    displayType: displayType,
                    orientation: traits.orientation
                )
                if firstSkin.supports(testTraits) {
                    validTraits = testTraits
                    break
                }
            }

            // If still not found, try all combinations
            if !firstSkin.supports(validTraits) {
                for displayType in DeltaSkinDisplayType.allCases {
                    for orientation in DeltaSkinOrientation.allCases {
                        let testTraits = DeltaSkinTraits(
                            device: traits.device,
                            displayType: displayType,
                            orientation: orientation
                        )
                        if firstSkin.supports(testTraits) {
                            validTraits = testTraits
                            break
                        }
                    }
                }
            }
        }

        _currentTraits = State(initialValue: validTraits)
    }

    private func updateTraitsForCurrentOrientation() {
        let currentSkin = skins[currentPage]
        #if os(tvOS)
        let desiredOrientation: DeltaSkinOrientation = .landscape
        #else
        let deviceOrientation = UIDevice.current.orientation

        // Only handle valid orientations
        guard deviceOrientation.isPortrait || deviceOrientation.isLandscape else { return }

        // Convert UIDeviceOrientation to DeltaSkinOrientation
        let desiredOrientation: DeltaSkinOrientation = deviceOrientation.isLandscape ? .landscape : .portrait
        #endif
        
        // First try with current display type
        let newTraits = DeltaSkinTraits(
            device: currentTraits.device,
            displayType: currentTraits.displayType,
            orientation: desiredOrientation
        )

        if currentSkin.supports(newTraits) {
            currentTraits = newTraits
            return
        }

        // Break up the display type check into simpler steps
        for displayType in DeltaSkinDisplayType.allCases {
            // Create traits for this display type
            let alternateTraits = DeltaSkinTraits(
                device: currentTraits.device,
                displayType: displayType,
                orientation: desiredOrientation
            )

            // Check if supported
            let isSupported = currentSkin.supports(alternateTraits)
            if isSupported {
                currentTraits = alternateTraits
                return
            }
        }

        // If no display type supports the desired orientation,
        // keep current traits (effectively locking rotation)
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                skinPagerView(geometry: geometry)
                if showControls {
                    controlBar(geometry: geometry)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            updateTraitsForCurrentOrientation()
        }
        #if !os(tvOS)
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            updateTraitsForCurrentOrientation()
        }
        #endif
    }

    @ViewBuilder
    private func skinPagerView(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<skins.count, id: \.self) { index in
                DeltaSkinView(
                    skin: skins[index],
                    traits: currentTraits,
                    filters: selectedFilters,
                    showDebugOverlay: showDebugOverlay,
                    showHitTestOverlay: showHitTestOverlay,
                    screenAspectRatio: screenAspectRatio
                )
                .id("\(index)-\(currentTraits.orientation)")
                .frame(width: geometry.size.width)
            }
        }
        .offset(x: -CGFloat(currentPage) * geometry.size.width + dragOffset)
        #if !os(tvOS)
        .gesture(pagingGesture(geometry: geometry))
        #endif
        .onTapGesture {
            withAnimation {
                showControls.toggle()
            }
        }
    }

    @ViewBuilder
    private func controlBar(geometry: GeometryProxy) -> some View {
        HStack(spacing: 20) {
            // Main controls group
            HStack(spacing: 16) {
                // Display type button
                Button {
                    withAnimation {
                        cycleDisplayType()
                    }
                } label: {
                    Image(systemName: displayIcon(for: currentTraits.displayType))
                        .symbolVariant(supportedDisplayTypes.count > 1 ? .circle.fill : .circle)
                }
                .disabled(supportedDisplayTypes.count <= 1)

                filtersMenu
                debugButtons
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            )

            Spacer()

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, max(geometry.safeAreaInsets.top, 44))  // Status bar padding
        .padding(.horizontal)
    }

    @ViewBuilder
    private var filtersMenu: some View {
        if #available(tvOS 17.0, *) {
            Menu {
                ForEach(TestPatternEffect.allCases, id: \.self) { effect in
                    Toggle(effect.displayName, isOn: effectBinding(for: effect))
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .symbolVariant(selectedFilters.isEmpty ? .none : .fill)
            }
        } else {
            // Fallback on earlier versions
        }
    }

    @ViewBuilder
    private var debugButtons: some View {
        // Debug overlay
        Button {
            showDebugOverlay.toggle()
        } label: {
            Image(systemName: showDebugOverlay ? "viewfinder.circle.fill" : "viewfinder.circle")
        }

        // Hit test overlay
        Button {
            showHitTestOverlay.toggle()
        } label: {
            Image(systemName: showHitTestOverlay ? "square.grid.2x2.fill" : "square.grid.2x2")
        }
    }

    #if !os(tvOS)
    private func pagingGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                let threshold = geometry.size.width * 0.5
                var newPage = currentPage

                if abs(value.translation.width) > threshold {
                    newPage = value.translation.width > 0 ? currentPage - 1 : currentPage + 1
                }

                newPage = min(max(0, newPage), skins.count - 1)

                withAnimation {
                    currentPage = newPage
                }
            }
    }
    #endif
    
    private var currentSkin: DeltaSkinProtocol {
        skins[currentPage]
    }

    private var supportedDisplayTypes: [DeltaSkinDisplayType] {
        DeltaSkinDisplayType.allCases.filter { type in
            let testTraits = DeltaSkinTraits(
                device: currentTraits.device,
                displayType: type,
                orientation: currentTraits.orientation
            )
            return currentSkin.supports(testTraits)
        }
    }

    private func cycleDisplayType() {
        guard !supportedDisplayTypes.isEmpty else { return }

        // Find current index
        let currentIndex = supportedDisplayTypes.firstIndex(of: currentTraits.displayType) ?? 0

        // Get next supported display type
        let nextIndex = (currentIndex + 1) % supportedDisplayTypes.count
        let nextType = supportedDisplayTypes[nextIndex]

        // Update traits
        currentTraits = DeltaSkinTraits(
            device: currentTraits.device,
            displayType: nextType,
            orientation: currentTraits.orientation
        )
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
