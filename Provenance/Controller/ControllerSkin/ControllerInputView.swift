//
//  ControllerInputView.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/17/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import UIKit

class ControllerInputView: UIInputView
{
    let controllerView: ControllerView
    
    private var aspectRatioConstraint: NSLayoutConstraint? {
        didSet {
            oldValue?.isActive = false
        }
    }
    
    init(frame: CGRect)
    {
        self.controllerView = ControllerView(frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        self.controllerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.controllerView.isControllerInputView = true
        
        super.init(frame: frame, inputViewStyle: .keyboard)
        
        self.addSubview(self.controllerView)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.allowsSelfSizing = true
        
        self.setNeedsUpdateConstraints()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        
        guard
            let controllerSkin = self.controllerView.controllerSkin,
            let traits = self.controllerView.controllerSkinTraits,
            let aspectRatio = controllerSkin.aspectRatio(for: traits)
            else { return }
        
        let multiplier = aspectRatio.height / aspectRatio.width
        guard self.aspectRatioConstraint?.multiplier != multiplier else { return }
        
        self.aspectRatioConstraint = self.heightAnchor.constraint(equalTo: self.widthAnchor, multiplier: multiplier)
        self.aspectRatioConstraint?.isActive = true
    }
}
