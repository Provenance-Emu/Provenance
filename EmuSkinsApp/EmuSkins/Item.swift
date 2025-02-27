//
//  Item.swift
//  EmuSkins
//
//  Created by Joseph Mattiello on 2/26/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
