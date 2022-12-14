//
//  PVSaveStateCollectionViewCell.swift
//  Provenance
//
//  Created by James Addyman on 30/03/2018.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import PVLibrary
import PVSupport
import RealmSwift
import UIKit

private let LabelHeight: CGFloat = 20.0

final class PVSaveStateCollectionViewCell: UICollectionViewCell {
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        return df
    }()

    private static let timeFormatter: DateFormatter = {
        let tf = DateFormatter()
        tf.timeStyle = .short
        return tf
    }()
    
    var saveStateView = false

    @IBOutlet var imageView: UIImageView!
    @IBOutlet var noScreenshotLabel: UILabel!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var timeStampLabel: UILabel!
    @IBOutlet var coreLabel: UILabel!
    @IBOutlet var labelContainer: UIView!

    #if os(tvOS)
        override var canBecomeFocused: Bool {
            return true
        }
    #endif

    weak var saveState: PVSaveState? {
        didSet {
            if let saveState = saveState {
                if let image = saveState.image {
                    imageView.image = UIImage(contentsOfFile: image.url.path)
                }

                let timeText = "\(PVSaveStateCollectionViewCell.dateFormatter.string(from: saveState.date)) \(PVSaveStateCollectionViewCell.timeFormatter.string(from: saveState.date))"
                timeStampLabel.text = timeText

                #if os(tvOS)
                // Set up initial textColor for the savestate labels to match the other titles and allow for animation to white for our popup effect when focussed
                if saveStateView {
                    labelContainer.superview?.constraints.first(where: {$0.identifier == "labelContainer"})?.constant = 40
                    
                    timeStampLabel.textColor = .white
                    titleLabel.textColor = .white
                    coreLabel.textColor = .white
                } else {
                    timeStampLabel.textColor = UIColor.darkGray
                    titleLabel.textColor = UIColor.darkGray
                    coreLabel.textColor = UIColor.darkGray
                }

                // Set up nicer Save State image filtering on tvOS
                    imageView.layer.shouldRasterize = true
                    imageView.layer.rasterizationScale = 2.0
                #endif

                guard let game = saveState.game, let system = game.system, !system.cores.isEmpty else {
                    let gameNil = saveState.game == nil ? "true" : "false"
                    let systemNil = saveState.game?.system == nil ? "true" : "false"
                    let noCores = saveState.game?.system?.cores.isEmpty ?? true ? "true" : "false"
                    ELOG("Something wrong with save state object. game nil? \(gameNil), system nil? \(systemNil), no cores? \(noCores)")

                    let errorLabel: String
                    if saveState.game == nil { errorLabel = "Missing Game!" } else if saveState.game.system == nil { errorLabel = "Missing System!" } else if saveState.game.system.cores.isEmpty { errorLabel = "Missing Cores!" } else { errorLabel = "Missing Data!" }

                    if saveState.game == nil {
                        titleLabel.text = errorLabel
                    } else {
                        timeStampLabel.text = errorLabel
                    }
                    return
                }

                let multipleCores = system.cores.count > 1
                var coreOrSystem: String = (multipleCores ? saveState.core.projectName : system.shortNameAlt ?? system.shortName)
                if !coreOrSystem.isEmpty {
                    coreOrSystem = " " + coreOrSystem
                }

                titleLabel.text = game.title
                // #if os(tvOS)
//                coreLabel.text = coreOrSystem
                // #else
                coreLabel.text = system.shortName
                // #endif
            }

            setNeedsLayout()
            layoutIfNeeded()
        }
    }

    class func cellSize(forImageSize imageSize: CGSize) -> CGSize {
        let size: CGSize
        size = CGSize(width: imageSize.width, height: imageSize.height + (imageSize.height * 0.15))
        return size
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // #if os(tvOS)
//        self.labelContainer.transform = .identity
        // #endif
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if imageView.image == nil {
            noScreenshotLabel.isHidden = false
        } else {
            noScreenshotLabel.isHidden = true
        }
    }

    #if os(tvOS)
        override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
            super.didUpdateFocus(in: context, with: coordinator)
 //           imageView.layer.borderWidth = 0.0
            coordinator.addCoordinatedAnimations({ () -> Void in
                if self.isFocused {
                    let yOffset = self.imageView.frame.maxY - self.labelContainer.frame.minY + 36
                    let labelTransform = CGAffineTransform(scaleX: 1.25, y: 1.25).translatedBy(x: 0, y: yOffset)
                    self.labelContainer.transform = labelTransform
                    self.timeStampLabel.textColor = UIColor.white
                    self.titleLabel.textColor = UIColor.white
                    self.coreLabel.textColor = UIColor.white
                    self.sizeToFit()
                    self.superview?.bringSubviewToFront(self)
                } else {
                    self.labelContainer.transform = .identity
                    if self.saveStateView {
                        self.timeStampLabel.textColor = .white
                        self.titleLabel.textColor = .white
                        self.coreLabel.textColor = .white
                    } else {
                        self.timeStampLabel.textColor = UIColor.darkGray
                        self.titleLabel.textColor = UIColor.darkGray
                        self.coreLabel.textColor = UIColor.darkGray
                    }
                }
            }) { () -> Void in }
        }
    #endif
}
