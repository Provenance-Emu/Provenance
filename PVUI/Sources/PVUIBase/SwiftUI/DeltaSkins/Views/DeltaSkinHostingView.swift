import SwiftUI
import UIKit

/// A custom hosting view for Delta skins to avoid generic type inference issues
class DeltaSkinHostingView: UIView {
    private var hostingController: UIViewController

    init<Content: View>(rootView: Content) {
        // Create a hosting controller with the root view
        let hostingController = UIHostingController(rootView: rootView)
        self.hostingController = hostingController

        // Initialize with the hosting controller's view frame
        super.init(frame: hostingController.view.frame)

        // Configure the hosting controller's view
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        // Add the hosting controller's view as a subview
        addSubview(hostingController.view)

        // Set up constraints to fill the view
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hostingController.view.frame = bounds
    }
}
