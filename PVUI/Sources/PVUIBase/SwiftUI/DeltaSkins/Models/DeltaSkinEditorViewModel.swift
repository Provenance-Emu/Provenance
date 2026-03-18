import SwiftUI
import PVLogging

/// View model managing the state of the skin button position editor.
///
/// Tracks per-button frame overrides (in mappingSize units) and
/// coordinates export of a patched .deltaskin archive.
final class DeltaSkinEditorViewModel: ObservableObject {
    // MARK: - State

    let skin: any DeltaSkinProtocol
    private(set) var traits: DeltaSkinTraits

    /// Modified frames keyed by button index (mappingSize-unit coordinates).
    @Published var modifiedFrames: [Int: CGRect] = [:]
    /// Index of the currently selected button, or nil if none selected.
    @Published var selectedButtonIndex: Int? = nil
    /// True while export is in progress.
    @Published var isExporting = false
    /// URL of the successfully exported skin file, triggers share sheet.
    @Published var exportedURL: URL? = nil
    /// Non-nil when export fails.
    @Published var exportError: Error? = nil
    /// True when changes have been made but not yet exported.
    var hasChanges: Bool { !modifiedFrames.isEmpty }

    // MARK: - Accessors

    var buttons: [DeltaSkinButton] {
        skin.buttons(for: traits) ?? []
    }

    var mappingSize: CGSize {
        skin.mappingSize(for: traits) ?? CGSize(width: 414, height: 896)
    }

    // MARK: - Init

    init(skin: any DeltaSkinProtocol, traits: DeltaSkinTraits) {
        self.skin = skin
        self.traits = traits
    }

    // MARK: - Frame helpers

    /// Returns the current effective frame for button at `index`.
    func frameForButton(at index: Int) -> CGRect {
        modifiedFrames[index] ?? buttons[safe: index]?.frame ?? .zero
    }

    /// Whether button at `index` has been modified from the original.
    func isModified(at index: Int) -> Bool {
        modifiedFrames[index] != nil
    }

    // MARK: - Editing

    /// Translate button at `index` by a screen-space delta, given the current
    /// scale factor from mappingSize → view coordinates.
    func moveButton(at index: Int, screenDelta: CGSize, scale: CGFloat) {
        guard scale > 0 else { return }
        let current = frameForButton(at: index)
        let mappingDX = screenDelta.width / scale
        let mappingDY = screenDelta.height / scale
        let newFrame = CGRect(
            x: current.minX + mappingDX,
            y: current.minY + mappingDY,
            width: current.width,
            height: current.height
        )
        applyFrame(newFrame, for: index)
    }

    /// Directly set the frame for a button (in mappingSize units).
    func setFrame(_ frame: CGRect, for index: Int) {
        applyFrame(frame, for: index)
    }

    private func applyFrame(_ frame: CGRect, for index: Int) {
        let originalFrame = buttons[safe: index]?.frame ?? .zero
        if frame == originalFrame {
            modifiedFrames.removeValue(forKey: index)
        } else {
            modifiedFrames[index] = frame
        }
    }

    /// Revert a single button to its original skin-defined frame.
    func resetButton(at index: Int) {
        modifiedFrames.removeValue(forKey: index)
    }

    /// Revert all modifications and deselect.
    func resetAll() {
        modifiedFrames.removeAll()
        selectedButtonIndex = nil
    }

    /// Update the active traits (e.g. when display type changes in the preview).
    /// Clears any pending modifications since they are specific to the previous traits.
    func updateTraits(_ newTraits: DeltaSkinTraits) {
        guard newTraits != traits else { return }
        traits = newTraits
        modifiedFrames.removeAll()
        selectedButtonIndex = nil
    }

    // MARK: - Selection

    func selectButton(at index: Int) {
        selectedButtonIndex = index
    }

    func clearSelection() {
        selectedButtonIndex = nil
    }

    // MARK: - Export

    func exportSkin() {
        isExporting = true
        exportError = nil
        // Snapshot values to avoid capturing self in a background task
        let skin = self.skin
        let traits = self.traits
        let modifiedFrames = self.modifiedFrames
        Task.detached {
            do {
                let url = try await DeltaSkinExporter.export(
                    skin: skin,
                    traits: traits,
                    modifiedFrames: modifiedFrames
                )
                await MainActor.run {
                    self.exportedURL = url
                    self.isExporting = false
                }
            } catch {
                ELOG("DeltaSkinEditor: export failed — \(error)")
                await MainActor.run {
                    self.exportError = error
                    self.isExporting = false
                }
            }
        }
    }
}

