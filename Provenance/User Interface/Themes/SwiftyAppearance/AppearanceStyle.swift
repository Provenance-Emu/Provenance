//
//  AppearanceStyle.swift
//  SwiftyAppearance
//
//  Created by Victor Pavlychko on 7/5/17.
//  Copyright © 2017 address.wtf. All rights reserved.
//

import Foundation

public struct AppearanceStyle {

    public let name: String

    public init(_ name: String) {
        self.name = name
    }
}

extension AppearanceStyle: ExpressibleByNilLiteral {
    
    public init(nilLiteral: ()) {
        self.name = ""
    }
}

extension AppearanceStyle: Equatable {

    public static func ==(lhs: AppearanceStyle, rhs: AppearanceStyle) -> Bool {
        return lhs.name == rhs.name
    }
}

extension AppearanceStyle: Hashable {
    
    public var hashValue: Int {
        return name.hashValue
    }
}
