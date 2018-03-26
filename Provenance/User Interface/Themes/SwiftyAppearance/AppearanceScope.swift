//
//  AppearanceScope.swift
//  SwiftyAppearance
//
//  Created by Victor Pavlychko on 9/18/16.
//  Copyright © 2016 address.wtf. All rights reserved.
//

import UIKit

internal struct AppearanceScope {

    internal static var main = AppearanceScope()

    private enum StackElement {
        case traitCollection(UITraitCollection)
        case containerTypes([UIAppearanceContainer.Type])
    }

    private var _stack: [StackElement] = []

    internal struct Context {

        internal let traitCollection: UITraitCollection?
        internal let containerTypes: [UIAppearanceContainer.Type]?

        internal init(_ traitCollections: [UITraitCollection], _ containerTypes: [UIAppearanceContainer.Type]) {
            self.traitCollection = traitCollections.isEmpty ? nil : UITraitCollection(traitsFrom: traitCollections)
            self.containerTypes = containerTypes.isEmpty ? nil : containerTypes.reversed()
        }
    }

    internal var context: Context {
        var traitCollections: [UITraitCollection] = []
        var containerTypes: [UIAppearanceContainer.Type] = []
        for element in _stack {
            switch element {
            case let .traitCollection(element):
                traitCollections.append(element)
            case let .containerTypes(element):
                containerTypes.append(contentsOf: element)
            }
        }
        return Context(traitCollections, containerTypes)
    }

    internal mutating func push(_ traitCollection: UITraitCollection) {
        _stack.append(.traitCollection(traitCollection))
    }

    internal mutating func push(_ containerType: UIAppearanceContainer.Type) {
        _stack.append(.containerTypes([containerType]))
    }

    internal mutating func push(_ containerTypes: [UIAppearanceContainer.Type]) {
        _stack.append(.containerTypes(containerTypes))
    }

    internal mutating func pop() {
        _stack.removeLast()
    }
}

internal extension UIAppearance {

    internal static func appearance(context: AppearanceScope.Context) -> Self {
        switch (context.traitCollection, context.containerTypes) {
        case let (.some(traitCollection), .some(containerTypes)):
            if #available(iOS 9.0, *) {
                return appearance(for: traitCollection, whenContainedInInstancesOf: containerTypes)
            } else {
                preconditionFailure("SwiftyAppearance: whenContainedInInstancesOf not available on this platform")
            }
        case let (.some(traitCollection), .none):
            return appearance(for: traitCollection)
        case let (.none, .some(containerTypes)):
            if #available(iOS 9.0, *) {
                return appearance(whenContainedInInstancesOf: containerTypes)
            } else {
                preconditionFailure("SwiftyAppearance: whenContainedInInstancesOf not available on this platform")
            }
        case (.none, .none):
            return appearance()
        }
    }
}
