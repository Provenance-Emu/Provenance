import SwiftUI
#if os(iOS)
import UIKit

/// Gives the responsive settings columns a page-sized sheet on iPad.
struct SettingsSheetSizing: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18, *), UIDevice.current.userInterfaceIdiom == .pad {
            content.presentationSizing(.page)
        } else {
            content
        }
    }
}
#endif
