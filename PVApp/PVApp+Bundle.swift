//
//  PVApp+Bundle.swift
//  PVApp
//
//  Created by Joseph Mattiello on 12/18/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

fileprivate class PVAppBundleRef: NSObject { }
public extension Bundle {
    static let pvapp: Bundle = Bundle.init(for: PVAppBundleRef.self)
}

public extension UIStoryboard {
    struct Name : Hashable, Equatable, RawRepresentable, @unchecked Sendable {
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
        
        public var rawValue: String
        
        public typealias RawValue = String
    }
    convenience init(name: UIStoryboard.Name, bundle: Bundle? = nil) {
        self.init(name: name.rawValue, bundle: bundle)
    }
}

public extension UIStoryboard.Name {
    #if os(tvOS)
    static let Provenance: UIStoryboard.Name = .init("Provenance~tvOS")
    static let Settings: UIStoryboard.Name = .init("Settings~tvOS")
    static let SaveStates: UIStoryboard.Name = .init("SaveStates~tvOS")
    static let Cheats: UIStoryboard.Name = .init("Cheats~tvOS")
    #else
    static let Provenance: UIStoryboard.Name = .init("Provenance")
    static let Settings: UIStoryboard.Name = .init("Settings")
    static let SaveStates: UIStoryboard.Name = .init("SaveStates")
    static let Cheats: UIStoryboard.Name = .init("Cheats~iOS")
    #endif
}
