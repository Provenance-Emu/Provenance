//
//  BoolSetting.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/8/24.
//

import Foundation

public struct BoolSetting: SettingModel {
    public var valueType: Any.Type {
        return Bool.self
    }
    
    public var defaultsValue: Any {
        return value
    }
    
    public let defaultValue: Bool
    public var value: Bool
    public var title: String
    public let info: String?
    
    public init(_ defaultValue: Bool, title: String, info: String? = nil) {
        self.defaultValue = defaultValue
        value = defaultValue
        self.title = title
        self.info = info
    }
}
