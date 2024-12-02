import SwiftUI

/// Observable object to track app icon changes
class IconManager: ObservableObject {
    static let shared = IconManager()

    @Published var currentIconName: String? {
        didSet {
            /// Update UI when icon changes
            objectWillChange.send()
        }
    }

    private init() {
        /// Initialize with current icon name
        currentIconName = UIApplication.shared.alternateIconName

        /// Setup notification observer for icon changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iconDidChange),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func iconDidChange() {
        /// Update current icon name when app becomes active
        currentIconName = UIApplication.shared.alternateIconName
    }
}
