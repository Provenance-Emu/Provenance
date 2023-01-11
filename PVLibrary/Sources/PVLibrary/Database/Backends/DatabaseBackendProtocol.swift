//
//  File.swift
//  
//
//  Created by Joseph Mattiello on 1/11/23.
//

import Foundation

public protocol DatabaseBackendProtocol {
    func releaseID(forCRCs crcs: Set<String>) -> Int?

}
