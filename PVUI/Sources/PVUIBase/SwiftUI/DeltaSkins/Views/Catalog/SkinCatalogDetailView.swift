//
//  SkinCatalogDetailView.swift
//  PVUIBase
//
//  Created for Provenance (GitHub issue #2545)
//

import SwiftUI
import PVLogging
import PVPrimitives
import PVSystems

/// Full-detail view for a single skin catalog entry.
///
/// Shows screenshots, metadata, and provides a "Download & Install" button
/// that downloads the `.deltaskin` file and installs it via `DeltaSkinManager`.
public struct SkinCatalogDetailView: View {

    // MARK: - Properties

    let entry: SkinCatalogEntry

    // MARK: - State

    @State private var downloadState: DownloadState = .idle
    @State private var screenshotIndex = 0
    @State private var glowIntensity: CGFloat = 0.5
    @State private var downloadTask: Task<Void, Never>?

    /// Observe the skin manager so we can detect already-installed skins.
    @StateObject private var skinManager = DeltaSkinManager.shared

    // MARK: - Types

    private enum DownloadState: Equatable {
        case idle
        case downloading(progress: Double)
        case installing
        case installed
        case failed(String)
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            RetroTheme.retroBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    screenshotSection
                    metadataSection
                    descriptionSection
                    statsSection
                    actionSection
                    systemTagsSection
                    if let tags = entry.tags, !tags.isEmpty {
                        tagsSection(tags)
                    }
                    sourceSection
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(entry.name)
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowIntensity = 0.8
            }
            // Check if this skin is already installed locally so the
            // action section shows "INSTALLED" instead of "DOWNLOAD".
            checkIfAlreadyInstalled()
        }
        .onChange(of: skinManager.skinsAreLoaded) { _, loaded in
            // Re-check once skins finish loading (scan may complete after
            // onAppear if it was triggered lazily).
            if loaded { checkIfAlreadyInstalled() }
        }
        .onDisappear {
            downloadTask?.cancel()
        }
    }

    // MARK: - Screenshot Section

    private var screenshotSection: some View {
        let screenshots: [URL] = {
            if let urls = entry.screenshotURLs, !urls.isEmpty {
                return urls
            }
            if let thumb = entry.thumbnailURL {
                return [thumb]
            }
            return []
        }()

        return Group {
            if !screenshots.isEmpty {
                TabView(selection: $screenshotIndex) {
                    ForEach(Array(screenshots.enumerated()), id: \.offset) { index, url in
                        screenshotCell(url: url)
                            .tag(index)
                    }
                }
                #if !os(tvOS)
                .tabViewStyle(.page(indexDisplayMode: screenshots.count > 1 ? .always : .never))
                #endif
                .frame(height: 280)
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .frame(height: 1)
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)
                        .opacity(glowIntensity * 0.6),
                    alignment: .bottom
                )
            } else {
                // Placeholder when no screenshots available
                ZStack {
                    Color.black.opacity(0.4)
                    VStack(spacing: 12) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(RetroTheme.retroHorizontalGradient)
                            .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 4)
                        Text("NO PREVIEW")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(2)
                    }
                }
                .frame(height: 200)
            }
        }
    }

    private func screenshotCell(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ZStack {
                    Color.black.opacity(0.4)
                    ProgressView()
                        .tint(RetroTheme.retroPink)
                }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            case .failure:
                ZStack {
                    Color.black.opacity(0.4)
                    Image(systemName: "photo.slash")
                        .font(.system(size: 30))
                        .foregroundColor(.white.opacity(0.3))
                }
            @unknown default:
                Color.black.opacity(0.4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
                    .shadow(color: RetroTheme.retroPink.opacity(glowIntensity * 0.4), radius: 2)

                Spacer()

                if let version = entry.version {
                    Text("v\(version)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                Text("by \(entry.author ?? "Unknown")")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    // MARK: - Description Section

    @ViewBuilder
    private var descriptionSection: some View {
        if let description = entry.description, !description.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader("DESCRIPTION")
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 16)
        }
    }

    // MARK: - Stats Section

    /// Dedicated stats section matching the design spec layout.
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("STATS")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statCard(
                    icon: "arrow.down.circle.fill",
                    value: entry.downloadCount.map { formatSkinDownloadCount($0) } ?? "—",
                    label: "Downloads"
                )
                statCard(
                    icon: "star.fill",
                    value: entry.rating.map { String(format: "%.1f", $0) } ?? "—",
                    label: "Rating"
                )
                statCard(
                    icon: "internaldrive",
                    value: entry.fileSize.map { formatFileSize($0) } ?? "—",
                    label: "Size"
                )
                statCard(
                    icon: "calendar",
                    value: entry.lastUpdated.map { formatDate($0) } ?? "—",
                    label: "Updated"
                )
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }

    /// A single stat card rendered inside the stats grid.
    private func statCard(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(label), \(value)"))
    }

    // MARK: - Action Section (Download & Install)

    private var actionSection: some View {
        VStack(spacing: 12) {
            switch downloadState {
            case .idle:
                downloadButton

            case .downloading(let progress):
                downloadProgressView(progress: progress)

            case .installing:
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(RetroTheme.retroPink)
                    Text("INSTALLING...")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(RetroTheme.retroHorizontalGradient)
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.5))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(RetroTheme.retroGradient, lineWidth: 1.5))
                )

            case .installed:
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(RetroTheme.retroHorizontalGradient)
                        Text("INSTALLED")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(RetroTheme.retroHorizontalGradient)
                            .tracking(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.5))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(RetroTheme.retroGradient, lineWidth: 1.5))
                    )
                    .shadow(color: RetroTheme.retroPink.opacity(0.4), radius: 6)

                    if let system = primarySystemIdentifier {
                        NavigationLink(destination: SystemSkinSelectionView(system: system)) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
                                Text("SET AS ACTIVE SKIN")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
                                    .tracking(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.black.opacity(0.4))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(RetroTheme.retroGradient, lineWidth: 1.5))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

            case .failed(let message):
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                        Text("DOWNLOAD FAILED")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                            .tracking(1)
                    }

                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)

                    downloadButton
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .animation(.easeInOut(duration: 0.3), value: downloadState)
    }

    private var downloadButton: some View {
        Button {
            downloadTask?.cancel()
            downloadTask = Task { await downloadAndInstall() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)

                Text("DOWNLOAD & INSTALL")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(RetroTheme.retroGradient, lineWidth: 2)
                    )
            )
            .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func downloadProgressView(progress: Double) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("DOWNLOADING...")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
                    .tracking(1)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.5))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(RetroTheme.retroGradient, lineWidth: 1))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(RetroTheme.retroHorizontalGradient)
                        .frame(width: geo.size.width * progress)
                        .shadow(color: RetroTheme.retroPink.opacity(0.8), radius: 4)
                        .animation(.linear(duration: 0.1), value: progress)
                }
            }
            .frame(height: 10)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.4))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(RetroTheme.retroGradient, lineWidth: 1))
                .padding(-8)
        )
        .padding(8)
    }

    // MARK: - System Tags Section

    private var systemTagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("SUPPORTED SYSTEMS")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(entry.systems.filter { !SkinCatalogService.isLegacySystemCode($0) }, id: \.self) { system in
                        Text(SystemIdentifier.displayName(forCatalogCode: system))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundColor(.white)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                                    .overlay(Capsule().strokeBorder(RetroTheme.retroGradient, lineWidth: 1))
                            )
                    }
                }
                .padding(.horizontal, 20)
            }

            // Device support
            if let devices = entry.deviceSupport, !devices.isEmpty {
                HStack(spacing: 12) {
                    ForEach(devices, id: \.self) { device in
                        HStack(spacing: 4) {
                            Image(systemName: deviceIcon(for: device))
                                .font(.system(size: 12))
                                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                            Text(device.capitalized)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 24)
    }

    private func tagsSection(_ tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("TAGS")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 11, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundColor(.white.opacity(0.7))
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.4))
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
                            )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 16)
    }

    private var sourceSection: some View {
        Group {
            if let source = entry.source, !source.isEmpty,
               let sourceURL = resolvedSourceURL(from: source) {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("SOURCE")

                    #if !os(tvOS)
                    Link(destination: sourceURL) {
                        HStack {
                            Image(systemName: "safari.fill")
                                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                            Text(source)
                                .font(.system(size: 13))
                                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(RetroTheme.retroHorizontalGradient)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.4))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(RetroTheme.retroGradient, lineWidth: 1))
                        )
                    }
                    .padding(.horizontal, 20)
                    #else
                    Text(source)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 20)
                    #endif
                }
                .padding(.top, 16)
            }
        }
    }

    /// Resolves a source string into a valid HTTP(S) URL, prepending `https://` for bare domains.
    private func resolvedSourceURL(from source: String) -> URL? {
        // Trim whitespace/newlines first to avoid constructing malformed URLs.
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed) {
            if let scheme = url.scheme?.lowercased() {
                // Only allow explicit http/https schemes.
                if scheme == "http" || scheme == "https" {
                    return url
                } else {
                    // Reject non-HTTP(S) schemes (e.g. mailto:, ftp:).
                    return nil
                }
            }
        }

        // No scheme present: treat as bare domain and prepend https://.
        return URL(string: "https://\(trimmed)")
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(2)
            .foregroundColor(.white.opacity(0.4))
            .padding(.horizontal, 20)
    }

    // MARK: - System Identifier

    /// Resolves the primary `SystemIdentifier` from the catalog entry's system codes.
    private var primarySystemIdentifier: SystemIdentifier? {
        // Try gameTypeIdentifier first (most specific)
        if let gameTypeId = entry.gameTypeIdentifier,
           let gameType = DeltaSkinGameType.fromAnyString(gameTypeId) {
            return gameType.systemIdentifier
        }
        // Fall back to the first short code in entry.systems
        return entry.systems.lazy.compactMap {
            DeltaSkinGameType.fromAnyString($0)?.systemIdentifier
        }.first
    }

    // MARK: - Installed Check

    /// Sets `downloadState` to `.installed` when the catalog entry matches a
    /// locally installed skin. Uses the same multi-strategy matching as the
    /// browser grid (identifier, filename, name).
    private func checkIfAlreadyInstalled() {
        // Only override when we haven't already started a download/install.
        guard downloadState == .idle else { return }

        let skins = skinManager.loadedSkins
        guard !skins.isEmpty else { return }

        let isInstalled: Bool = {
            // 1. Identifier match
            if skins.contains(where: { $0.identifier == entry.id }) { return true }

            // 2. Filename match
            let catalogStem = entry.downloadURL.deletingPathExtension().lastPathComponent.lowercased()
            if !catalogStem.isEmpty,
               skins.contains(where: { $0.fileURL.deletingPathExtension().lastPathComponent.lowercased() == catalogStem }) {
                return true
            }

            // 3. Name match (case-insensitive)
            let nameLower = entry.name.lowercased()
            if skins.contains(where: { $0.name.lowercased() == nameLower }) { return true }

            return false
        }()

        if isInstalled {
            downloadState = .installed
        }
    }

    // MARK: - Download & Install Logic

    private func downloadAndInstall() async {
        guard !Task.isCancelled else { return }

        await MainActor.run {
            downloadState = .downloading(progress: 0)
        }

        do {
            // Download the skin file with progress
            let localURL = try await downloadSkin()
            defer { try? FileManager.default.removeItem(at: localURL) }

            // Check for cancellation before proceeding to install
            guard !Task.isCancelled else {
                await MainActor.run { downloadState = .idle }
                return
            }

            // Install via DeltaSkinManager
            await MainActor.run {
                downloadState = .installing
            }

            try await DeltaSkinManager.shared.importSkin(from: localURL)

            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    downloadState = .installed
                }
            }

            ILOG("SkinCatalogDetailView: Successfully installed skin '\(entry.name)'")
        } catch {
            guard !Task.isCancelled else {
                await MainActor.run { downloadState = .idle }
                return
            }
            ELOG("SkinCatalogDetailView: Failed to install skin '\(entry.name)': \(error)")
            await MainActor.run {
                downloadState = .failed(error.localizedDescription)
            }
        }
    }

    /// Downloads the skin file to a temporary location using URLSessionDownloadTask for efficiency.
    private func downloadSkin() async throws -> URL {
        let downloadURL = entry.downloadURL
        let fileName = downloadURL.lastPathComponent.isEmpty
            ? "\(entry.id).deltaskin"
            : downloadURL.lastPathComponent
        let destURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = SkinDownloadDelegate(
                destURL: destURL,
                progressHandler: { progress in
                    Task { @MainActor in
                        downloadState = .downloading(progress: progress)
                    }
                },
                completion: { result in
                    continuation.resume(with: result)
                }
            )
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            delegate.session = session
            session.downloadTask(with: downloadURL).resume()
        }
    }

    // MARK: - URLSessionDownloadDelegate helper

    private final class SkinDownloadDelegate: NSObject, URLSessionDownloadDelegate {
        /// Destination URL for the downloaded file. The file is moved here in didFinishDownloadingTo.
        private let destURL: URL
        private let progressHandler: (Double) -> Void
        private let completion: (Result<URL, Error>) -> Void
        /// Stored so the session can be invalidated after completion to prevent leaks.
        var session: URLSession?
        private var moveError: Error?

        init(destURL: URL, progressHandler: @escaping (Double) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
            self.destURL = destURL
            self.progressHandler = progressHandler
            self.completion = completion
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                        didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                        totalBytesExpectedToWrite: Int64) {
            guard totalBytesExpectedToWrite > 0 else { return }
            progressHandler(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                        didFinishDownloadingTo location: URL) {
            // The file at `location` is deleted by the system when this method returns.
            // We must move it to a persistent location here before returning.
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: location, to: destURL)
            } catch {
                moveError = error
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            defer { self.session?.finishTasksAndInvalidate() }
            if let error = error {
                completion(.failure(error))
                return
            }
            if let http = task.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            if let moveError = moveError {
                completion(.failure(moveError))
                return
            }
            completion(.success(destURL))
        }
    }

    // MARK: - Helpers

    private func formatFileSize(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_048_576.0
        if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        }
        let kb = Double(bytes) / 1_024.0
        return String(format: "%.0f KB", kb)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func deviceIcon(for device: String) -> String {
        switch device.lowercased() {
        case "iphone": return "iphone"
        case "ipad":   return "ipad"
        case "tv":     return "appletv"
        default:       return "display"
        }
    }
}
