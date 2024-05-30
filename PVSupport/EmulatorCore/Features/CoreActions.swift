//
//  CoreActions.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 12/27/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

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
    public let style: UIAlertAction.Style

    public init(title: String, requiresReset: Bool = false, options: [CoreActionOption]? = nil, style: UIAlertAction.Style = .destructive) {
        self.title = title
        self.requiresReset = requiresReset
        self.options = options
        self.style = style
    }
}
