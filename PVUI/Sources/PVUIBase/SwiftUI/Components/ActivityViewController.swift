#if !os(tvOS)
import SwiftUI
import UIKit

/// A SwiftUI wrapper for UIActivityViewController
public struct ActivityViewController: UIViewControllerRepresentable {
    /// The items to share
    var activityItems: [Any]
    /// Optional custom activities
    var applicationActivities: [UIActivity]? = nil
    /// Activity types to exclude from the share sheet
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil
    
    public init(activityItems: [Any], applicationActivities: [UIActivity]? = nil, excludedActivityTypes: [UIActivity.ActivityType]? = nil) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
        self.excludedActivityTypes = excludedActivityTypes
    }

    public func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}
#endif
