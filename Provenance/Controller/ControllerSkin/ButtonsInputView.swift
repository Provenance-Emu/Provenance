//
//  ButtonsInputView.swift
//  DeltaCore
//
//  Created by Riley Testut on 8/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

class ButtonsInputView: UIView
{
    var isHapticFeedbackEnabled = true
    
    var controllerSkin: ControllerSkinProtocol?
    var controllerSkinTraits: ControllerSkin.Traits?
    
    var activateInputsHandler: ((Set<AnyInput>) -> Void)?
    var deactivateInputsHandler: ((Set<AnyInput>) -> Void)?
    
    var image: UIImage? {
        get {
            return self.imageView.image
        }
        set {
            self.imageView.image = newValue
        }
    }
    
    private let imageView = UIImageView(frame: .zero)
    
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    private var touchInputsMappingDictionary: [UITouch: Set<AnyInput>] = [:]
    private var previousTouchInputs = Set<AnyInput>()
    private var touchInputs: Set<AnyInput> {
        return self.touchInputsMappingDictionary.values.reduce(Set<AnyInput>(), { $0.union($1) })
    }
    
    override var intrinsicContentSize: CGSize {
        return self.imageView.intrinsicContentSize
    }
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        self.isMultipleTouchEnabled = true
        
        self.feedbackGenerator.prepare()
        
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.imageView)
        
        NSLayoutConstraint.activate([self.imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                                     self.imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                                     self.imageView.topAnchor.constraint(equalTo: self.topAnchor),
                                     self.imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor)])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        for touch in touches
        {
            self.touchInputsMappingDictionary[touch] = []
        }
        
        self.updateInputs(for: touches)
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        self.updateInputs(for: touches)
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        for touch in touches
        {
            self.touchInputsMappingDictionary[touch] = nil
        }
        
        self.updateInputs(for: touches)
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        return self.touchesEnded(touches, with: event)
    }
}

private extension ButtonsInputView
{
    func updateInputs(for touches: Set<UITouch>)
    {
        guard let controllerSkin = self.controllerSkin else { return }
        
        // Don't add the touches if it has been removed in touchesEnded:/touchesCancelled:
        for touch in touches where self.touchInputsMappingDictionary[touch] != nil
        {
            guard touch.view == self else { continue }
            
            var point = touch.location(in: self)
            point.x /= self.bounds.width
            point.y /= self.bounds.height
            
            if let traits = self.controllerSkinTraits
            {
                let inputs = Set((controllerSkin.inputs(for: traits, at: point) ?? []).map { AnyInput($0) })
                
                let menuInput = AnyInput(stringValue: StandardGameControllerInput.menu.stringValue, intValue: nil, type: .controller(.controllerSkin))
                if inputs.contains(menuInput)
                {
                    // If the menu button is located at this position, ignore all other inputs that might be overlapping.
                    self.touchInputsMappingDictionary[touch] = [menuInput]
                }
                else
                {
                    self.touchInputsMappingDictionary[touch] = Set(inputs)
                }
            }
        }
        
        let activatedInputs = self.touchInputs.subtracting(self.previousTouchInputs)
        let deactivatedInputs = self.previousTouchInputs.subtracting(self.touchInputs)
        
        // We must update previousTouchInputs *before* calling activate() and deactivate().
        // Otherwise, race conditions that cause duplicate touches from activate() or deactivate() calls can result in various bugs.
        self.previousTouchInputs = self.touchInputs
        
        if !activatedInputs.isEmpty
        {
            self.activateInputsHandler?(activatedInputs)
            
            if self.isHapticFeedbackEnabled
            {
                switch UIDevice.current.feedbackSupportLevel
                {
                case .feedbackGenerator: self.feedbackGenerator.impactOccurred()
                case .basic, .unsupported: UIDevice.current.vibrate()
                }
            }
        }
        
        if !deactivatedInputs.isEmpty
        {
            self.deactivateInputsHandler?(deactivatedInputs)
        }
    }
}
