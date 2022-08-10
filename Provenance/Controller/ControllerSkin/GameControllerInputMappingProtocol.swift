//
//  GameControllerInputMappingProtocol.swift
//  DeltaCore
//
//  Created by Riley Testut on 8/14/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation

public protocol GameControllerInputMappingProtocol
{
    var gameControllerInputType: GameControllerInputType { get }
        
    func input(forControllerInput controllerInput: Input) -> Input?
}
