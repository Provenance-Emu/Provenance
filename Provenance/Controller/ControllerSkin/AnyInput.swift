//
//  AnyInput.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/24/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation

public struct AnyInput: Input, Codable, Hashable
{
    public let stringValue: String
    public let intValue: Int?
    
    public var type: InputType
    public var isContinuous: Bool
    
    public init(_ input: Input)
    {
        self.init(stringValue: input.stringValue, intValue: input.intValue, type: input.type, isContinuous: input.isContinuous)
    }
    
    public init(stringValue: String, intValue: Int?, type: InputType, isContinuous: Bool? = nil)
    {
        self.stringValue = stringValue
        self.intValue = intValue
        
        self.type = type
        self.isContinuous = false
        
        if let isContinuous = isContinuous
        {
            self.isContinuous = isContinuous
        }
        else
        {
            switch type
            {
            case .game(let gameType):
                guard let deltaCore = Delta.core(for: gameType), let input = deltaCore.gameInputType.init(stringValue: self.stringValue) else { break }
                self.isContinuous = input.isContinuous
                
            case .controller(.standard):
                guard let standardInput = StandardGameControllerInput(input: self) else { break }
                self.isContinuous = standardInput.isContinuous
                
            case .controller(.mfi):
                guard let mfiInput = MFiGameController.Input(input: self) else { break }
                self.isContinuous = mfiInput.isContinuous
                
            case .controller:
                // FIXME: We have no way to look up arbitrary controller inputs at runtime, so just leave isContinuous as false for now.
                // In practice this is not too bad, since it's very uncommon to map from an input to a non-standard controller input.
                break
            }
        }
    }
}

public extension AnyInput
{
    init?(stringValue: String)
    {
        return nil
    }

    init?(intValue: Int)
    {
        return nil
    }
}

public extension AnyInput
{
    private enum CodingKeys: String, CodingKey
    {
        case stringValue = "identifier"
        case type
    }
    
    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let stringValue = try container.decode(String.self, forKey: .stringValue)
        let type = try container.decode(InputType.self, forKey: .type)
        
        let intValue: Int?
        
        switch type
        {
        case .controller: intValue = nil
        case .game(let gameType):
            guard let deltaCore = Delta.core(for: gameType), let input = deltaCore.gameInputType.init(stringValue: stringValue) else {
                throw DecodingError.dataCorruptedError(forKey: .stringValue, in: container, debugDescription: "The Input game type \(gameType) is unsupported.")
            }
            
            intValue = input.intValue
        }
        
        self.init(stringValue: stringValue, intValue: intValue, type: type)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.stringValue, forKey: .stringValue)
        try container.encode(self.type, forKey: .type)
    }
}
