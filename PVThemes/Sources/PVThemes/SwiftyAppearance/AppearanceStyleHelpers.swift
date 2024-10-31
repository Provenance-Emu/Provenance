//
//  AppearanceStyleHelper.swift
//  SwiftyAppearance
//
//  Created by Victor Pavlychko on 3/6/18.
//  Copyright © 2018 address.wtf. All rights reserved.
//

import Foundation

internal func className(_ cls: AnyClass) -> String {
    return String(cString: class_getName(cls))
}

internal func lookUpClass(_ className: String) -> AnyClass? {
    return className.withCString { objc_lookUpClass($0) }
}

internal func allocateClassPair(_ superclass: AnyClass, _ className: String, extraBytes: Int = 0) -> AnyClass? {
    return className.withCString { objc_allocateClassPair(superclass, $0, extraBytes) }
}

internal func styleClassName(_ cls: AnyClass, styleName: String) -> String {
    return "__SwiftyAppearance_\(className(cls))_style_\(styleName)"
}

internal func styleName(_ className: String) -> String {
    if className.hasPrefix("__SwiftyAppearance_"), let range = className.range(of: "_style_") {
        return String(className[range.upperBound...])
    } else {
        return ""
    }
}

internal func isStyleClass(_ cls: AnyClass) -> Bool {
    return className(cls).hasPrefix("__SwiftyAppearance_")
}

internal func actualClass(_ cls: AnyClass) -> AnyClass? {
    return sequence(first: cls, next: { class_getSuperclass($0) }).first(where: { !isStyleClass($0) })
}

internal func styleClass<T: AnyObject>(_ cls: T.Type, styleName: String) -> T.Type {
    guard let actualClass = actualClass(cls) as? T.Type else {
        assertionFailure("SwiftyAppearance: failed to find actual class for \(cls)")
        return cls
    }
    guard !styleName.isEmpty else {
        return actualClass
    }
    let subclassName = styleClassName(actualClass, styleName: styleName)
    if let subclass = lookUpClass(subclassName) as? T.Type {
        return subclass
    }
    guard let subclass = allocateClassPair(cls, subclassName) as? T.Type else {
        assertionFailure("SwiftyAppearance: failed to subclass \(cls) as `\(subclassName)`")
        return cls
    }
    objc_registerClassPair(subclass)
    return subclass
}
