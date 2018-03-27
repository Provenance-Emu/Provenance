//
//  AppearanceStyleable.swift
//  SwiftyAppearance
//
//  Created by Victor Pavlychko on 5/2/17.
//  Copyright © 2017 address.wtf. All rights reserved.
//

import UIKit

/// <#Description#>
public protocol AppearanceStyleable: NSObjectProtocol {

    /// <#Description#>
    associatedtype Style: RawRepresentable

    /// <#Description#>
    var appearanceRoot: UIWindow? { get }
}

public extension AppearanceStyleable where Self.Style.RawValue == String {

    /// <#Description#>
    ///
    /// - Parameter style: <#style description#>
    /// - Returns: <#return value description#>
    public static func style(_ style: Style) -> Self.Type {
        return _styleClass(name: style.rawValue)
    }

    /// <#Description#>
    public var style: Style? {
        get { return Style(rawValueOrNil: Self._styleName(class: object_getClass(self)!)) }
        set { setStyle(newValue, animated: false) }
    }

    /// <#Description#>
    ///
    /// - Parameters:
    ///   - style: <#style description#>
    ///   - animated: <#animated description#>
    public func setStyle(_ style: Style?, animated: Bool) {
        object_setClass(self, Self._styleClass(name: style?.rawValue))
        appearanceRoot?.refreshAppearance(animated: animated)
    }
}

public extension AppearanceStyleable where Self: UIView {

    /// <#Description#>
    public var appearanceRoot: UIWindow? {
        return window
    }
}

public extension AppearanceStyleable where Self: UIWindow {

    /// <#Description#>
    public var appearanceRoot: UIWindow? {
        return self
    }
}

public extension AppearanceStyleable where Self: UIViewController {

    /// <#Description#>
    public var appearanceRoot: UIWindow? {
        if #available(iOS 9.0, *) {
            return viewIfLoaded?.window
        } else {
            return isViewLoaded ? view.window : nil
        }
    }
}

fileprivate extension RawRepresentable {

    fileprivate init?(rawValueOrNil: RawValue?) {
        guard let rawValue = rawValueOrNil else {
            return nil
        }
        self.init(rawValue: rawValue)
    }
}

fileprivate extension AppearanceStyleable {

    private static var _subclassPrefix: String {
        return "__SwiftyAppearance_\(String(cString: class_getName(Self.self)))_style_"
    }

    private static func _lookUpClass(_ className: String) -> AnyClass? {
        return className.withCString { objc_lookUpClass($0) }
    }

    private static func _allocateClassPair(_ superclass: AnyClass, _ className: String, _ extraBytes: Int) -> AnyClass? {
        return className.withCString { objc_allocateClassPair(superclass, $0, extraBytes) }
    }

    fileprivate static func _styleClass(name styleName: String?) -> Self.Type {
        guard let subclassName = styleName.flatMap({ _subclassPrefix + $0 }) else {
            return Self.self
        }
        if let subclass = _lookUpClass(subclassName) as? Self.Type {
            return subclass
        }
        if let subclass = _allocateClassPair(Self.self, subclassName, 0) as? Self.Type {
            objc_registerClassPair(subclass)
            return subclass
        }
        fatalError("SwiftyAppearance: failed to subclass \(Self.self) as `\(subclassName)`")
    }

    fileprivate static func _styleName(class styleClass: AnyClass) -> String? {
        let subclassName = String(cString: class_getName(styleClass))
        let subclassPrefix = _subclassPrefix
        guard subclassName.hasPrefix(subclassPrefix) else {
            return nil
        }
		return String(subclassName[subclassPrefix.endIndex...])
	}
}
