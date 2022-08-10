//
//  GameController.swift
//  DeltaCore
//
//  Created by Riley Testut on 5/3/15.
//  Copyright (c) 2015 Riley Testut. All rights reserved.
//

import ObjectiveC

private var gameControllerStateManagerKey = 0

//MARK: - GameControllerReceiver -
public protocol GameControllerReceiver: class
{
    /// Equivalent to pressing a button, or moving an analog stick
    func gameController(_ gameController: GameController, didActivate input: Input, value: Double)
    
    /// Equivalent to releasing a button or an analog stick
    func gameController(_ gameController: GameController, didDeactivate input: Input)
}

//MARK: - GameController -
public protocol GameController: NSObjectProtocol
{
    var name: String { get }
        
    var playerIndex: Int? { get set }
    
    var inputType: GameControllerInputType { get }
    
    var defaultInputMapping: GameControllerInputMappingProtocol? { get }
}

public extension GameController
{
    private var stateManager: GameControllerStateManager {
        var stateManager = objc_getAssociatedObject(self, &gameControllerStateManagerKey) as? GameControllerStateManager
        
        if stateManager == nil
        {
            stateManager = GameControllerStateManager(gameController: self)
            objc_setAssociatedObject(self, &gameControllerStateManagerKey, stateManager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        return stateManager!
    }
    
    var receivers: [GameControllerReceiver] {
        return self.stateManager.receivers
    }
    
    var activatedInputs: [AnyInput: Double] {
        return self.stateManager.activatedInputs
    }
    
    var sustainedInputs: [AnyInput: Double] {
        return self.stateManager.sustainedInputs
    }
}

public extension GameController
{
    func addReceiver(_ receiver: GameControllerReceiver)
    {
        self.addReceiver(receiver, inputMapping: self.defaultInputMapping)
    }
    
    func addReceiver(_ receiver: GameControllerReceiver, inputMapping: GameControllerInputMappingProtocol?)
    {
        self.stateManager.addReceiver(receiver, inputMapping: inputMapping)
    }
    
    func removeReceiver(_ receiver: GameControllerReceiver)
    {
        self.stateManager.removeReceiver(receiver)
    }
    
    func activate(_ input: Input, value: Double = 1.0)
    {
        self.stateManager.activate(input, value: value)
    }
    
    func deactivate(_ input: Input)
    {
        self.stateManager.deactivate(input)
    }
    
    func sustain(_ input: Input, value: Double = 1.0)
    {
        self.stateManager.sustain(input, value: value)
    }
    
    func unsustain(_ input: Input)
    {
        self.stateManager.unsustain(input)
    }
}

public extension GameController
{
    func inputMapping(for receiver: GameControllerReceiver) -> GameControllerInputMappingProtocol?
    {
        return self.stateManager.inputMapping(for: receiver)
    }
    
    func mappedInput(for input: Input, receiver: GameControllerReceiver) -> Input?
    {
        return self.stateManager.mappedInput(for: input, receiver: receiver)
    }
}

public func ==(lhs: GameController?, rhs: GameController?) -> Bool
{
    switch (lhs, rhs)
    {
    case (nil, nil): return true
    case (_?, nil): return false
    case (nil, _?): return false
    case (let lhs?, let rhs?): return lhs.isEqual(rhs)
    }
}

public func !=(lhs: GameController?, rhs: GameController?) -> Bool
{
    return !(lhs == rhs)
}

public func ~=(pattern: GameController?, value: GameController?) -> Bool
{
    return pattern == value
}
