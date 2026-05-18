///
/// RetroSaveSelectionAlertView.swift
/// Provenance
///
/// Save state selection alert with cloud sync support and inline download progress
/// Created by Joseph Mattiello on 12/29/25.
///

import SwiftUI
import PVThemes
import PVRealm
import PVLibrary
import PVLogging
import RealmSwift

// MARK: - Save Selection Item

/// Data model for save state selection with download status
public struct RetroSaveSelectionItem: Identifiable {
    public let id: String
    public let saveStateId: String
    public let title: String
    public let subtitle: String
    public let isDownloaded: Bool
    public let thumbnailURL: URL?
    public let date: Date
    public let isAutosave: Bool
    public let coreIdentifier: String
    public let coreName: String
    public let fileSize: Int

    public init(
        id: String = UUID().uuidString,
        saveStateId: String,
        title: String,
        subtitle: String,
        isDownloaded: Bool,
        thumbnailURL: URL?,
        date: Date,
        isAutosave: Bool,
        coreIdentifier: String,
        coreName: String,
        fileSize: Int = 0
    ) {
        self.id = id
        self.saveStateId = saveStateId
        self.title = title
        self.subtitle = subtitle
        self.isDownloaded = isDownloaded
        self.thumbnailURL = thumbnailURL
        self.date = date
        self.isAutosave = isAutosave
        self.coreIdentifier = coreIdentifier
        self.coreName = coreName
        self.fileSize = fileSize
    }

    /// Creates from a PVSaveState
    public init(from saveState: PVSaveState) {
        self.id = saveState.id
        self.saveStateId = saveState.id

        if saveState.isAutosave {
            self.title = "Auto-Save"
        } else if let desc = saveState.userDescription, !desc.isEmpty {
            self.title = desc
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            self.title = formatter.string(from: saveState.date)
        }

        let relativeDate = Self.relativeDate(from: saveState.date)
        self.subtitle = "\(saveState.core?.projectName ?? "Unknown") • \(relativeDate)"

        self.isDownloaded = saveState.isDownloaded
        self.thumbnailURL = saveState.image?.url
        self.date = saveState.date
        self.isAutosave = saveState.isAutosave
        self.coreIdentifier = saveState.core?.identifier ?? ""
        self.coreName = saveState.core?.projectName ?? "Unknown"
        self.fileSize = saveState.fileSize
    }

    private static func relativeDate(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Save Selection View Model

/// View model for managing save selection state and downloads
@MainActor
public class RetroSaveSelectionViewModel: ObservableObject {
    @Published public var saves: [RetroSaveSelectionItem] = []
    @Published public var downloadingItemId: String?
    @Published public var downloadProgress: Double = 0
    @Published public var downloadError: String?

    public let gameTitle: String
    public let coreName: String
    public let coreIdentifier: String

    private var downloadTask: Task<Void, Never>?
    private var downloadingRecordID: String?
    private var progressPollTask: Task<Void, Never>?

    public init(gameTitle: String, coreName: String, coreIdentifier: String, saves: [RetroSaveSelectionItem] = []) {
        self.gameTitle = gameTitle
        self.coreName = coreName
        self.coreIdentifier = coreIdentifier
        self.saves = saves
    }

    /// The most recent save state
    public var mostRecentSave: RetroSaveSelectionItem? {
        saves.first
    }

    /// Whether there are any saves to show
    public var hasSaves: Bool {
        !saves.isEmpty
    }

    /// Whether a download is in progress
    public var isDownloading: Bool {
        downloadingItemId != nil
    }

    private static let downloadTimeoutSeconds: UInt64 = 60

    /// Starts downloading a save state using the appropriate cloud syncer.
    /// On success, the completion receives a refreshed item with `isDownloaded = true`.
    public func startDownload(for item: RetroSaveSelectionItem, completion: @escaping (RetroSaveSelectionItem?) -> Void) {
        let actionStart = CFAbsoluteTimeGetCurrent()
        downloadingItemId = item.id
        downloadProgress = 0
        downloadError = nil

        downloadTask = Task {
            do {
                ILOG("[SaveSelection] Starting download for save state: \(item.saveStateId)")

                // Get the save state from Realm
                let realmInstance = try await Realm()
                guard let saveState = realmInstance.object(ofType: PVSaveState.self, forPrimaryKey: item.saveStateId) else {
                    throw NSError(domain: "RetroSaveSelection", code: 1, userInfo: [NSLocalizedDescriptionKey: "Save state not found in database"])
                }

                // Check if already downloaded
                if saveState.isDownloaded, let fileURL = saveState.file?.url,
                   FileManager.default.fileExists(atPath: fileURL.path) {
                    ILOG("[SaveSelection] Save state already downloaded locally: \(item.saveStateId)")
                    let refreshedItem = RetroSaveSelectionItem(from: saveState)
                    downloadingRecordID = nil
                    downloadingItemId = nil
                    downloadProgress = 0
                    completion(refreshedItem)
                    return
                }

                let recordID: String = {
                    if let cloudID = saveState.cloudRecordID, !cloudID.isEmpty {
                        return cloudID
                    }
                    return saveState.id
                }()
                downloadingRecordID = recordID

                // Start polling SyncProgressTracker for real download progress
                startProgressPolling(recordID: recordID)

                ILOG("[SaveSelection] Starting direct CloudSyncManager download after \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - actionStart))s (recordID=\(recordID))")
                let downloadStart = CFAbsoluteTimeGetCurrent()

                // Freeze on the Realm-owning thread BEFORE handing off to the
                // task group. Calling `.freeze()` from inside `addTask` crashes
                // with `verifyThread` because that closure runs on a different
                // executor than the Realm `saveState` is bound to.
                let frozenSaveState = saveState.freeze()

                // Download with timeout
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        try await CloudSyncManager.shared.downloadSaveState(for: frozenSaveState)
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: Self.downloadTimeoutSeconds * 1_000_000_000)
                        throw NSError(domain: "RetroSaveSelection", code: 3, userInfo: [NSLocalizedDescriptionKey: "Download timed out after \(Self.downloadTimeoutSeconds) seconds"])
                    }
                    // Wait for the first task to finish (download or timeout)
                    try await group.next()
                    // Cancel the remaining task
                    group.cancelAll()
                }

                ILOG("[SaveSelection] Direct download completed in \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - downloadStart))s (recordID=\(recordID))")

                stopProgressPolling()

                // Verify download completed by refreshing the save state
                let updatedRealm = try await Realm()
                if let updatedSaveState = updatedRealm.object(ofType: PVSaveState.self, forPrimaryKey: item.saveStateId),
                   updatedSaveState.isDownloaded,
                   let fileURL = updatedSaveState.file?.url,
                   FileManager.default.fileExists(atPath: fileURL.path) {
                    ILOG("[SaveSelection] Download complete for: \(item.saveStateId)")
                    downloadProgress = 1.0
                    let refreshedItem = RetroSaveSelectionItem(from: updatedSaveState)
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    downloadingRecordID = nil
                    downloadingItemId = nil
                    completion(refreshedItem)
                    downloadProgress = 0
                } else {
                    throw NSError(domain: "RetroSaveSelection", code: 2, userInfo: [NSLocalizedDescriptionKey: "File not available after download"])
                }
            } catch {
                ELOG("[SaveSelection] Download failed: \(error.localizedDescription)")
                stopProgressPolling()
                downloadError = error.localizedDescription
                downloadingRecordID = nil
                downloadingItemId = nil
                completion(nil)
            }
        }
    }

    /// Polls SyncProgressTracker for real-time download progress
    private func startProgressPolling(recordID: String) {
        stopProgressPolling()
        let kind = SyncProgressTracker.DownloadKind.saveState(recordID: recordID)
        progressPollTask = Task { @MainActor in
            while !Task.isCancelled {
                if let active = SyncProgressTracker.shared.activeDownloads.first(where: { $0.kind == kind }) {
                    let newProgress = active.progress
                    if newProgress > self.downloadProgress {
                        self.downloadProgress = newProgress
                    }
                }
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
        }
    }

    private func stopProgressPolling() {
        progressPollTask?.cancel()
        progressPollTask = nil
    }

    /// Cancels an in-progress download
    public func cancelDownload() {
        stopProgressPolling()
        downloadTask?.cancel()
        downloadTask = nil
        downloadingRecordID = nil
        downloadingItemId = nil
        downloadProgress = 0
    }

    deinit {
        progressPollTask?.cancel()
        downloadTask?.cancel()
    }
}

// MARK: - Save Selection Alert View

/// Alert view for selecting save states with cloud download support
public struct RetroSaveSelectionAlertView: View {
    @ObservedObject var viewModel: RetroSaveSelectionViewModel

    let showBackButton: Bool
    let onStartFresh: () -> Void
    let onSelectSave: (RetroSaveSelectionItem) -> Void
    let onBack: (() -> Void)?
    let onCancel: () -> Void

    @State private var glowOpacity: Double = 0.7

    #if os(tvOS)
    @FocusState private var focusedItemId: String?
    private let gridColumns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    #elseif os(iOS)
    /// Drives controller-nav focus on iOS. SwiftUI `@FocusState` is iOS 15+,
    /// which is well below the iOS 17 minimum target.
    @FocusState private var focusedItemId: String?
    /// Gamepad input bridge for iOS controller navigation of the save picker.
    @StateObject private var gamepadManager = GamepadManager.shared
    private let gridColumns = [GridItem(.flexible()), GridItem(.flexible())]
    #else
    private let gridColumns = [GridItem(.flexible()), GridItem(.flexible())]
    #endif

    // MARK: - Controller-nav focus IDs (iOS / tvOS)

    /// Stable focus identifier for the prominent "Quick Continue" tile.
    private static let quickContinueFocusID = "quick-continue"
    /// Stable focus identifier for the "Start Fresh" action.
    private static let startFreshFocusID = "start-fresh"
    /// Stable focus identifier for the "Back" action (only present when
    /// `showBackButton` is true).
    private static let backFocusID = "back"
    /// Stable focus identifier for the "Cancel" action.
    private static let cancelFocusID = "cancel"

    public init(
        viewModel: RetroSaveSelectionViewModel,
        showBackButton: Bool = false,
        onStartFresh: @escaping () -> Void,
        onSelectSave: @escaping (RetroSaveSelectionItem) -> Void,
        onBack: (() -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.showBackButton = showBackButton
        self.onStartFresh = onStartFresh
        self.onSelectSave = onSelectSave
        self.onBack = onBack
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerSection

            quickActionsSection

            if viewModel.saves.count > 1 {
                savesGridSection
            }

            footerSection
        }
        .frame(minWidth: 350, maxWidth: 600)
        .background(alertBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(alertBorder)
        .shadow(color: Color.retroPink.opacity(glowOpacity), radius: 20, x: 0, y: 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.3
            }
            #if os(tvOS) || os(iOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                focusedItemId = initialFocusID
            }
            #endif
            #if os(iOS)
            // Block sidebar / root / home gamepad subscribers from "leaking"
            // A and d-pad input through to the views behind this picker.
            GamepadManager.shared.isModalAlertPresented = true
            #endif
        }
        .onDisappear {
            #if os(iOS)
            GamepadManager.shared.isModalAlertPresented = false
            #endif
        }
        #if os(tvOS)
        .onExitCommand {
            if viewModel.isDownloading {
                viewModel.cancelDownload()
            } else if showBackButton {
                onBack?()
            } else {
                onCancel()
            }
        }
        #endif
        #if os(iOS)
        .onReceive(gamepadManager.eventPublisher) { event in
            guard gamepadManager.isControllerConnected else { return }
            switch event {
            case .verticalNavigation(let value, let isPressed):
                guard isPressed else { return }
                moveSelectionVertical(value: value)
            case .horizontalNavigation(let value, let isPressed):
                guard isPressed else { return }
                moveSelectionHorizontal(value: value)
            case .buttonPress(let isPressed):
                guard isPressed else { return }
                activateFocusedItem()
            case .buttonB(let isPressed):
                guard isPressed else { return }
                handleBackOrCancel()
            default:
                break
            }
        }
        #endif
    }

    /// First item that should receive focus when the picker appears.
    /// Prefers Quick Continue when there is a save; otherwise Start Fresh.
    private var initialFocusID: String {
        viewModel.mostRecentSave?.id ?? Self.startFreshFocusID
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.gameTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .shadow(color: Color.retroBlue.opacity(0.8), radius: 8, x: 0, y: 0)

            Text("Playing with \(viewModel.coreName)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            if viewModel.hasSaves {
                Text(verbatim: String.localizedStringWithFormat(NSLocalizedString("retro_save.saves_available", bundle: .module, comment: ""), viewModel.saves.count))
                    .font(.system(size: 12))
                    .foregroundColor(.retroBlue)
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            if let mostRecent = viewModel.mostRecentSave {
                quickContinueButton(for: mostRecent)
            }

            RetroAlertButton(
                title: "Start Fresh",
                style: .secondary,
                isExternallyFocused: isExternallyFocused(Self.startFreshFocusID)
            ) {
                onStartFresh()
            }
            #if os(tvOS) || os(iOS)
            .focused($focusedItemId, equals: Self.startFreshFocusID)
            #endif
        }
        .padding(.horizontal, 20)
        .padding(.bottom, viewModel.saves.count > 1 ? 16 : 20)
    }

    private func quickContinueButton(for save: RetroSaveSelectionItem) -> some View {
        Button {
            handleSaveSelection(save)
        } label: {
            HStack(spacing: 12) {
                // Screenshot thumbnail
                ZStack {
                    thumbnailView(for: save)

                    if !save.isDownloaded && viewModel.downloadingItemId != save.id {
                        cloudBadge
                    }

                    if viewModel.downloadingItemId == save.id {
                        downloadProgressOverlay
                    }
                }
                .frame(width: 80, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Label and metadata
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Continue")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Text(save.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)

                    if !save.isDownloaded && viewModel.downloadingItemId != save.id {
                        Text("☁️ Download required")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.retroBlue.opacity(0.9))
                    } else if viewModel.downloadingItemId == save.id {
                        downloadStatusText
                    }
                }

                Spacer()

                Image(systemName: "play.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.retroPink)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.retroPink.opacity(0.2), Color.retroBlue.opacity(0.15)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.retroPink.opacity(0.6), .retroBlue.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
        }
#if os(tvOS)
        .retroFocusableButton(
            focused: $focusedItemId,
            equals: save.id,
            focusScale: 1.03,
            cornerRadius: 10,
            glowRadius: 8,
            showBorder: false
        )
#elseif os(iOS)
        .focused($focusedItemId, equals: save.id)
        .overlay(controllerFocusRing(visible: focusedItemId == save.id, cornerRadius: 10))
#endif
    }

    @ViewBuilder
    private var downloadStatusText: some View {
        if viewModel.downloadProgress > 0 {
            Text("\(Int(viewModel.downloadProgress * 100))% downloaded")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [.retroPink, .retroBlue], startPoint: .leading, endPoint: .trailing)
                )
        } else {
            Text("Connecting...")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Saves Grid Section

    private var savesGridSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Other Saves")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                Text(verbatim: String.localizedStringWithFormat(NSLocalizedString("retro_save.more_saves", bundle: .module, comment: ""), viewModel.saves.count - 1))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(viewModel.saves.dropFirst()) { save in
                        saveGridItem(for: save)
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxHeight: 250)
        }
        .padding(.bottom, 16)
    }

    private func saveGridItem(for save: RetroSaveSelectionItem) -> some View {
        Button {
            handleSaveSelection(save)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    thumbnailView(for: save)

                    if !save.isDownloaded && viewModel.downloadingItemId != save.id {
                        cloudBadge
                    }

                    if viewModel.downloadingItemId == save.id {
                        downloadProgressOverlay
                    }
                }
                .frame(width: 80, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(spacing: 2) {
                    Text(save.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(save.subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        #if os(tvOS)
        .retroFocusableButton(
            focused: $focusedItemId,
            equals: save.id,
            focusScale: 1.05,
            cornerRadius: 8,
            glowRadius: 8,
            showBorder: false
        )
        #elseif os(iOS)
        .focused($focusedItemId, equals: save.id)
        .overlay(controllerFocusRing(visible: focusedItemId == save.id, cornerRadius: 8))
        #endif
    }

    private func thumbnailView(for save: RetroSaveSelectionItem) -> some View {
        Group {
            if let thumbnailURL = save.thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderThumbnail(autosave: save.isAutosave)
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    @unknown default:
                        placeholderThumbnail(autosave: save.isAutosave)
                    }
                }
            } else {
                placeholderThumbnail(autosave: save.isAutosave)
            }
        }
    }

    private func placeholderThumbnail(autosave: Bool) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color.retroBlack, Color.retroBlack.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: autosave ? "clock.arrow.circlepath" : "square.and.arrow.down")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var cloudBadge: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.retroBlue.opacity(0.9))
                    .clipShape(Circle())
            }
            Spacer()
        }
        .padding(4)
    }

    private var downloadProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)

            VStack(spacing: 4) {
                if viewModel.downloadProgress > 0 {
                    CircularProgressView(progress: viewModel.downloadProgress)
                        .frame(width: 24, height: 24)

                    Text("\(Int(viewModel.downloadProgress * 100))%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [.retroPink, .retroBlue], startPoint: .leading, endPoint: .trailing)
                        )
                } else {
                    RetroIndeterminateSpinner()
                        .frame(width: 24, height: 24)
                }
            }
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack(spacing: 12) {
            if showBackButton {
                RetroAlertButton(
                    title: "Back",
                    style: .secondary,
                    isExternallyFocused: isExternallyFocused(Self.backFocusID)
                ) {
                    onBack?()
                }
                #if os(tvOS) || os(iOS)
                .focused($focusedItemId, equals: Self.backFocusID)
                #endif
            }

            RetroAlertButton(
                title: "Cancel",
                style: .cancel,
                isExternallyFocused: isExternallyFocused(Self.cancelFocusID)
            ) {
                onCancel()
            }
            #if os(tvOS) || os(iOS)
            .focused($focusedItemId, equals: Self.cancelFocusID)
            #endif
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Helpers

    private func handleSaveSelection(_ save: RetroSaveSelectionItem) {
        if save.isDownloaded {
            onSelectSave(save)
        } else {
            viewModel.startDownload(for: save) { refreshedItem in
                if let refreshedItem {
                    onSelectSave(refreshedItem)
                }
            }
        }
    }

    /// Mirrors `focusedItemId` to a `RetroAlertButton`'s
    /// `isExternallyFocused` so the button paints its retrowave highlight when
    /// a controller drives focus. Returns `nil` on platforms that don't track
    /// focus state, letting the button fall back to system focus.
    private func isExternallyFocused(_ id: String) -> Bool? {
        #if os(tvOS) || os(iOS)
        return focusedItemId == id
        #else
        return nil
        #endif
    }

    // MARK: - iOS Controller Navigation

    #if os(iOS)
    /// Ordered list of focus IDs as they appear top-to-bottom in the picker.
    /// Used by d-pad vertical / grid navigation. Quick Continue (mostRecent)
    /// is followed by the remaining saves grid (if any), then Start Fresh,
    /// then Back (optional), then Cancel.
    private var orderedFocusIDs: [String] {
        var ids: [String] = []
        if let mostRecent = viewModel.mostRecentSave {
            ids.append(mostRecent.id)
        }
        if viewModel.saves.count > 1 {
            ids.append(contentsOf: viewModel.saves.dropFirst().map { $0.id })
        }
        ids.append(Self.startFreshFocusID)
        if showBackButton {
            ids.append(Self.backFocusID)
        }
        ids.append(Self.cancelFocusID)
        return ids
    }

    /// Number of grid columns used in the "other saves" section. Matches the
    /// `gridColumns` definition above for iOS.
    private var iosGridColumnCount: Int { 2 }

    /// Index ranges inside `orderedFocusIDs` for the grid items so that
    /// horizontal navigation can stay within a row.
    private var gridIndexRange: Range<Int>? {
        guard viewModel.saves.count > 1 else { return nil }
        let start = viewModel.mostRecentSave == nil ? 0 : 1
        let end = start + (viewModel.saves.count - 1)
        return start..<end
    }

    /// Moves focus vertically through the picker. Quick Continue, grid rows,
    /// Start Fresh, Back, and Cancel are all reachable via d-pad up/down.
    private func moveSelectionVertical(value: Float) {
        let ids = orderedFocusIDs
        guard !ids.isEmpty else { return }
        guard let current = focusedItemId, let idx = ids.firstIndex(of: current) else {
            focusedItemId = ids.first
            return
        }
        let isDown = value < 0
        if let gridRange = gridIndexRange, gridRange.contains(idx) {
            let stride = iosGridColumnCount
            let next = isDown ? idx + stride : idx - stride
            if gridRange.contains(next) {
                focusedItemId = ids[next]
                return
            }
            // Falling out of the grid: move to the next/previous non-grid item.
            if isDown {
                focusedItemId = ids[min(gridRange.upperBound, ids.count - 1)]
            } else {
                focusedItemId = ids[max(gridRange.lowerBound - 1, 0)]
            }
            return
        }
        let next = isDown ? idx + 1 : idx - 1
        guard next >= 0, next < ids.count else { return }
        focusedItemId = ids[next]
    }

    /// Horizontal navigation only matters inside the saves grid.
    private func moveSelectionHorizontal(value: Float) {
        guard let gridRange = gridIndexRange else { return }
        let ids = orderedFocusIDs
        guard let current = focusedItemId, let idx = ids.firstIndex(of: current),
              gridRange.contains(idx) else { return }
        let isRight = value > 0
        let next = isRight ? idx + 1 : idx - 1
        guard gridRange.contains(next) else { return }
        // Stay in the same grid row.
        let rowSize = iosGridColumnCount
        let currentRow = (idx - gridRange.lowerBound) / rowSize
        let nextRow = (next - gridRange.lowerBound) / rowSize
        guard currentRow == nextRow else { return }
        focusedItemId = ids[next]
    }

    /// Resolves the currently-focused tile to an action.
    private func activateFocusedItem() {
        guard let current = focusedItemId else {
            // Default: trigger Quick Continue if available, else Start Fresh.
            if let mostRecent = viewModel.mostRecentSave {
                handleSaveSelection(mostRecent)
            } else {
                onStartFresh()
            }
            return
        }
        switch current {
        case Self.startFreshFocusID:
            onStartFresh()
        case Self.backFocusID:
            onBack?()
        case Self.cancelFocusID:
            onCancel()
        default:
            if let save = viewModel.saves.first(where: { $0.id == current }) {
                handleSaveSelection(save)
            }
        }
    }

    /// B-button behavior: cancel an in-flight download, otherwise go Back
    /// (when available) or Cancel.
    private func handleBackOrCancel() {
        if viewModel.isDownloading {
            viewModel.cancelDownload()
        } else if showBackButton {
            onBack?()
        } else {
            onCancel()
        }
    }

    /// Pink/blue gradient ring drawn around the currently focused tile when
    /// a controller is connected. Mirrors the tvOS focus affordance without
    /// relying on the system focus engine.
    @ViewBuilder
    private func controllerFocusRing(visible: Bool, cornerRadius: CGFloat) -> some View {
        if visible && gamepadManager.isControllerConnected {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [.retroPink, .retroBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .shadow(color: .retroPink.opacity(0.7), radius: 6, x: 0, y: 0)
                .allowsHitTesting(false)
        }
    }
    #endif

    private var alertBackground: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.retroBlack,
                    Color.retroBlack.opacity(0.95)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            RetroAlertGridPattern()
                .opacity(0.2)
            RetroScanlineOverlay()
                .opacity(0.05)
        }
    }

    private var alertBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(
                    gradient: Gradient(colors: [.retroPink, .retroBlue]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [.retroPink, .retroBlue], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.2), value: progress)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RetroSaveSelectionAlertView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3)
                .edgesIgnoringSafeArea(.all)

            RetroSaveSelectionAlertView(
                viewModel: RetroSaveSelectionViewModel(
                    gameTitle: "Super Mario World",
                    coreName: "Snes9x",
                    coreIdentifier: "com.provenance.snes9x",
                    saves: [
                        RetroSaveSelectionItem(
                            saveStateId: "1",
                            title: "Auto-Save",
                            subtitle: "Snes9x • 2h ago",
                            isDownloaded: true,
                            thumbnailURL: nil,
                            date: Date(),
                            isAutosave: true,
                            coreIdentifier: "com.provenance.snes9x",
                            coreName: "Snes9x"
                        ),
                        RetroSaveSelectionItem(
                            saveStateId: "2",
                            title: "Before Boss",
                            subtitle: "Snes9x • 1d ago",
                            isDownloaded: false,
                            thumbnailURL: nil,
                            date: Date().addingTimeInterval(-86400),
                            isAutosave: false,
                            coreIdentifier: "com.provenance.snes9x",
                            coreName: "Snes9x"
                        ),
                        RetroSaveSelectionItem(
                            saveStateId: "3",
                            title: "World 2",
                            subtitle: "Snes9x • 3d ago",
                            isDownloaded: true,
                            thumbnailURL: nil,
                            date: Date().addingTimeInterval(-259200),
                            isAutosave: false,
                            coreIdentifier: "com.provenance.snes9x",
                            coreName: "Snes9x"
                        )
                    ]
                ),
                showBackButton: true,
                onStartFresh: { print("Start fresh") },
                onSelectSave: { save in print("Selected: \(save.title)") },
                onBack: { print("Back") },
                onCancel: { print("Cancel") }
            )
        }
    }
}
#endif
