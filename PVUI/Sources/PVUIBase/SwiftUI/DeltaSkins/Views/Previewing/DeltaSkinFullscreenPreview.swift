import SwiftUI
import PVLogging

/// Fullscreen preview of skin with test pattern
struct DeltaSkinFullscreenPreview: View {
    let skin: any DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let filters: Set<TestPatternEffect>

    @State private var currentDisplayType: DeltaSkinDisplayType
    @State private var showDebugOverlay = false
    @State private var showInfoSheet = false
    @State private var showHitTestOverlay = false
    @State private var isEditMode = false
    /// Pending display type when a switch was requested while unsaved edits exist.
    @State private var pendingDisplayType: DeltaSkinDisplayType? = nil
    @StateObject private var editorViewModel: DeltaSkinEditorViewModel
    @Environment(\.dismiss) private var dismiss

    init(skin: any DeltaSkinProtocol, traits: DeltaSkinTraits, filters: Set<TestPatternEffect>, initialEditMode: Bool = false) {
        self.skin = skin
        self.traits = traits
        self.filters = filters
        _currentDisplayType = State(initialValue: traits.displayType)
        _isEditMode = State(initialValue: initialEditMode)
        _editorViewModel = StateObject(wrappedValue: DeltaSkinEditorViewModel(skin: skin, traits: traits))
    }

    private var supportedDisplayTypes: [DeltaSkinDisplayType] {
        DeltaSkinDisplayType.allCases.filter { type in
            skin.supports(DeltaSkinTraits(
                device: traits.device,
                displayType: type,
                orientation: traits.orientation
            ))
        }
    }

    private func nextDisplayType() {
        guard let currentIndex = supportedDisplayTypes.firstIndex(of: currentDisplayType),
              supportedDisplayTypes.count > 1 else { return }

        let next = supportedDisplayTypes[(currentIndex + 1) % supportedDisplayTypes.count]
        if editorViewModel.hasChanges {
            // Ask user before discarding unsaved button position edits
            pendingDisplayType = next
        } else {
            withAnimation { currentDisplayType = next }
        }
    }

    private func displayTypeIcon(_ type: DeltaSkinDisplayType) -> String {
        switch type {
        case .standard: return "rectangle"
        case .edgeToEdge: return "rectangle.inset.filled"
        case .splitView: return "square.split.2x1"
        case .stageManager: return "squares.leading.rectangle"
        case .externalDisplay: return "display.2"
        }
    }

    private var debugInfo: String {
        """
        Skin: \(skin.name)
        ID: \(skin.identifier)
        Game Type: \(skin.gameType.systemIdentifier?.fullName ?? (skin.gameType.deltaIdentifierString ?? skin.gameType.manicIdentifierString ?? String(describing: skin.gameType)))
        Device: \(currentTraits.device.rawValue)
        Display: \(currentTraits.displayType.rawValue)
        Orientation: \(currentTraits.orientation.rawValue)
        Mapping Size: \(skin.mappingSize(for: currentTraits)?.debugDescription ?? "nil")
        Buttons: \(skin.buttons(for: currentTraits)?.count ?? 0)
        Screens: \(skin.screens(for: currentTraits)?.count ?? 0)
        """
    }

    private var currentTraits: DeltaSkinTraits {
        DeltaSkinTraits(
            device: traits.device,
            displayType: currentDisplayType,
            orientation: traits.orientation
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DeltaSkinView(
                    skin: skin,
                    traits: currentTraits,
                    filters: filters,
                    showDebugOverlay: showDebugOverlay && !isEditMode,
                    showHitTestOverlay: showHitTestOverlay && !isEditMode,
                    screenAspectRatio: nil,
                    isInEmulator: false,
                    inputHandler: DeltaSkinInputHandler(),
                    core: nil
                )

                // Edit overlay (replaces debug overlay in edit mode)
                if isEditMode {
                    DeltaSkinEditOverlay(
                        viewModel: editorViewModel,
                        size: geometry.size,
                        safeAreaInsets: geometry.safeAreaInsets
                    )
                }

                // Overlay controls
                VStack {
                    HStack {
                        if !isEditMode {
                            // Debug overlay toggle
                            Button {
                                showDebugOverlay.toggle()
                                if showDebugOverlay {
                                    #if !os(tvOS)
                                    UIPasteboard.general.string = debugInfo
                                    #endif
                                    DLOG("Debug Info:\n\(debugInfo)")
                                }
                            } label: {
                                Image(systemName: showDebugOverlay ? "viewfinder.circle.fill" : "viewfinder.circle")
                                    .font(.title)
                                    .foregroundStyle(.white)
                                    .padding()
                                    .background(Circle().fill(.ultraThinMaterial))
                            }

                            // Hit test overlay toggle
                            Button {
                                showHitTestOverlay.toggle()
                            } label: {
                                Image(systemName: showHitTestOverlay ? "square.grid.2x2.fill" : "square.grid.2x2")
                                    .font(.title)
                                    .foregroundStyle(.white)
                                    .padding()
                                    .background(Circle().fill(.ultraThinMaterial))
                            }

                            // Display type toggle (only show if multiple types supported)
                            if supportedDisplayTypes.count > 1 {
                                Button { nextDisplayType() } label: {
                                    Image(systemName: displayTypeIcon(currentDisplayType))
                                        .font(.title)
                                        .foregroundStyle(.white)
                                        .padding()
                                        .background(Circle().fill(.ultraThinMaterial))
                                }
                            }
                        }

                        // Edit mode toggle (drag gesture is iOS-only inside the overlay; tvOS can still inspect button coordinates)
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isEditMode.toggle()
                                if !isEditMode {
                                    editorViewModel.clearSelection()
                                }
                            }
                        } label: {
                            Image(systemName: isEditMode ? "pencil.circle.fill" : "pencil.circle")
                                .font(.title)
                                .foregroundStyle(isEditMode ? .yellow : .white)
                                .padding()
                                .background(Circle().fill(isEditMode ? AnyShapeStyle(.yellow.opacity(0.2)) : AnyShapeStyle(.ultraThinMaterial)))
                        }
                        .accessibilityLabel("Edit Button Positions")
                        .accessibilityValue(isEditMode ? "Active" : "Inactive")

                        // Export edited skin (iOS only — no ShareSheet on tvOS)
                        #if !os(tvOS)
                        if isEditMode && editorViewModel.hasChanges {
                            Button {
                                editorViewModel.exportSkin()
                            } label: {
                                HStack(spacing: 4) {
                                    if editorViewModel.isExporting {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "square.and.arrow.up")
                                    }
                                    Text("Export")
                                        .font(.subheadline)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(.green.opacity(0.85)))
                            }
                            .disabled(editorViewModel.isExporting)
                        }
                        #endif

                        Spacer()

                        // Info button (hidden in edit mode to reduce clutter)
                        if !isEditMode {
                            Button {
                                showInfoSheet = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.title)
                                    .foregroundStyle(.white)
                                    .padding()
                                    .background(Circle().fill(.ultraThinMaterial))
                            }
                        }

                        // Dismiss button
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .padding()
                                .background(Circle().fill(.ultraThinMaterial))
                        }
                    }
                    .padding()

                    Spacer()

                    // Status bar in edit mode
                    if isEditMode {
                        DeltaSkinEditorStatusBar(viewModel: editorViewModel)
                    }
                }

            }
        }
        .sheet(isPresented: $showInfoSheet) {
            DeltaSkinInfoSheet(skin: skin)
        }
        #if !os(tvOS)
        .sheet(item: Binding(
            get: { editorViewModel.exportedURL.map { ExportedSkinURL($0) } },
            set: { _ in editorViewModel.exportedURL = nil }
        )) { wrapper in
            ShareSheet(activityItems: [wrapper.url])
        }
        .alert("Export Failed",
               isPresented: Binding(
                get: { editorViewModel.exportError != nil },
                set: { if !$0 { editorViewModel.exportError = nil } }
               )
        ) {
            Button("OK", role: .cancel) { editorViewModel.exportError = nil }
        } message: {
            Text(editorViewModel.exportError?.localizedDescription ?? "Unknown error")
        }
        .statusBar(hidden: true)
        #endif
        .alert("Discard Edits?", isPresented: Binding(
            get: { pendingDisplayType != nil },
            set: { if !$0 { pendingDisplayType = nil } }
        )) {
            Button("Discard", role: .destructive) {
                if let next = pendingDisplayType {
                    pendingDisplayType = nil
                    withAnimation { currentDisplayType = next }
                }
            }
            Button("Cancel", role: .cancel) { pendingDisplayType = nil }
        } message: {
            Text("Switching display type will discard your unsaved button position edits.")
        }
        .onChange(of: currentDisplayType) { _ in
            editorViewModel.updateTraits(currentTraits)
        }
        .ignoresSafeArea()
        .onAppear {
            #if !os(tvOS)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                DLOG("FullscreenPreview safe areas: \(window.safeAreaInsets)")
            }
            #endif
        }
    }

    /// Thin `Identifiable` wrapper so we can drive a `.sheet(item:)` from a URL.
    private struct ExportedSkinURL: Identifiable {
        let id: String
        let url: URL
        init(_ url: URL) { self.url = url; self.id = url.absoluteString }
    }
}

/// Sheet showing detailed skin information
private struct DeltaSkinInfoSheet: View {
    let skin: any DeltaSkinProtocol
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                SwiftUI.Section("Skin Information") {
                    LabeledContent("Name", value: skin.name)
                    LabeledContent("Identifier", value: skin.identifier)
                    LabeledContent("Game Type", value: skin.gameType.systemIdentifier?.fullName ?? (skin.gameType.deltaIdentifierString ?? skin.gameType.manicIdentifierString ?? String(describing: skin.gameType)))
                }

                SwiftUI.Section("Supported Configurations") {
                    ForEach(DeltaSkinDevice.allCases, id: \.self) { device in
                        deviceSection(device)
                    }
                }
            }
            .navigationTitle("Skin Details")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func deviceSection(_ device: DeltaSkinDevice) -> some View {
        #if !os(tvOS)
        DisclosureGroup(device.rawValue) {
            ForEach(supportedDisplayTypes(for: device), id: \.self) { type in
                displayTypeSection(type, for: device)
            }
        }
        #else
        ForEach(supportedDisplayTypes(for: device), id: \.self) { type in
            displayTypeSection(type, for: device)
        }
        #endif
    }

    @ViewBuilder
    private func displayTypeSection(_ type: DeltaSkinDisplayType, for device: DeltaSkinDevice) -> some View {
        #if !os(tvOS)
        DisclosureGroup(type.rawValue) {
            ForEach(supportedOrientations(for: device, type: type), id: \.self) { orientation in
                Text(orientation.rawValue)
                    .padding(.leading)
            }
        }
        #else
        ForEach(supportedOrientations(for: device, type: type), id: \.self) { orientation in
            Text(orientation.rawValue)
                .padding(.leading)
        }
        #endif
    }

    private func supportedDisplayTypes(for device: DeltaSkinDevice) -> [DeltaSkinDisplayType] {
        DeltaSkinDisplayType.allCases.filter { type in
            DeltaSkinOrientation.allCases.contains { orientation in
                let traits = DeltaSkinTraits(device: device, displayType: type, orientation: orientation)
                return skin.supports(traits)
            }
        }
    }

    private func supportedOrientations(for device: DeltaSkinDevice, type: DeltaSkinDisplayType) -> [DeltaSkinOrientation] {
        DeltaSkinOrientation.allCases.filter { orientation in
            let traits = DeltaSkinTraits(device: device, displayType: type, orientation: orientation)
            return skin.supports(traits)
        }
    }
}

extension UIEdgeInsets {
    var debugDescription: String {
        return "UIEdgeInsets(top: \(top), left: \(left), bottom: \(bottom), right: \(right))"
    }
}
