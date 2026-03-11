import Foundation
import PVRealm
#if canImport(UIKit)
import UIKit
#endif

/// Describes how a save-state launch should proceed after compatibility checks.
enum SaveStateLoadMismatchDecision {
    case loadAnyway
    case startWithoutSave
    case cancel
}

public extension PVSaveState {
    /// Returns `true` when the save state was created with a different known core version.
    func hasCoreVersionMismatch(comparedTo core: PVCore) -> Bool {
        guard let savedVersion = normalizedCoreVersion(createdWithCoreVersion),
              let currentVersion = normalizedCoreVersion(core.projectVersion) else {
            return false
        }

        return savedVersion != currentVersion
    }

    /// Builds a user-facing warning for a save state created with a different core version.
    func coreVersionMismatchWarning(comparedTo core: PVCore) -> (title: String, message: String)? {
        guard hasCoreVersionMismatch(comparedTo: core),
              let savedVersion = normalizedCoreVersion(createdWithCoreVersion),
              let currentVersion = normalizedCoreVersion(core.projectVersion) else {
            return nil
        }

        let title = "Save State Version Mismatch"
        let message =
            """
            This save state was created with \(core.projectName) \(savedVersion), but the active core is \(currentVersion).

            Loading can fail or leave the game in a broken state after a core update.

            Load anyway only if you are comfortable with the risk.
            """

        return (title, message)
    }

    /// Normalizes stored core-version strings so legacy empty or unknown values do not trigger warnings.
    private func normalizedCoreVersion(_ version: String?) -> String? {
        guard let trimmed = version?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              trimmed.caseInsensitiveCompare("unknown") != .orderedSame else {
            return nil
        }

        return trimmed
    }
}

#if canImport(UIKit)
public extension UIViewController {
    /// Prompts before loading a save state created with a different core version.
    @MainActor
    func confirmSaveStateLoadIfNeeded(_ saveState: PVSaveState, currentCore: PVCore, allowsStartWithoutSave: Bool) async -> SaveStateLoadMismatchDecision {
        guard let warning = saveState.coreVersionMismatchWarning(comparedTo: currentCore) else {
            return .loadAnyway
        }

        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: warning.title, message: warning.message, preferredStyle: .alert)
            var hasResumed = false

            let resumeOnce: (SaveStateLoadMismatchDecision) -> Void = { decision in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: decision)
            }

            alert.addAction(UIAlertAction(title: "Load Anyway", style: .default) { _ in
                resumeOnce(.loadAnyway)
            })

            if allowsStartWithoutSave {
                alert.addAction(UIAlertAction(title: "Start Without Save", style: .default) { _ in
                    resumeOnce(.startWithoutSave)
                })
            }

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                resumeOnce(.cancel)
            })

            present(alert, animated: true)
        }
    }
}
#endif
