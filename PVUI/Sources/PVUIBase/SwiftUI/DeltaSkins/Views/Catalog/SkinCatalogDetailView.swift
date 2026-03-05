//
//  SkinCatalogDetailView.swift
//  PVUIBase
//
//  Created for Provenance (GitHub issue #2545)
//

import SwiftUI
import PVLogging

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
        }
        .onDisappear {
            downloadTask?.cancel()
        }
    }

    // MARK: - Screenshot Section

    private var screenshotSection: some View {
        let screenshots = entry.screenshotURLs ?? (entry.thumbnailURL.map { [$0] } ?? [])

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
        VStack(alignment: .leading, spacing: 16) {
            // Title and author
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
                    .shadow(color: RetroTheme.retroPink.opacity(glowIntensity * 0.4), radius: 2)

                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    Text(entry.author)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Stats row
            HStack(spacing: 20) {
                if let rating = entry.rating {
                    statItem(icon: "star.fill", value: String(format: "%.1f", rating), label: "Rating")
                }
                if let downloads = entry.downloadCount, downloads > 0 {
                    statItem(icon: "arrow.down.circle.fill", value: formatCount(downloads), label: "Downloads")
                }
                if let size = entry.fileSize {
                    statItem(icon: "internaldrive", value: formatFileSize(size), label: "Size")
                }
                if let version = entry.version {
                    statItem(icon: "tag.fill", value: version, label: "Version")
                }
                if let updated = entry.lastUpdated {
                    statItem(icon: "calendar", value: formatDate(updated), label: "Updated")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
        }
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
                    ForEach(entry.systems, id: \.self) { system in
                        Text(system.uppercased())
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
               let sourceURL = URL(string: source), sourceURL.scheme?.hasPrefix("http") == true {
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(2)
            .foregroundColor(.white.opacity(0.4))
            .padding(.horizontal, 20)
    }

    // MARK: - Download & Install Logic

    private func downloadAndInstall() async {
        await MainActor.run {
            downloadState = .downloading(progress: 0)
        }

        do {
            // Download the skin file with progress
            let localURL = try await downloadSkin()
            defer { try? FileManager.default.removeItem(at: localURL) }

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
                progressHandler: { [self] progress in
                    Task { @MainActor in
                        downloadState = .downloading(progress: progress)
                    }
                },
                completion: { result in
                    switch result {
                    case .success(let location):
                        do {
                            if FileManager.default.fileExists(atPath: destURL.path) {
                                try FileManager.default.removeItem(at: destURL)
                            }
                            try FileManager.default.moveItem(at: location, to: destURL)
                            continuation.resume(returning: destURL)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            )
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            session.downloadTask(with: downloadURL).resume()
        }
    }

    // MARK: - URLSessionDownloadDelegate helper

    private final class SkinDownloadDelegate: NSObject, URLSessionDownloadDelegate {
        private let progressHandler: (Double) -> Void
        private let completion: (Result<URL, Error>) -> Void
        private var downloadedURL: URL?

        init(progressHandler: @escaping (Double) -> Void, completion: @escaping (Result<URL, Error>) -> Void) {
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
            downloadedURL = location
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                completion(.failure(error))
                return
            }
            if let http = task.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            guard let url = downloadedURL else {
                completion(.failure(URLError(.unknown)))
                return
            }
            completion(.success(url))
        }
    }

    // MARK: - Helpers

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000 {
            return String(format: "%.1fk", Double(count) / 1_000.0)
        }
        return "\(count)"
    }

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
