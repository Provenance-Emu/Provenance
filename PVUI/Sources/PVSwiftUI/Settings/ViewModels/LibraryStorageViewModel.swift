//
//  LibraryStorageViewModel.swift
//  PVSwiftUI
//
//  State for Settings › Library › Storage Location: pick → inspect → confirm → move → relaunch, plus the
//  recovery actions when the picked folder is unavailable. tvOS has no folder picker; the view is iOS-only.
//

#if !os(tvOS)
import Foundation
import Observation
import PVLibrary

@MainActor
@Observable
final class LibraryStorageViewModel {
    enum Step: Equatable {
        case idle
        case inspecting
        case confirming(LibraryFolderInspection, LibraryMovePreview)
        case moving(LibraryMoveProgress)
        case relaunchRequired
        case failed(String)
    }

    private(set) var step: Step = .idle
    /// "Also move saves" in the confirmation sheet. Forced to the source folder's value when leaving a picked folder (D11).
    var includeSaves = false
    let location = LibraryLocation.current
    let launchAxis = LibraryLocation.launchAxis
    let launchState = LibraryLocation.pickedFolderAtLaunch
    let folder = PickedLibraryFolderStore.shared.load()
    private(set) var hasPendingMove = LibraryMoveCoordinator.shared.hasPendingMove
    private var pendingURL: URL?
    private var runID = UUID()

    /// Picked-folder moves are refused while iCloud Drive mode is on (phase 5) and from the App Group (D11).
    var canChooseFolder: Bool { location == .appStorage || location == .pickedFolder }
    var canMoveToAppStorage: Bool { location == .appGroup || location == .pickedFolder }
    var includeSavesIsLocked: Bool { launchAxis == .pickedFolder }

    var locationTitle: String {
        switch location {
        case .appStorage: return "App storage"
        case .appGroup: return "App Group (legacy)"
        case .iCloudDrive: return "iCloud Drive"
        case .pickedFolder: return folder?.displayName ?? "Chosen folder"
        }
    }

    var locationDetail: String {
        switch location {
        case .pickedFolder:
            if case .unavailable(let reason) = launchState { return "Unavailable: \(reason)" }
            return launchState.url?.path ?? ""
        case .iCloudDrive: return "Turn off iCloud Drive mode in Cloud Sync Settings to choose a folder."
        case .appGroup: return "Move to App storage first to choose a folder."
        case .appStorage: return "On My iPhone › Provenance"
        }
    }

    // MARK: - Pick → inspect → confirm

    func folderPicked(_ url: URL) {
        step = .inspecting
        if includeSavesIsLocked { includeSaves = folder?.includesSaves ?? false }
        let saves = includeSaves
        Task.detached(priority: .userInitiated) {
            do {
                let inspection = try LibraryFolderInspector().inspect(url)
                let preview = try LibraryMoveCoordinator.shared.preview(destinationRoot: inspection.url, includeSaves: saves)
                await MainActor.run {
                    // The picker's own URL, not `inspection.url`: it is the one security-scoped access was started on.
                    self.pendingURL = url
                    self.step = .confirming(inspection, preview)
                }
            } catch {
                await MainActor.run { self.step = .failed(error.localizedDescription) }
            }
        }
    }

    func refreshPreview() {
        guard case .confirming(let inspection, _) = step else { return }
        let saves = includeSaves
        Task.detached(priority: .userInitiated) {
            let preview = try? LibraryMoveCoordinator.shared.preview(destinationRoot: inspection.url, includeSaves: saves)
            await MainActor.run {
                if let preview, case .confirming = self.step { self.step = .confirming(inspection, preview) }
            }
        }
    }

    /// Leaves the confirmation sheet. Does nothing once the move has started.
    func dismissConfirmation() {
        guard case .confirming = step else { return }
        pendingURL = nil
        step = .idle
    }

    /// The user dismissed a failure or relaunch alert.
    func acknowledge() {
        switch step {
        case .failed, .relaunchRequired:
            pendingURL = nil
            step = .idle
        default:
            break
        }
    }

    /// Starts the move (or the join when the folder already has a manifest).
    func confirmMove() {
        guard case .confirming(let inspection, _) = step, let url = pendingURL else { return }
        let saves = includeSaves
        let deduplicate = inspection.hasManifest
        run { progress in
            try await LibraryMoveCoordinator.shared.moveToPickedFolder(url, displayName: url.lastPathComponent, includeSaves: saves,
                                                                       deduplicate: deduplicate, progress: progress)
        }
    }

    func moveToAppStorage() {
        run { progress in try await LibraryMoveCoordinator.shared.moveToAppStorage(progress: progress) }
    }

    func cancel() {
        LibraryMoveCoordinator.shared.cancelRunningMove()
    }

    private func run(_ move: @escaping @Sendable (@escaping @Sendable (LibraryMoveProgress) -> Void) async throws -> LibraryMoveOutcome) {
        let token = UUID()
        runID = token
        step = .moving(LibraryMoveProgress(phase: .copying, filesDone: 0, filesTotal: 0, bytesDone: 0, bytesTotal: 0))
        Task { @MainActor in
            do {
                let outcome = try await move { report in
                    Task { @MainActor in
                        if self.runID == token { self.step = .moving(report) }
                    }
                }
                runID = UUID()
                hasPendingMove = LibraryMoveCoordinator.shared.hasPendingMove
                switch outcome {
                case .switched: step = .relaunchRequired
                case .cancelled: step = .failed("Move cancelled. Nothing was changed.")
                case .cleanedUp: step = .idle
                }
            } catch {
                runID = UUID()
                hasPendingMove = LibraryMoveCoordinator.shared.hasPendingMove
                step = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Recovery (folder unavailable at launch)

    /// Checks the new folder off the main thread, then points the library at it. Returns the resulting step so a caller
    /// without the storage view (the launch alert) can tell whether a relaunch is now due.
    @discardableResult
    func rebind(to url: URL) async -> Step {
        step = .inspecting
        let result = await Task.detached(priority: .userInitiated) { () -> Step in
            do {
                _ = try LibraryFolderInspector().inspect(url)
                try LibraryMoveCoordinator.shared.rebindPickedFolder(to: url, displayName: url.lastPathComponent)
                return .relaunchRequired
            } catch {
                return .failed(error.localizedDescription)
            }
        }.value
        step = result
        return result
    }

    @discardableResult
    func abandon() -> Step {
        do {
            try LibraryMoveCoordinator.shared.abandonPickedFolder()
            step = .relaunchRequired
        } catch {
            step = .failed(error.localizedDescription)
        }
        return step
    }
}
#endif
