//
//  TVMediaImportStatusSheet.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/6/26.
//

import SwiftUI
import Combine
import PVUIBase
import PVThemes
import PVLibrary
import PVFeatureFlags
import PVHelp
import RealmSwift
import PVRealm
import PVPrimitives
import PVSystems
import PVLogging

#if canImport(PVWebServer)
import PVWebServer
#endif

// MARK: - Import Status Sheet (Full Screen)

/// Full import queue management sheet with tvOS styling
@available(tvOS 16.0, iOS 17.0, *)
struct TVMediaImportStatusSheet: View {
    let gameImporter: any GameImporting
    @ObservedObject var updatesController: PVGameLibraryUpdatesController
    let onDismiss: () -> Void

    @StateObject private var viewModel: ImportProgressViewModel
    @Namespace private var sheetNamespace

    /// Drives `navigationDestination` for system selection rows.
    @State private var systemSelectionItemID: UUID?

    /// Unified focus target — lives in the parent so focus survives row deletion.
    enum FocusTarget: Hashable {
        case row(UUID)
        case delete(UUID)
    }
    @FocusState private var focusTarget: FocusTarget?

    init(gameImporter: any GameImporting, updatesController: PVGameLibraryUpdatesController, onDismiss: @escaping () -> Void) {
        self.gameImporter = gameImporter
        self.updatesController = updatesController
        self.onDismiss = onDismiss
        self._viewModel = StateObject(wrappedValue: ImportProgressViewModel(gameImporter: gameImporter, updatesController: updatesController))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                TVMediaBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    header
                        .padding(.horizontal, 60)
                        .padding(.top, 50)
                        .padding(.bottom, 30)

                    // Content
                    if viewModel.importQueueItems.isEmpty && !viewModel.isSyncing {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // iCloud sync status
                                if viewModel.isSyncing {
                                    iCloudSyncCard
                                }

                                // Import queue items
                                ForEach(viewModel.importQueueItems) { item in
                                    importItemRow(item)
                                        .transition(.opacity.combined(with: .move(edge: .leading)))
                                }
                            }
                            .animation(.easeInOut(duration: 0.25), value: viewModel.importQueueItems.map(\.id))
                            .padding(.horizontal, 60)
                            .padding(.bottom, 60)
                        }
                        .tvMediaFocusSection()
                    }
                }
            }
            .tvMediaFocusScope(sheetNamespace)
            .tvMediaOnExitCommand {
                onDismiss()
            }
            #if os(tvOS)
            .navigationDestination(item: $systemSelectionItemID) { id in
                systemSelectionDestination(for: id)
            }
            #endif
        }
    }

    /// Handle system selection from SystemSelectionView.
    /// SystemSelectionView already sets `item.userChosenSystem`; we just kick off processing.
    private func handleSystemSelection(_ system: SystemIdentifier, for item: ImportQueueItem) {
        if gameImporter.processingState == .idle {
            gameImporter.startProcessing()
        }
    }

    #if os(tvOS)
    @ViewBuilder
    private func systemSelectionDestination(for id: UUID) -> some View {
        if let item = viewModel.importQueueItems.first(where: { $0.id == id }) {
            SystemSelectionView(item: item, onSystemSelected: { system, queueItem in
                handleSystemSelection(system, for: queueItem)
            })
        } else {
            Text("THIS IMPORT IS NO LONGER IN THE QUEUE")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.retroBlue)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    #endif

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("tv_media.import_queue.title", bundle: .module)
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .tracking(2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.retroBlue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.retroPink.opacity(0.5), radius: 10)

                if !viewModel.importQueueItems.isEmpty {
                    Text(verbatim: String.localizedStringWithFormat(NSLocalizedString("tv_media.import_queue.files_in_queue", bundle: .module, comment: ""), viewModel.importQueueItems.count))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer()

            // Close button
            Button(action: onDismiss) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                    Text("tv_media.import_queue.close", bundle: .module)
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(Color.retroPink)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.retroPink, Color.retroBlue.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
            }
            .buttonStyle(TVMediaCardButtonStyle())
            .tvOSDisableFocusEffect()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Color.retroBlue.opacity(0.6))
                .shadow(color: Color.retroBlue.opacity(0.4), radius: 12)

            Text("tv_media.import_queue.no_pending", bundle: .module)
                .font(.system(size: 22, weight: .bold, design: .default))
                .tracking(2)
                .foregroundStyle(.white)

            Text("tv_media.import_queue.all_processed", bundle: .module)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var iCloudSyncCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.retroBlue)
                    .shadow(color: Color.retroBlue.opacity(0.5), radius: 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text("tv_media.icloud_sync.title", bundle: .module)
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .tracking(1.5)
                        .foregroundStyle(.white)

                    Text(viewModel.iCloudStatusMessage.isEmpty ? "Syncing with iCloud..." : viewModel.iCloudStatusMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }

                Spacer()

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.retroBlue))
            }

            if let progress = viewModel.initialSyncProgress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [Color.retroBlue, Color.retroPink.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, geo.size.width * CGFloat(progress.overallProgress)), height: 6)
                            .shadow(color: Color.retroBlue.opacity(0.5), radius: 4)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.retroBlue.opacity(0.4), Color.retroPink.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
    }

    /// Whether this item needs user intervention to pick a system.
    /// Only true for genuine system conflicts (multiple systems matched) — not for
    /// artwork failures, BIOS mismatches, or files that simply aren't ROMs.
    private func needsSystemSelection(_ item: ImportQueueItem) -> Bool {
        guard item.userChosenSystem == nil else { return false }
        // Only game/cdRom/unknown file types can have system conflicts
        switch item.fileType {
        case .artwork, .bios, .skin, .patch, .folder:
            return false
        default:
            break
        }
        switch item.status {
        case .conflict:
            // Conflict specifically means multiple systems matched
            return item.systems.count > 1
        case .partial:
            let ext = item.url.pathExtension.lowercased()
            return ext == "cue" || ext == "m3u"
        default:
            return false
        }
    }

    /// Row content (status icon + file info) — shared between the button label and plain display.
    @ViewBuilder
    private func importItemContent(_ item: ImportQueueItem) -> some View {
        HStack(spacing: 18) {
            // Status icon
            statusIcon(for: item.status)
                .frame(width: 36, height: 36)

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.url.lastPathComponent)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Text(statusText(for: item.status))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(statusColor(for: item.status).opacity(0.9))

                    if let system = item.targetSystem() {
                        Text(verbatim: "→ \(system.rawValue)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }

            Spacer()

            // Show "Select System" hint inline when conflict
            if needsSystemSelection(item) {
                Text("SELECT SYSTEM →")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.retroBlue.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    /// Each import row: a focusable Button for the row content + a delete button beside it.
    /// Siri Remote up/down scrolls rows; left/right moves between row and delete.
    @ViewBuilder
    private func importItemRow(_ item: ImportQueueItem) -> some View {
        ImportItemRowView(
            item: item,
            focusTarget: $focusTarget,
            needsSystemSelection: needsSystemSelection(item),
            onSelectSystem: { systemSelectionItemID = item.id },
            onDelete: { deleteItem(item) },
            content: { importItemContent(item) }
        )
    }

    /// Delete an item and move focus to the adjacent row so it doesn't vanish.
    private func deleteItem(_ item: ImportQueueItem) {
        let items = viewModel.importQueueItems
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        // Pick the next row to focus — prefer the row below, fall back to above
        let nextFocusID: UUID? = {
            if index + 1 < items.count {
                return items[index + 1].id
            } else if index > 0 {
                return items[index - 1].id
            }
            return nil
        }()

        // Set focus to the next row *before* the removal so SwiftUI has a valid
        // target while the ForEach re-evaluates. The .animation on LazyVStack
        // handles the visual transition.
        if let nextID = nextFocusID {
            focusTarget = .row(nextID)
        }

        Task {
            await gameImporter.removeImports(at: IndexSet(integer: index))
        }
    }

    @ViewBuilder
    private func statusIcon(for status: ImportQueueItem.ImportStatus) -> some View {
        ZStack {
            Circle()
                .fill(statusColor(for: status).opacity(0.15))

            switch status {
            case .queued:
                Image(systemName: "clock")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(statusColor(for: status))
            case .processing, .extracting:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: statusColor(for: status)))
                    .scaleEffect(0.7)
            case .success:
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(statusColor(for: status))
            case .failure, .conflict:
                Image(systemName: status == .conflict ? "exclamationmark.triangle" : "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(statusColor(for: status))
            case .partial:
                Image(systemName: "hourglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(statusColor(for: status))
            }
        }
    }

    private func statusColor(for status: ImportQueueItem.ImportStatus) -> Color {
        switch status {
        case .queued: return .white.opacity(0.5)
        case .processing, .extracting: return Color.retroBlue
        case .success: return Color.retroGreen
        case .failure: return Color.retroPink
        case .conflict: return .orange
        case .partial: return .yellow
        }
    }

    private func statusText(for status: ImportQueueItem.ImportStatus) -> String {
        switch status {
        case .queued: return "Queued"
        case .processing: return "Processing..."
        case .extracting: return "Extracting..."
        case .success: return "Imported"
        case .failure(let error): return error.localizedDescription
        case .conflict: return "Needs system selection"
        case .partial(let expectedFiles): return "Waiting for \(expectedFiles.count) files"
        }
    }
}

// MARK: - Import Item Row (parent-owned focus)

/// Row view that binds to the parent's `FocusState` so focus survives row
/// deletion. Siri Remote up/down scrolls rows; left/right moves between
/// the row button and the delete button within a single row.
@available(tvOS 16.0, iOS 17.0, *)
private struct ImportItemRowView<Content: View>: View {
    let item: ImportQueueItem
    var focusTarget: FocusState<TVMediaImportStatusSheet.FocusTarget?>.Binding
    let needsSystemSelection: Bool
    let onSelectSystem: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    private var isRowFocused: Bool { focusTarget.wrappedValue == .row(item.id) }
    private var isDeleteFocused: Bool { focusTarget.wrappedValue == .delete(item.id) }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Main row button — pressing Select navigates to system picker (if needed)
            Button(action: {
                if needsSystemSelection {
                    onSelectSystem()
                }
            }) {
                content()
                    .contentShape(Rectangle())
            }
            .buttonStyle(TVMediaCardButtonStyle())
            .focused(focusTarget, equals: .row(item.id))
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(isRowFocused ? 0.06 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isRowFocused ?
                            LinearGradient(
                                colors: [Color.retroPink.opacity(0.7), Color.retroBlue.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: isRowFocused ? 2 : 1
                    )
            )
            .scaleEffect(isRowFocused ? 1.02 : 1.0)
            .tvOSDisableFocusEffect()
            .frame(maxWidth: .infinity, alignment: .leading)

            // Delete button — right of the row
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.retroPink)
                    .shadow(color: Color.retroPink.opacity(isDeleteFocused ? 0.8 : 0.3), radius: isDeleteFocused ? 6 : 2)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.7))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.retroPink, Color.retroPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isDeleteFocused ? 3.0 : 1.5
                            )
                            .shadow(color: Color.retroPink.opacity(isDeleteFocused ? 0.8 : 0.3), radius: isDeleteFocused ? 8 : 3)
                    )
            }
            .buttonStyle(TVMediaCardButtonStyle())
            .focused(focusTarget, equals: .delete(item.id))
            .scaleEffect(isDeleteFocused ? 1.08 : 1.0)
            .tvOSDisableFocusEffect()
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isRowFocused)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isDeleteFocused)
    }
}
