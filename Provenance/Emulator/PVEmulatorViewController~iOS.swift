//
//  PVEmulatorViewController~iOS.swift
//  Provenance
//
//  Created by Joseph Mattiello on 7/20/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import Foundation
import PVLibrary
import PVSupport
import UIKit
import XLActionController

extension UIColor {
    func lighter(by percentage: CGFloat = 30.0) -> UIColor? {
        return adjust(by: abs(percentage))
    }

    func darker(by percentage: CGFloat = 30.0) -> UIColor? {
        return adjust(by: -1 * abs(percentage))
    }

    func adjust(by percentage: CGFloat = 30.0) -> UIColor? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            return UIColor(red: min(r + percentage / 100, 1.0),
                           green: min(g + percentage / 100, 1.0),
                           blue: min(b + percentage / 100, 1.0),
                           alpha: a)
        } else {
            return nil
        }
    }
}

public final class EmulatorActionCell: ActionCell {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override func awakeFromNib() {
        super.awakeFromNib()
        initialize()
    }

    func initialize() {
        backgroundColor = Theme.currentTheme.settingsCellBackground?.withAlphaComponent(0.3)
        let backgroundView = UIView()
        backgroundView.backgroundColor = backgroundColor
        selectedBackgroundView = backgroundView
    }
}

// public class EmulatorHeader: UICollectionReusableView {
//
//	lazy var label: UILabel = UILabel()
//
//	public override init(frame: CGRect) {
//		super.init(frame: frame)
//		addSubview(label)
//	}
//
//	required public init?(coder aDecoder: NSCoder) {
//		fatalError("init(coder:) has not been implemented")
//	}
// }

open class EmulatorActionController: DynamicsActionController<EmulatorActionCell, String, UICollectionReusableView, (), UICollectionReusableView, ()> {
    fileprivate lazy var blurView: UIVisualEffectView = {
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blurView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        blurView.alpha = 0.75
        return blurView
    }()

    public override init(nibName nibNameOrNil: String? = nil, bundle nibBundleOrNil: Bundle? = nil) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        settings.animation.present.options = [.allowUserInteraction]
        settings.animation.present.duration = 0.5

        //		settings.animation.dismiss.options = [.curveEaseIn, .transitionCurlUp]
        settings.animation.dismiss.duration = 0.5

        settings.animation.scale = nil // Don't shrink the game view
        settings.animation.present.springVelocity = 0.0
        settings.animation.present.damping = 1.0

        settings.behavior.bounces = false
        settings.behavior.useDynamics = true
        // I wrote a custom version of this to make sure we call our cancel callback
        settings.behavior.hideOnTap = false
        settings.behavior.hideOnScrollDown = true
        settings.behavior.scrollEnabled = true

        settings.cancelView.showCancel = true
        settings.cancelView.hideCollectionViewBehindCancelView = true
        settings.cancelView.title = "Resume"

        collectionView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 6.0, right: 0.0)
        (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 24.0, right: 0.0)

        sectionHeaderSpec = .cellClass(height: { _ in 24 })

        // Call cancel function on tap of empty space

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(EmulatorActionController.tappedOut))
        collectionView.backgroundView = UIView(frame: collectionView.bounds)
        collectionView.backgroundView?.isUserInteractionEnabled = true
        collectionView.backgroundView?.addGestureRecognizer(tapRecognizer)

        //		if !self.settings.behavior.scrollEnabled {
        //			let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(EmulatorActionController.tappedOut))
        //			swipeGesture.direction = .down
        //			collectionView.addGestureRecognizer(swipeGesture)
        //		}

        // providing a specific view that will render the action sheet header. We calculate its height according the text that should be displayed.
        //		headerSpec = .cellClass(height: { [weak self] _ -> CGFloat in
        //			guard let me = self else { return 0 }
        //			let label = UILabel(frame: CGRect(x: 0, y: 0, width: me.view.frame.width - 40, height: CGFloat.greatestFiniteMagnitude))
        //			label.numberOfLines = 1
        //			label.font = UIFont.preferredFont(forTextStyle: .callout)
        //			label.textColor = UIColor.white
        //			label.text = "PAUSED"
        //			label.sizeToFit()
        //			return label.frame.size.height + 20
        //		})

        //		onConfigureHeader = { [weak self] header, headerData in
        //			guard let me = self else { return }
        //			header.label.frame = CGRect(x: 0, y: 0, width: me.view.frame.size.width - 40, height: CGFloat.greatestFiniteMagnitude)
        //			header.label.text = "PAUSED"
        //			header.label.sizeToFit()
        //			header.label.center = CGPoint(x: header.frame.size.width  / 2, y:header.frame.size.height / 2)
        //		}

        cellSpec = .nibFile(nibName: "EmulatorActionCell", bundle: Bundle(for: EmulatorActionCell.self), height: { _ in 50 })

        onConfigureCellForAction = { [weak self] cell, action, indexPath in

            cell.setup(action.data, detail: nil, image: nil)
            let actions = self?.sectionForIndex(indexPath.section)?.actions
            let actionsCount = actions?.count ?? 0
            cell.separatorView?.isHidden = indexPath.section > 0

            //			let cellBackground = Theme.currentTheme.settingsCellBackground!
            //			cell.backgroundColor = action.style == .cancel ? cellBackground : cellBackground.lighter(by: 30)
            cell.alpha = action.enabled ? 1.0 : 0.5

            switch action.style {
            case .destructive:
                cell.actionTitleLabel?.textColor = UIColor(red: 210 / 255.0, green: 77 / 255.0, blue: 56 / 255.0, alpha: 1.0)
            case .default:
                cell.actionTitleLabel?.textColor = Theme.currentTheme.settingsCellText
            case .cancel:
                cell.actionTitleLabel?.textColor = Theme.currentTheme.defaultTintColor
            }

            var corners = UIRectCorner()
            if indexPath.item == 0 {
                corners = [.topLeft, .topRight]
            }
            if indexPath.item == actionsCount - 1 {
                corners = corners.union([.bottomLeft, .bottomRight])
            }

            if corners == .allCorners {
                cell.layer.mask = nil
                cell.layer.cornerRadius = 8.0
            } else {
                let borderMask = CAShapeLayer()
                borderMask.frame = cell.bounds
                borderMask.path = UIBezierPath(roundedRect: cell.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: 8.0, height: 8.0)).cgPath
                cell.layer.mask = borderMask
            }
        }

        // block used to setup the section header
        //		onConfigureSectionHeader = { [weak self] sectionHeader, sectionHeaderData in
        //			guard let me = self else { return }
        //			sectionHeader.frame = CGRect(x: 0, y: 0, width: me.view.frame.size.width - 40, height: 80)
        //		}
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        backgroundView.addSubview(blurView)

        cancelView?.frame.origin.y = view.bounds.size.height // Starts hidden below screen
        cancelView?.layer.shadowColor = UIColor.black.cgColor
        cancelView?.layer.shadowOffset = CGSize(width: 0, height: -4)
        cancelView?.layer.shadowRadius = 2
        cancelView?.layer.shadowOpacity = 0.8
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        blurView.frame = backgroundView.bounds
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    open override func createCancelView() -> UIView {
        let cancelView = super.createCancelView()
        let button = cancelView.subviews.compactMap { $0 as? UIButton }.first!
        button.addTarget(self, action: #selector(EmulatorActionController.cancelTapped), for: .touchUpInside)
        return cancelView
    }

    var cancelBlock: (() -> Void)?

    @objc
    func tappedOut() {
        dismiss { [weak self] in
            self?.cancelBlock?()
        }
    }

    @objc
    func cancelTapped() {
        //		self.dismiss { [weak self] in
        cancelBlock?()
        //		}
    }

    open override func performCustomDismissingAnimation(_ presentedView: UIView, presentingView: UIView) {
        super.performCustomDismissingAnimation(presentedView, presentingView: presentingView)
        cancelView?.frame.origin.y = view.bounds.size.height + 10
    }

    //	open override func onWillPresentView() {
    //		collectionView.frame.origin.y = CGFloat(25)
    //	}
}

extension PVEmulatorViewController {
    @objc func showMenu(_: Any?) {
        enableContorllerInput(true)
        core.setPauseEmulation(true)
        isShowingMenu = true

        let actionSheet = EmulatorActionController()

        if traitCollection.userInterfaceIdiom == .pad {
            actionSheet.popoverPresentationController?.sourceView = menuButton
            actionSheet.popoverPresentationController?.sourceRect = menuButton!.bounds
        }

        if PVControllerManager.shared.iCadeController != nil {
            actionSheet.addAction(Action("Disconnect iCade", style: .default) { _ in
                NotificationCenter.default.post(name: .GCControllerDidDisconnect, object: PVControllerManager.shared.iCadeController)
                self.core.setPauseEmulation(false)
                self.isShowingMenu = false
                self.enableContorllerInput(false)
            })
        }

        if core is CoreOptional {
            actionSheet.addAction(Action("Core Options", style: .default, handler: { _ in
                self.showCoreOptions()
            }))
        }

        let controllerManager = PVControllerManager.shared
        let wantsStartSelectInMenu: Bool = PVEmulatorConfiguration.systemIDWantsStartAndSelectInMenu(game.system.identifier)
        var hideP1MenuActions = false
        if let player1 = controllerManager.player1 {
            #if os(iOS)
                if PVSettingsModel.shared.missingButtonsAlwaysOn {
                    hideP1MenuActions = true
                }
            #endif
            if player1.extendedGamepad != nil || wantsStartSelectInMenu, !hideP1MenuActions {
                // left trigger bound to Start
                // right trigger bound to Select
                actionSheet.addAction(Action("P1 Start", style: .default, handler: { _ in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressStart(forPlayer: 0)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: { () -> Void in
                        self.controllerViewController?.releaseStart(forPlayer: 0)
                    })
                    self.enableContorllerInput(false)
                }))
                actionSheet.addAction(Action("P1 Select", style: .default, handler: { _ in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressSelect(forPlayer: 0)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: { () -> Void in
                        self.controllerViewController?.releaseSelect(forPlayer: 0)
                    })
                    self.enableContorllerInput(false)
                }))
            }
            if player1.extendedGamepad != nil || wantsStartSelectInMenu {
                actionSheet.addAction(Action("P1 AnalogMode", style: .default, handler: { _ in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressAnalogMode(forPlayer: 0)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: { () -> Void in
                        self.controllerViewController?.releaseAnalogMode(forPlayer: 0)
                    })
                    self.enableContorllerInput(false)
                }))
            }
        }
        if let player2 = controllerManager.player2 {
            if player2.extendedGamepad != nil || wantsStartSelectInMenu {
                actionSheet.addAction(Action("P2 Start", style: .default, handler: { _ in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressStart(forPlayer: 1)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: { () -> Void in
                        self.controllerViewController?.releaseStart(forPlayer: 1)
                    })
                    self.enableContorllerInput(false)
                }))
                actionSheet.addAction(Action("P2 Select", style: .default, handler: { _ in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressSelect(forPlayer: 1)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: { () -> Void in
                        self.controllerViewController?.releaseSelect(forPlayer: 1)
                    })
                    self.enableContorllerInput(false)
                }))
                actionSheet.addAction(Action("P2 AnalogMode", style: .default, handler: { _ in
                    self.core.setPauseEmulation(false)
                    self.isShowingMenu = false
                    self.controllerViewController?.pressAnalogMode(forPlayer: 1)
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: { () -> Void in
                        self.controllerViewController?.releaseAnalogMode(forPlayer: 1)
                    })
                    self.enableContorllerInput(false)
                }))
            }
        }
        if let swappableCore = core as? DiscSwappable, swappableCore.currentGameSupportsMultipleDiscs {
            actionSheet.addAction(Action("Swap Disc", style: .default, handler: { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                    self.showSwapDiscsMenu()
                })
            }))
        }

        if let actionableCore = core as? CoreActions, let actions = actionableCore.coreActions {
            actions.forEach { coreAction in
                actionSheet.addAction(Action(coreAction.title, style: .default, handler: { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                        actionableCore.selected(action: coreAction)
                        self.core.setPauseEmulation(false)
                        if coreAction.requiresReset {
                            self.core.resetEmulation()
                        }
                        self.isShowingMenu = false
                        self.enableContorllerInput(false)
                    })
                }))
            }
        }
        #if os(iOS)
            actionSheet.addAction(Action("Save Screenshot", style: .default, handler: { _ in
                self.perform(#selector(self.takeScreenshot), with: nil, afterDelay: 0.1)
            }))
        #endif
        actionSheet.addAction(Action("Game Info", style: .default, handler: { _ in
            let sb = UIStoryboard(name: "Provenance", bundle: nil)
            let moreInfoViewContrller = sb.instantiateViewController(withIdentifier: "gameMoreInfoVC") as? PVGameMoreInfoViewController
            moreInfoViewContrller?.game = self.game
            moreInfoViewContrller?.showsPlayButton = false
            moreInfoViewContrller?.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.hideModeInfo))
            let newNav = UINavigationController(rootViewController: moreInfoViewContrller ?? UIViewController())
            self.present(newNav, animated: true) { () -> Void in }
            self.isShowingMenu = false
            self.enableContorllerInput(false)
        }))
        actionSheet.addAction(Action("Game Speed", style: .default, handler: { _ in
            self.perform(#selector(self.showSpeedMenu), with: nil, afterDelay: 0.1)
        }))
        if core.supportsSaveStates {
            actionSheet.addAction(Action("Save States", style: .default, handler: { _ in
                self.perform(#selector(self.showSaveStateMenu), with: nil, afterDelay: 0.1)
            }))
        }
        actionSheet.addAction(Action("Reset", style: .default, handler: { _ in
            if PVSettingsModel.shared.autoSave, self.core.supportsSaveStates {
                self.autoSaveState { result in
                    switch result {
                    case .success:
                        break
                    case let .error(error):
                        ELOG("Auto-save failed \(error.localizedDescription)")
                    }
                }
            }
            self.core.setPauseEmulation(false)
            self.core.resetEmulation()
            self.isShowingMenu = false
            self.enableContorllerInput(false)
        }))

        let lastPlayed = game.lastPlayed ?? Date()
        var shouldSave = PVSettingsModel.shared.autoSave
        shouldSave = shouldSave && abs(lastPlayed.timeIntervalSinceNow) > minimumPlayTimeToMakeAutosave
        shouldSave = shouldSave && (game.lastAutosaveAge ?? minutes(2)) > minutes(1)
        shouldSave = shouldSave && abs(game.saveStates.sorted(byKeyPath: "date", ascending: true).last?.date.timeIntervalSinceNow ?? minutes(2)) > minutes(1)

        // Add Non-Saving quit first
        let quitTitle = shouldSave ? "Quit (without save)" : "Quit"
        actionSheet.addAction(Action(quitTitle, style: shouldSave ? .default : .destructive, handler: { _ in
            self.quit(optionallySave: false)
        }))

        // If save and quit is an option, add it last with different style
        if shouldSave {
            actionSheet.addAction(Action("Save & Quit", style: .destructive, handler: { _ in
                self.quit(optionallySave: true)
            }))
        }

        actionSheet.cancelBlock = {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.core.setPauseEmulation(false)
                self.isShowingMenu = false
                self.enableContorllerInput(false)
            }
        }

        present(actionSheet, animated: true, completion: { () -> Void in
            PVControllerManager.shared.iCadeController?.refreshListener()
        })
    }

    //	override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
    //		super.dismiss(animated: flag, completion: completion)
    //	}
}
