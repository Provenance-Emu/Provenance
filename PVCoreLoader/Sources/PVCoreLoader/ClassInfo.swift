//
//  ClassInfo.swift
//
//
//  Created by Joseph Mattiello on 6/18/24.
//

import Foundation

fileprivate func superClassName(forClass c: AnyClass) -> String? {
    guard let superClass = class_getSuperclass(c) else {
        return nil
    }
    let cName = class_getName(superClass)
    let classString = String(cString: cName)
    return classString
}

public struct ClassInfo {
    /// The name of the class.
    public let className: String
    /// The class type of the object.
    public let classObject: AnyClass
    /// The bundle where the class is defined.
    public let bundle: Bundle

    public init?(_ classObject: AnyClass?, withSuperclass superclass: [String]? = nil) {
        guard let classObject = classObject else { return nil }

        self.classObject = classObject

        let cName = class_getName(classObject)
        let classString = String(cString: cName)
        className = classString

        if let superclass = superclass,
           let superclassName = superClassName(forClass: classObject),
           !superclass.contains(superclassName) {
            return nil
        }

        bundle = Bundle(for: classObject)
    }

    public lazy var superclassesInfo: [ClassInfo]? = {
        var classInfos = [ClassInfo]()
        var superClass: ClassInfo? = superclassInfo

        while(superClass != nil) {
            if let classInfo = ClassInfo(superClass?.classObject) {
                classInfos.append(classInfo)
                superClass = classInfo.superclassInfo
            } else {
                superClass = nil
            }
        }

        return classInfos.isEmpty ? nil : classInfos
    }()

    public var superclassInfo: ClassInfo? {
        if let superclassObject: AnyClass = class_getSuperclass(self.classObject) {
            return ClassInfo(superclassObject)
        } else {
            return nil
        }
    }
}

extension ClassInfo: Equatable {
    public static func == (lhs: ClassInfo, rhs: ClassInfo) -> Bool {
        return lhs.className == rhs.className 
        && lhs.classObject == rhs.classObject
    }
}

extension ClassInfo: CustomStringConvertible {
    public var description: String {
        return "\(className),\(classObject),\(bundle)"
    }
}

extension ClassInfo: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "Name:\(className)\nClass: \(classObject)\nBundle: \(bundle)"
    }
}

extension ClassInfo: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(className)
        hasher.combine(bundle.bundleIdentifier)
    }
}
