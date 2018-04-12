//
//  UIAppearanceExtensions.swift
//  SwiftyAppearance
//
//  Created by Victor Pavlychko on 6/19/16.
//  Copyright © 2016 address.wtf. All rights reserved.
//

import UIKit

/// Nested appearance scope for specified trait collection and container types
///
/// - Parameters:
///   - traitCollection: trait collection
///   - containerTypes: list of container types
///   - block: appearance code block
public func appearance(for traitCollection: UITraitCollection? = nil, in containerTypes: [UIAppearanceContainer.Type] = [], _ block: () -> Void) {
    AppearanceScope.main.push(traitCollection: traitCollection)
    AppearanceScope.main.push(containerTypes: containerTypes)
    block()
    AppearanceScope.main.pop(count: 2)
}

/// Nested appearance scope for specified trait collection any of specified containers
///
/// - Parameters:
///   - traitCollection: trait collection
///   - containerTypes: list of container types
///   - block: appearance code block
public func appearance(for traitCollection: UITraitCollection? = nil, inAny containerTypes: [UIAppearanceContainer.Type], _ block: () -> Void) {
    AppearanceScope.main.push(traitCollection: traitCollection)
    for container in containerTypes {
        AppearanceScope.main.push(containerTypes: [container])
        block()
        AppearanceScope.main.pop()
    }
    AppearanceScope.main.pop()
}

public extension UIAppearanceContainer {
    
    /// Nested appearance scope for `Self` container and trait collection
    ///
    /// - Parameter
    ///   - style: appearance style for this container
    ///   - traitCollection: trait collection
    ///   - block: appearance code block for current container
    public static func appearance(style: AppearanceStyle = nil, for traitCollection: UITraitCollection? = nil, _ block: () -> Void) {
        let cls = styleClass(self, styleName: style.name)
        AppearanceScope.main.push(traitCollection: traitCollection)
        AppearanceScope.main.push(containerTypes: [cls])
        block()
        AppearanceScope.main.pop(count: 2)
    }
}

public extension UIAppearance {

    /// Configure appearance for `Self` type and start
    /// nested appearance scope for `Self` container with specified trait collection
    ///
    /// - Parameters:
    ///   - style: appearance style for current class
    ///   - traitCollection: trait collections
    ///   - block: appearance code block for current container
    ///   - proxy: appearance proxy to configure
    public static func appearance(style: AppearanceStyle = nil, for traitCollection: UITraitCollection? = nil, _ block: (_ proxy: Self) -> Void) {
        let cls = styleClass(self, styleName: style.name)
        AppearanceScope.main.push(traitCollection: traitCollection)
        let context = AppearanceScope.main.context
        let proxy = cls.appearance(context: context)
        if let selfContainerType = cls as? UIAppearanceContainer.Type {
            AppearanceScope.main.push(containerTypes: [selfContainerType])
            block(proxy)
            AppearanceScope.main.pop()
        } else {
            block(proxy)
        }
        AppearanceScope.main.pop()
    }
}

public extension UIAppearance where Self: UIAppearanceContainer {

    /// Configure appearance for `Self` type and start
    /// nested appearance scope for `Self` container with specified trait collection
    ///
    /// - Parameters:
    ///   - style: appearance style for current class
    ///   - traitCollection: trait collections
    ///   - block: appearance code block for current container
    ///   - proxy: appearance proxy to configure
    public static func appearance(style: AppearanceStyle = nil, for traitCollection: UITraitCollection? = nil, _ block: (_ proxy: Self) -> Void) {
        let cls = styleClass(self, styleName: style.name)
        AppearanceScope.main.push(traitCollection: traitCollection)
        let context = AppearanceScope.main.context
        let proxy = cls.appearance(context: context)
        AppearanceScope.main.push(containerTypes: [cls])
        block(proxy)
        AppearanceScope.main.pop(count: 2)
    }
}
