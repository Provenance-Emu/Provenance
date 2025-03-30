import SwiftUI
import PVLogging

/// Preview view showing both portrait and landscape orientations of a skin
struct DeltaSkinPreviewView: View {
    let skins: [any DeltaSkinProtocol]
    let initialSkin: any DeltaSkinProtocol
    let device: DeltaSkinDevice
    let displayType: DeltaSkinDisplayType

    @State private var showHitTestOverlay = false
    @State private var showDebugOverlay = false
    @State private var selectedFilters: Set<TestPatternEffect> = []
    @State private var selectedIndex: Int = 0
    @State private var showFullscreen = false

    init(skins: [any DeltaSkinProtocol], initialSkin: any DeltaSkinProtocol, device: DeltaSkinDevice, displayType: DeltaSkinDisplayType) {
        self.skins = skins
        self.initialSkin = initialSkin
        self.device = device
        self.displayType = displayType
        if let index = skins.firstIndex(where: { $0.identifier == initialSkin.identifier }) {
            _selectedIndex = State(initialValue: index)
        }
    }

    private func makeTraits(orientation: DeltaSkinOrientation) -> DeltaSkinTraits {
        // Try standard first, fallback to edgeToEdge if not supported
        let standardTraits = DeltaSkinTraits(
            device: device,
            displayType: .standard,
            orientation: orientation
        )

        if initialSkin.supports(standardTraits) {
            return standardTraits
        }

        return DeltaSkinTraits(
            device: device,
            displayType: .edgeToEdge,
            orientation: orientation
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Portrait preview
                VStack(alignment: .leading) {
                    Text("Portrait")
                        .font(.headline)
                        .padding(.horizontal)

                    DeltaSkinView(
                        skin: initialSkin,
                        traits: makeTraits(orientation: .portrait),
                        showDebugOverlay: false,
                        showHitTestOverlay: false,
                        isInEmulator: false,
                        inputHandler: DeltaSkinInputHandler()
                    )
                    .frame(height: 400)
                }

                // Landscape preview
                VStack(alignment: .leading) {
                    Text("Landscape")
                        .font(.headline)
                        .padding(.horizontal)

                    DeltaSkinView(
                        skin: initialSkin,
                        traits: makeTraits(orientation: .landscape),
                        showDebugOverlay: false,
                        showHitTestOverlay: false,
                        isInEmulator: false,
                        inputHandler: DeltaSkinInputHandler()
                    )
                    .frame(height: 600)
                    .rotationEffect(.degrees(90))
                }
            }
            .padding(.bottom, 100) // Space for bottom controls
        }
        .safeAreaInset(edge: .bottom) {
            // Bottom controls
            HStack {
                // Debug overlay toggle
                Button {
                    showDebugOverlay.toggle()
                } label: {
                    Image(systemName: showDebugOverlay ? "viewfinder.circle.fill" : "viewfinder.circle")
                        .font(.title2)
                }

                // Hit test overlay toggle
                Button {
                    showHitTestOverlay.toggle()
                } label: {
                    Image(systemName: showHitTestOverlay ? "square.grid.2x2.fill" : "square.grid.2x2")
                        .font(.title2)
                }

                Spacer()

                // Fullscreen button
                Button {
                    showFullscreen = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.title2)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .fullScreenCover(isPresented: $showFullscreen) {
            TabView(selection: $selectedIndex) {
                ForEach(Array(skins.enumerated()), id: \.element.identifier) { index, skin in
                    DeltaSkinFullscreenPreview(
                        skin: skin,
                        traits: makeTraits(orientation: .portrait),
                        filters: selectedFilters
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(selectedIndex + 1) of \(skins.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        DeltaSkinPreviewView(
            skins: [MockDeltaSkin(), MockDeltaSkin()],
            initialSkin: MockDeltaSkin(),
            device: .iphone,
            displayType: .standard
        )
    }
}
