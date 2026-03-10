import PVSupport
import PVEmulatorCore
import PVCoreBridge

extension PVEmulatorViewController {
    public func showSwapDiscsMenu() {
        guard let core = self.core as? (PVEmulatorCore & DiscSwappable) else {
            presentError("Internal error: No core found.", source: self.view)
            // Don't resume emulation here - the presenting menu handles that.
            enableControllerInput(false)
            return
        }

        let numberOfDiscs = core.numberOfDiscs
        guard numberOfDiscs > 1 else {
            presentError("Game only supports 1 disc.", source: self.view)
            // Don't resume emulation here - the presenting menu handles that.
            enableControllerInput(false)
            return
        }

        // Add action for each disc
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.popoverPresentationController?.barButtonItem = self.navigationItem.leftBarButtonItem
        actionSheet.popoverPresentationController?.sourceView = self.navigationItem.titleView ?? self.view
        if let menuButton = menuButton {
            actionSheet.popoverPresentationController?.sourceView = menuButton
            actionSheet.popoverPresentationController?.sourceRect = menuButton.bounds
        }
        for index in 1 ... numberOfDiscs {
            actionSheet.addAction(UIAlertAction(title: "\(index)", style: .default, handler: { [unowned self] _ in

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                    core.swapDisc(number: index)
                })

                // Disc swap is an intentional resume action — go through the proper
                // isShowingMenu setter so the didSet observer manages the pause state.
                self.isShowingMenu = false
                self.enableControllerInput(false)
            }))
        }

        // Add cancel action
        actionSheet.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: { [unowned self] _ in
            // Don't resume emulation here - the presenting menu handles that.
            self.enableControllerInput(false)
        }))

        // Present
#if targetEnvironment(macCatalyst) || os(macOS)
        actionSheet.popoverPresentationController?.sourceView = menuButton
        actionSheet.popoverPresentationController?.sourceRect = menuButton?.bounds ?? .zero
#else
        if traitCollection.userInterfaceIdiom == .pad {
            actionSheet.popoverPresentationController?.sourceView = menuButton
            actionSheet.popoverPresentationController?.sourceRect = menuButton?.bounds ?? .zero
        }
#endif

        present(actionSheet, animated: true) {
            Task.detached {
                await PVControllerManager.shared.iCadeController?.refreshListener()
            }
        }
    }
}
