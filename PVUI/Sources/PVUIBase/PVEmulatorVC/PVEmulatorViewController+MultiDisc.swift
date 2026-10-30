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

        var actions = (1 ... numberOfDiscs).map { index in
            PVAlertAction("\(index)") { [unowned self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                    core.swapDisc(number: index)
                })

                // Disc swap is an intentional resume action — go through the proper
                // isShowingMenu setter so the didSet observer manages the pause state.
                self.isShowingMenu = false
                self.enableControllerInput(false)
            }
        }
        actions.append(.cancel(NSLocalizedString("Cancel", comment: "Cancel")) { [unowned self] in
            // Don't resume emulation here - the presenting menu handles that.
            self.enableControllerInput(false)
        })
        present(PVAlert(title: "Swap Disc", style: .actionSheet, actions: actions))
        Task {
            await PVControllerManager.shared.iCadeController?.refreshListener()
        }
    }
}
