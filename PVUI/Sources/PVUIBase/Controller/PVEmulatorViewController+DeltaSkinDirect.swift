import UIKit
import SwiftUI
import PVEmulatorCore
import PVLibrary

// MARK: - Direct Delta Skin Integration
extension PVEmulatorViewController {

    /// Setup method to be called directly from viewDidLoad
    func setupDeltaSkinDirectly() {
        Task {
            do {
                try await setupDeltaSkinView()
            } catch {
                print("Error setting up Delta Skin: \(error)")
            }
        }
    }
}
