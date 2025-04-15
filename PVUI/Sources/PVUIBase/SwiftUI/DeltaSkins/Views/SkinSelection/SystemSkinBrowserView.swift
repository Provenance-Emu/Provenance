import SwiftUI
import PVPrimitives
import PVLogging
import UniformTypeIdentifiers

/// View for browsing and selecting skins for all systems with retrowave styling
public struct SystemSkinBrowserView: View {
    // MARK: - Properties
    
    @StateObject private var skinManager = DeltaSkinManager.shared
    @State private var systemSkinCounts: [SystemIdentifier: Int] = [:]
    @State private var isLoading = true
    @State private var loadingProgress: Double = 0
    @State private var selectedSystem: SystemIdentifier?
    
    // Environment properties
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    // UI state
    @State private var showingDocumentPicker = false
    @State private var showingImportError = false
    @State private var importError: Error?
    @State private var importingFiles = false
    @State private var importProgress: Double = 0
    
    // Animation states
    @State private var appearAnimation = false
    @State private var glowIntensity: CGFloat = 0.5
    
    public init() {}
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            // Retrowave background
            RetroTheme.retroBackground
                .ignoresSafeArea()
            
            // Main content
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 24) {
                        if isLoading {
                            loadingView
                        } else if supportedSystems.isEmpty {
                            emptyStateView
                        } else {
                            systemsGridView
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("Controller Skins")
#if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingDocumentPicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation {
                        isLoading = true
                    }
                    Task {
                        await reloadAllSkins()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)
                }
                .disabled(isLoading)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                appearAnimation = true
            }
            
            // Start glow animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowIntensity = 0.8
            }
            
            // Load skins with a slight delay for animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                loadSkins()
            }
        }
        // Navigation handled in systemSection via NavigationLink
        #if !os(tvOS)
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [UTType.deltaSkin],
            allowsMultipleSelection: true
        ) { result in
            Task {
                do {
                    let urls = try result.get()
                    try await importSkins(from: urls)
                } catch {
                    importError = error
                    showingImportError = true
                }
            }
        }
        #endif
        .retroAlert("Import Error",
                    message: importError?.localizedDescription ?? "Failed to import skin",
                    isPresented: $showingImportError) {
            Button("OK", role: .cancel) { }
        }
    }

    // MARK: - UI Components
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("CONTROLLER SKINS")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .padding(.top, 20)
                .shadow(color: RetroTheme.retroPink.opacity(glowIntensity * 0.5), radius: 3)
            
            Text("Select and customize your game controllers")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, RetroTheme.retroPink.opacity(0.3), .clear]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .blendMode(.overlay)
                )
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)
                        .blur(radius: 0.5)
                        .opacity(glowIntensity),
                    alignment: .bottom
                )
        )
    }
    
    private var loadingView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Retrowave styled loading indicator
            ZStack {
                Circle()
                    .stroke(
                        RetroTheme.retroHorizontalGradient,
                        lineWidth: 4
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 2 * glowIntensity)
                
                Circle()
                    .trim(from: 0, to: loadingProgress)
                    .stroke(
                        RetroTheme.retroHorizontalGradient,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 4)
                
                Text("\(Int(loadingProgress * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    loadingProgress = 1.0
                }
            }
            
            Text("LOADING SKINS")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .tracking(2)
            
            Spacer()
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(RetroTheme.retroGradient, lineWidth: 1)
                )
        )
        .padding(.top, 40)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 60))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 4)
                .padding(.bottom, 10)
            
            Text("NO SKINS FOUND")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .tracking(2)
            
            Text("Add controller skins to customize your gaming experience")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showingDocumentPicker = true
            } label: {
                Text("ADD SKINS")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(RetroTheme.retroGradient, lineWidth: 2)
                            )
                    )
                    .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 5)
            }
            
            Spacer()
        }
        .frame(height: 400)
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(RetroTheme.retroGradient, lineWidth: 1)
                )
        )
        .padding(.top, 40)
    }
    
    private var systemsGridView: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .regular ? 320 : 280), spacing: 20)],
            spacing: 24
        ) {
            ForEach(supportedSystems, id: \.self) { system in
                systemCard(system)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.top, 20)
    }
    
    private func systemCard(_ system: SystemIdentifier) -> some View {
        let skinCount = systemSkinCounts[system] ?? 0
        
        return NavigationLink(destination: SystemSkinSelectionView(system: system)) {
            VStack(alignment: .leading, spacing: 12) {
                // System header
                HStack {
                    Text(system.fullName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(skinCount)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(RetroTheme.retroGradient, lineWidth: 1)
                                )
                        )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Preview of selected skins for this system
                SystemSkinPreviewRow(system: system)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(RetroTheme.retroGradient, lineWidth: 1.5)
                    )
                    .shadow(color: RetroTheme.retroPurple.opacity(0.5), radius: 8)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Data Handling
    
    private var supportedSystems: [SystemIdentifier] {
        systemSkinCounts.filter { $0.value > 0 }.keys.sorted()
    }
    
    private func loadSkins() {
        Task {
            await reloadAllSkins()
        }
    }
    
    private func reloadAllSkins() async {
        await MainActor.run {
            isLoading = true
            loadingProgress = 0.1
        }
        
        // Simulate progress for better UX
        Task {
            for progress in stride(from: 0.1, to: 0.9, by: 0.1) {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    loadingProgress = progress
                }
            }
        }
        
        // Reload skins
        await skinManager.reloadSkins()
        
        // Get all available skins
        let allSkins = (try? await skinManager.availableSkins()) ?? []
        
        // Group by system
        var counts: [SystemIdentifier: Int] = [:]
        
        for skin in allSkins {
            if let system = skin.gameType.systemIdentifier {
                counts[system, default: 0] += 1
            }
        }
        
        // Final update
        await MainActor.run {
            self.systemSkinCounts = counts
            self.loadingProgress = 1.0
            
            // Slight delay before hiding loading screen for smoother transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func importSkins(from urls: [URL]) async throws {
        await MainActor.run {
            importingFiles = true
            importProgress = 0
        }
        
        for (index, url) in urls.enumerated() {
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                ELOG("Failed to start accessing security-scoped resource")
                throw DeltaSkinError.accessDenied
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            // Import the skin
            try await skinManager.importSkin(from: url)
            
            // Update progress
            let progress = Double(index + 1) / Double(urls.count)
            await MainActor.run {
                importProgress = progress
            }
        }
        
        // Reload after all imports
        await reloadAllSkins()
        
        await MainActor.run {
            importingFiles = false
        }
    }
}
