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
    enum Trait {
        case userInterfaceIdiom(UIUserInterfaceIdiom)

        case displayScale(CGFloat)

        case horizontalSizeClass(UIUserInterfaceSizeClass)

        case verticalSizeClass(UIUserInterfaceSizeClass)

        case forceTouchCapability(UIForceTouchCapability)

        case layoutDirection(UITraitEnvironmentLayoutDirection)

        case preferredContentSizeCategory(UIContentSizeCategory)

        case displayGamut(UIDisplayGamut)
    }

    /// Returns a new trait collection containing single specified trait
    ///
    /// - Parameter trait: A Trait value specifying the trait for the new trait collection
    convenience init(trait: Trait) {
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
            self.init(forceTouchCapability: value)
        case let .layoutDirection(value):
            self.init(layoutDirection: value)
        case let .preferredContentSizeCategory(value):
            self.init(preferredContentSizeCategory: value)
        case let .displayGamut(value):
            self.init(displayGamut: value)
        }
    }

    /// Returns a new trait collection consisting of traits merged from a specified array of traits
    ///
    /// - Parameter entities: An array of Trait values
    convenience init<S>(traits: S) where S: Sequence, S.Iterator.Element == Trait {
        self.init(traitsFrom: traits.map(UITraitCollection.init(trait:)))
    }
}
