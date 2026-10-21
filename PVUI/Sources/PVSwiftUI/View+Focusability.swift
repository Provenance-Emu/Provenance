import SwiftUI

extension View {
    /// Enables focus on platforms that support the modifier.
    @ViewBuilder
    func focusableIfAvailable() -> some View {
        if #available(iOS 17, tvOS 17, *) {
            self.focusable(true)
        } else {
            self
        }
    }
}
