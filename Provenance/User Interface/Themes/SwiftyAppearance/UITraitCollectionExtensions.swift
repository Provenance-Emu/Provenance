//
//  UITraitCollectionExtensions.swift
//  SwiftyAppearance
//
//  Created by Victor Pavlychko on 7/3/17.
//  Copyright © 2017 address.wtf. All rights reserved.
//

import UIKit

public extension UITraitCollection {

    /// Umbrella emun wrapping all possible traits
    ///
    /// - userInterfaceIdiom: user interface idiom specifier
    /// - displayScale: display scale specifier
    /// - horizontalSizeClass: horizontal size class specifier
    /// - verticalSizeClass: vertical size class specifier
    /// - forceTouchCapability: force touch capability specifier
    /// - layoutDirection: layout direction specifier
    /// - preferredContentSizeCategory: preferred content size category specifier
    /// - displayGamut: display gamut specifier
    public enum Trait {

        case userInterfaceIdiom(UIUserInterfaceIdiom)

        case displayScale(CGFloat)

        case horizontalSizeClass(UIUserInterfaceSizeClass)

        case verticalSizeClass(UIUserInterfaceSizeClass)

        case forceTouchCapability(UIForceTouchCapability)

        @available(iOS 10.0, tvOS 10.0, *)
        case layoutDirection(UITraitEnvironmentLayoutDirection)

        @available(iOSApplicationExtension 10.0, *)
        case preferredContentSizeCategory(UIContentSizeCategory)

		@available(iOS 10.0, tvOS 10.0, *)
        case displayGamut(UIDisplayGamut)
    }

    /// Returns a new trait collection containing single specified trait
    ///
    /// - Parameter trait: A Trait value specifying the trait for the new trait collection
    public convenience init(trait: Trait) {
        switch trait {
        case let .userInterfaceIdiom(value):
            self.init(userInterfaceIdiom: value)
        case let .displayScale(value):
            self.init(displayScale: value)
        case let .horizontalSizeClass(value):
            self.init(horizontalSizeClass: value)
        case let .verticalSizeClass(value):
            self.init(verticalSizeClass: value)
        case let .forceTouchCapability(value):
            if #available(iOS 9.0, *) {
                self.init(forceTouchCapability: value)
            } else {
                preconditionFailure("SwiftyAppearance: forceTouchCapability trait not available on this platform")
            }
        case let .layoutDirection(value):
            if #available(iOS 10.0, tvOS 10.0, *) {
                self.init(layoutDirection: value)
            } else {
                preconditionFailure("SwiftyAppearance: layoutDirection trait not available on this platform")
            }
        case let .preferredContentSizeCategory(value):
			if #available(iOS 10.0, tvOS 10.0, *) {
                self.init(preferredContentSizeCategory: value)
            } else {
                preconditionFailure("SwiftyAppearance: preferredContentSizeCategory trait not available on this platform")
            }
        case let .displayGamut(value):
			if #available(iOS 10.0, tvOS 10.0, *) {
                self.init(displayGamut: value)
            } else {
                preconditionFailure("SwiftyAppearance: displayGamut trait not available on this platform")
            }
        }
    }

    /// Returns a new trait collection consisting of traits merged from a specified array of traits
    ///
    /// - Parameter entities: An array of Trait values
    public convenience init<S>(traits: S) where S: Sequence, S.Iterator.Element == Trait {
        self.init(traitsFrom: traits.map(UITraitCollection.init(trait:)))
    }
}
