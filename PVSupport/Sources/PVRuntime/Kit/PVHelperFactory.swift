//
//  CoreFactory.swift
//  PVRuntime
//
//  Created by Stuart Carnie on 2/12/2022.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public class PVHelperFactory {
    public static let shared = PVHelperFactory()
    
    var registry: [(_ principalClass: String, _ systemIdentifier: String, _ coreIdentifier: String) -> OEGameCoreHelper?] = []
    
    init() {
        
    }
    
    public func register(_ create: @escaping (_ principalClass: String, _ systemIdentifier: String, _ coreIdentifier: String) -> OEGameCoreHelper?) {
        registry.append(create)
    }
    
    public func create(_ principalClass: String, systemIdentifier: String, coreIdentifier: String) -> OEGameCoreHelper? {
        if let cfn = registry.first {
            return cfn(principalClass, systemIdentifier, coreIdentifier)
        }
        return nil
    }
}

// MARK: - Static functions

public extension PVHelperFactory {
    static func register(_ create: @escaping (_ principalClass: String, _ systemIdentifier: String, _ coreIdentifier: String) -> OEGameCoreHelper?) {
        shared.register(create)
    }
    
    static func create(_ principalClass: String, systemIdentifier: String, coreIdentifier: String) -> OEGameCoreHelper? {
        shared.create(principalClass, systemIdentifier: systemIdentifier, coreIdentifier: coreIdentifier)
    }
}
