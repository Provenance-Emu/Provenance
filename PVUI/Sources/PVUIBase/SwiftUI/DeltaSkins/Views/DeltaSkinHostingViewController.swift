import SwiftUI
import UIKit
import PVEmulatorCore
import PVLibrary

/// A custom hosting view controller for Delta skins
class DeltaSkinHostingViewController: UIViewController {
    private var hostingController: UIViewController

    // Factory method to create an instance without generic type inference issues
    static func create(game: PVGame, core: PVEmulatorCore, inputHandler: DeltaSkinInputHandler, onSkinLoaded: @escaping () -> Void, onRefreshRequested: @escaping () -> Void, onMenuRequested: @escaping () -> Void) -> DeltaSkinHostingViewController {
        return DeltaSkinHostingViewController(
            game: game,
            core: core,
            inputHandler: inputHandler,
            onSkinLoaded: onSkinLoaded,
            onRefreshRequested: onRefreshRequested,
            onMenuRequested: onMenuRequested
        )
    }

    init(game: PVGame, core: PVEmulatorCore, inputHandler: DeltaSkinInputHandler, onSkinLoaded: @escaping () -> Void, onRefreshRequested: @escaping () -> Void, onMenuRequested: @escaping () -> Void) {
        // Create the wrapper view
        let wrapperView = EmulatorWrapperView(
            game: game,
            coreInstance: core,
            onSkinLoaded: onSkinLoaded,
            onRefreshRequested: onRefreshRequested,
            onMenuRequested: onMenuRequested,
            inputHandler: inputHandler
        )

        // Create the hosting controller
        let hostingController = UIHostingController(rootView: wrapperView)
        self.hostingController = hostingController

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure the hosting controller
        addChild(hostingController)

        // Configure the hosting controller's view
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.view.backgroundColor = .clear

        // Add the hosting controller's view as a subview
        view.addSubview(hostingController.view)

        // Finish adding the hosting controller
        hostingController.didMove(toParent: self)
    }
}
