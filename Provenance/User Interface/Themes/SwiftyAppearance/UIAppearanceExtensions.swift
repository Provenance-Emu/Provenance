//
//  UIAppearanceExtensions.swift
//  SwiftyAppearance
//
//  Created by Victor Pavlychko on 6/19/16.
//  Copyright © 2016 address.wtf. All rights reserved.
//

import UIKit

/// Nested appearance scope for specified trait collection
///
/// - Parameters:
///   - traits: trait collection
///   - block:  appearance code block
public func appearance(for traits: UITraitCollection, _ block: () -> Void) {
    AppearanceScope.main.push(traits)
    block()
    AppearanceScope.main.pop()
}

/// Nested appearance scope for specified trait
///
/// - Parameters:
///   - trait: trait element
///   - block: appearance code block
public func appearance(for trait: UITraitCollection.Trait, _ block: () -> Void) {
    appearance(for: UITraitCollection(trait: trait), block)
}

/// Nested appearance scope for specified trait list
///
/// - Parameters:
///   - traits: trait element list
///   - block:  appearance code block
public func appearance(for traits: [UITraitCollection.Trait], _ block: () -> Void) {
    appearance(for: UITraitCollection(traits: traits), block)
}

/// Nested appearance scope for specified container type
///
/// - Parameters:
///   - containerType: container type
///   - block:         appearance code block
public func appearance(in containerType: UIAppearanceContainer.Type, _ block: () -> Void) {
    AppearanceScope.main.push(containerType)
    block()
    AppearanceScope.main.pop()
}

/// Nested appearance scope for specified container chain
///
/// - Parameters:
///   - containerTypes: container chain
///   - block:          appearance code block
public func appearance(inChain containerTypes: [UIAppearanceContainer.Type], _ block: () -> Void) {
    AppearanceScope.main.push(containerTypes)
    block()
    AppearanceScope.main.pop()
}

/// Nested appearance scope for any of specified containers
///
/// - Parameters:
///   - containerTypes: list of containers
///   - block:          appearance code block
public func appearance(inAny containerTypes: [UIAppearanceContainer.Type], _ block: () -> Void) {
    for container in containerTypes {
        appearance(in: container, block)
    }
}

public extension UIAppearanceContainer {
    
    /// Nested appearance scope for `Self` container
    ///
    /// - Parameter block: appearance code block for current container
    public static func appearance(_ block: () -> Void) {
        AppearanceScope.main.push(self)
        block()
        AppearanceScope.main.pop()
    }
}

public extension UIAppearance where Self: UIAppearanceContainer {
    
    /// Configure appearance for `Self` type and start
    /// nested appearance scope for `Self` container
    ///
    /// - Parameters:
    ///   - block: appearance code block for current container
    ///   - proxy: appearance proxy to configure
    public static func appearance(_ block: (_ proxy: Self) -> Void) {
        let context = AppearanceScope.main.context
        let proxy = appearance(context: context)
        AppearanceScope.main.push(self)
        block(proxy)
        AppearanceScope.main.pop()
    }
}

public extension UIAppearance {

    /// Configure appearance for `Self` type and start
    /// nested appearance scope for `Self` container if applicable
    ///
    /// - Parameters:
    ///   - block: appearance code block for current container
    ///   - proxy: appearance proxy to configure
    public static func appearance(_ block: (_ proxy: Self) -> Void) {
        let context = AppearanceScope.main.context
        let proxy = appearance(context: context)
        if let selfContainerType = self as? UIAppearanceContainer.Type {
            AppearanceScope.main.push(selfContainerType)
            block(proxy)
            AppearanceScope.main.pop()
        } else {
            block(proxy)
        }
    }
    
    /// Configure appearance for `Self` type and start
    /// nested appearance scope for `Self` container with specified trait collection
    ///
    /// - Parameters:
    ///   - traits: trait collections
    ///   - block:  appearance code block for current container
    ///   - proxy:  appearance proxy to configure
    public static func appearance(for traits: UITraitCollection, _ block: (_ proxy: Self) -> Void) {
        AppearanceScope.main.push(traits)
        appearance(block)
        AppearanceScope.main.pop()
    }
    
    /// Configure appearance for `Self` type and start
    /// nested appearance scope for specified trait
    ///
    /// - Parameters:
    ///   - trait: trait element
    ///   - block: appearance code block
    public static func appearance(for trait: UITraitCollection.Trait, _ block: (_ proxy: Self) -> Void) {
        appearance(for: UITraitCollection(trait: trait), block)
    }
    
    /// Configure appearance for `Self` type and start
    /// nested appearance scope for specified trait list
    ///
    /// - Parameters:
    ///   - traits: trait element list
    ///   - block:  appearance code block
    public static func appearance(for traits: [UITraitCollection.Trait], _ block: (_ proxy: Self) -> Void) {
        appearance(for: UITraitCollection(traits: traits), block)
    }
    
    /// Configure appearance for `Self` type and start
    /// nested appearance scope for `Self` container inside specified container type
    ///
    /// - Parameters:
    ///   - containerType: container type
    ///   - block:         appearance code block for current container
    ///   - proxy:         appearance proxy to configure
    public static func appearance(in containerType: UIAppearanceContainer.Type, _ block: (_ proxy: Self) -> Void) {
        AppearanceScope.main.push(containerType)
        appearance(block)
        AppearanceScope.main.pop()
    }
    
    /// Configure appearance for `Self` type and start
    /// nested appearance scope for `Self` container inside specified container chain
    ///
    /// - Parameters:
    ///   - containerTypes: container chain
    ///   - block:          appearance code block for current container
    ///   - proxy:          appearance proxy to configure
    public static func appearance(inChain containerTypes: [UIAppearanceContainer.Type], _ block: (_ proxy: Self) -> Void) {
        AppearanceScope.main.push(containerTypes)
        appearance(block)
        AppearanceScope.main.pop()
    }
    
    /// Configure appearance for `Self` type and start
    /// nested appearance scope for `Self` container inside any of specified containers
    ///
    /// - Parameters:
    ///   - containerTypes: list of containers
    ///   - block:          appearance code block for current container
    ///   - proxy:          appearance proxy to configure
    public static func appearance(inAny containerTypes: [UIAppearanceContainer.Type], _ block: (_ proxy: Self) -> Void) {
        for container in containerTypes {
            appearance(in: container, block)
        }
    }
}
