//
//  CoreActions.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 12/27/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

#if canImport(UIKit)
import UIKit.UIAlert
public typealias CoreActionAlertStyle = UIAlertAction.Style
public let CoreActionAlertDefaultStyle: CoreActionAlertStyle = UIAlertAction.Style.destructive
#elseif canImport(AppKit)
import AppKit.NSAlert
public typealias CoreActionAlertStyle = NSAlert.Style
public let CoreActionAlertDefaultStyle: CoreActionAlertStyle = NSAlert.Style.critical
#endif
public protocol CoreActions {
    var coreActions: [CoreAction]? { get }
    func selected(action: CoreAction)
}

// MARK: - Models

public struct CoreActionOption {
    public let title: String
    public let selected: Bool

    public init(title: String, selected: Bool = false) {
        self.title = title
        self.selected = selected
    }
}

public struct CoreAction {
    public let title: String
    public let requiresReset: Bool
    public let options: [CoreActionOption]?
    public let style: CoreActionAlertStyle

    public init(title: String, requiresReset: Bool = false, options: [CoreActionOption]? = nil, style: CoreActionAlertStyle = CoreActionAlertDefaultStyle) {
        self.title = title
        self.requiresReset = requiresReset
        self.options = options
        self.style = style
    }
}
