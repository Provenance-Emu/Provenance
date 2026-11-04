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
    @FocusState private var focusedItemID: String?
    @Namespace private var sheetNamespace

    /// Drives `navigationDestination` for system selection rows.
    @State private var systemSelectionItemID: UUID?

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
                                    TVMediaImportQueueRow(
                                        item: item,
                                        focusedItemID: $focusedItemID,
                                        onChooseSystem: { systemSelectionItemID = item.id },
                                        onRemove: { remove(item) }
                                    )
                                }
                            }
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
            .navigationDestination(item: $systemSelectionItemID) { id in
                if let item = viewModel.importQueueItems.first(where: { $0.id == id }) {
                    SystemSelectionView(item: item, onSystemSelected: { _, queueItem in
                        Task { @MainActor in
                            await ImportQueueResolver.resumeProcessing(of: queueItem, with: gameImporter)
                        }
                    })
                } else {
                    Text("This import is no longer in the queue.")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    /// Deletes by id against the importer's own queue; the sheet's list is only a snapshot of it.
    private func remove(_ item: ImportQueueItem) {
        let importer = gameImporter
        let id = item.id
        Task {
            await ImportQueueResolver.remove(itemWithID: id, from: importer)
        }
    }

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
}

// MARK: - Import Queue Row

/// One queue entry: the row itself (a button that opens the system picker when the importer
/// could not place the file) and a delete button beside it.
///
/// Both are plain `Button`s that sit directly in the layout. The previous design opened a
/// `confirmationDialog` from a single row button and ran the chosen action as the dialog
/// dismissed; on tvOS that action could be dropped, and pushing the system picker from it
/// raced the dialog's own dismissal.
@available(tvOS 16.0, iOS 17.0, *)
private struct TVMediaImportQueueRow: View {
    /// Observed so the row follows the item's status as it is re-queued, processed or fails.
    @ObservedObject var item: ImportQueueItem
    var focusedItemID: FocusState<String?>.Binding
    let onChooseSystem: () -> Void
    let onRemove: () -> Void

    private var rowFocusID: String { item.id.uuidString }
    private var removeFocusID: String { "remove-\(item.id.uuidString)" }
    private var canChooseSystem: Bool { ImportQueueResolver.canChooseSystem(for: item) }

    var body: some View {
        HStack(spacing: 12) {
            if canChooseSystem {
                Button(action: onChooseSystem) {
                    rowContent
                }
                .buttonStyle(TVMediaCardButtonStyle())
                .tvOSDisableFocusEffect()
                .modifier(TVMediaImportRowChrome(isFocused: focusedItemID.wrappedValue == rowFocusID))
                .focused(focusedItemID, equals: rowFocusID)
            } else {
                rowContent
                    .modifier(TVMediaImportRowChrome(isFocused: false))
            }

            removeButton
        }
    }

    private var removeButton: some View {
        let isFocused = focusedItemID.wrappedValue == removeFocusID
        return Button(action: onRemove) {
            Image(systemName: "trash")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.retroPink)
                .frame(width: 72, height: 72)
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .tvOSDisableFocusEffect()
        .modifier(TVMediaImportRowChrome(isFocused: isFocused))
        .focused(focusedItemID, equals: removeFocusID)
    }

    private var rowContent: some View {
        HStack(spacing: 18) {
            statusIcon
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.url.lastPathComponent)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Text(statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(statusColor.opacity(0.9))

                    if let system = item.userChosenSystem ?? item.targetSystem() {
                        Text(verbatim: "→ \(system.rawValue)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }

            Spacer()

            if canChooseSystem {
                Text("Select System")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.retroBlue.opacity(0.7))
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))

            switch item.status {
            case .queued:
                Image(systemName: "clock")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(statusColor)
            case .processing, .extracting:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: statusColor))
                    .scaleEffect(0.7)
            case .success:
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(statusColor)
            case .failure:
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(statusColor)
            case .conflict:
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(statusColor)
            case .partial:
                Image(systemName: "hourglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(statusColor)
            }
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .queued: return .white.opacity(0.5)
        case .processing, .extracting: return Color.retroBlue
        case .success: return Color.retroGreen
        case .failure: return Color.retroPink
        case .conflict: return .orange
        case .partial: return .yellow
        }
    }

    private var statusText: String {
        switch item.status {
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

/// The retrowave card background and focus border shared by a row's controls.
private struct TVMediaImportRowChrome: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(isFocused ? 0.06 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isFocused ?
                        LinearGradient(
                            colors: [Color.retroPink.opacity(0.7), Color.retroBlue.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                            LinearGradient(
                                colors: [Color.clear, Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                        lineWidth: isFocused ? 2 : 0
                    )
            )
            .scaleEffect(isFocused ? 1.01 : 1.0)
            .animation(Animation.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
    }
}
