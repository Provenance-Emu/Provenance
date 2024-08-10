//
//  SettingModel.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/8/24.
//

import Foundation

public protocol SettingModel: UserDefaultsRepresentable {
    associatedtype T: Any
    var title: String { get }
    var info: String? { get }
    var defaultValue: T { get }
    var value: T { get set }
}
