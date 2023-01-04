//
//  CoreOptions+Protocols.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public protocol COption {
    associatedtype ValueType: OptionValueRepresentable

    var key: String { get }
    var title: String { get }
    var description: String? { get }

//    associatedtype Dependencies : COption
//    var dependsOn : [OptionDependency<Dependencies>]? {get set}

    var defaultValue: ValueType { get }
    var value: ValueType { get }
}

public protocol MultiCOption: COption {
    var options: [(key: String, title: String, description: String?)] { get }
}

public protocol EnumCOption: COption {
    var options: [(key: String, title: String, description: String?)] { get }
}

public protocol OptionValueRepresentable: Codable {}
extension Array: OptionValueRepresentable where Self.Element: OptionValueRepresentable { }

extension Int: OptionValueRepresentable {}
extension UInt: OptionValueRepresentable {}
extension UInt64: OptionValueRepresentable {}
extension Int64: OptionValueRepresentable {}
extension Bool: OptionValueRepresentable {}
extension String: OptionValueRepresentable {}
extension Float: OptionValueRepresentable {}
extension Double: OptionValueRepresentable {}
