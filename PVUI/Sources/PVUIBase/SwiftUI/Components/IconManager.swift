import SwiftUI

/// Observable object to track app icon changes
public class IconManager: ObservableObject {
    public static let shared = IconManager()

    @Published public var currentIconName: String? {
        didSet {
            /// Update UI when icon changes
            objectWillChange.send()
        }
    }
    
    @Published public var isChangingIcon = false
    @Published public var lastError: String? = nil

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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Change the app icon and update the state
    public func changeIcon(to iconName: String?) {
        // Don't change if it's already the current icon
        if iconName == currentIconName {
            return
        }
        
        isChangingIcon = true
        lastError = nil
        
        UIApplication.shared.setAlternateIconName(iconName) { [weak self] error in
            DispatchQueue.main.async {
                self?.isChangingIcon = false
                
                if let error = error {
                    self?.lastError = error.localizedDescription
                    print("Error changing app icon: \(error.localizedDescription)")
                } else {
                    self?.currentIconName = iconName
                }
            }
        }
    }

    @objc private func iconDidChange() {
        /// Update current icon name when app becomes active
        let newIconName = UIApplication.shared.alternateIconName
        if newIconName != currentIconName {
            currentIconName = newIconName
        }
    }
}
