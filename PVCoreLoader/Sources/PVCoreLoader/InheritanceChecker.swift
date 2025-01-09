//
//  InheritanceChecker.swift
//
//
//  Created by Joseph Mattiello on 6/13/24.
//

import Foundation
import ObjectiveC

internal
struct ClassFinder {
    static func findSubclasses(of parentClass: AnyClass, excluding exceptions: [AnyClass] = []) -> [AnyClass] {
        var result: [AnyClass] = []

        // Get the count of all registered classes
        let classCount = objc_getClassList(nil, 0)
        let classes = UnsafeMutablePointer<AnyClass?>.allocate(capacity: Int(classCount))
        defer { classes.deallocate() }

        let bufferSize = Int(classCount)
        objc_getClassList(AutoreleasingUnsafeMutablePointer(classes), Int32(bufferSize))

        for index in 0..<bufferSize {
            if let currentClass: AnyClass = classes[index] {
                // Check if the current class is a subclass of parentClass excluding itself
                if class_getSuperclass(currentClass) == parentClass && !exceptions.contains(where: { $0 == currentClass }) && currentClass != parentClass {
                    result.append(currentClass)
                }
            }
        }

        return result
    }

//    static func findClasses(ofProtocol parentProtocol: Protocol, excluding exceptions: [AnyClass] = []) -> [AnyClass] {
//        var result: [AnyClass] = []
//
//        // Get the count of all registered classes
//        let classCount = objc_getClassList(nil, 0)
//        let classes = UnsafeMutablePointer<AnyClass?>.allocate(capacity: Int(classCount))
//        defer { classes.deallocate() }
//
//        let bufferSize = Int(classCount)
//        objc_getClassList(AutoreleasingUnsafeMutablePointer(classes), Int32(bufferSize))
//
//        for index in 0..<bufferSize {
//            if let currentClass: AnyClass = classes[index] {
//                // Check if the current class is a subclass of parentClass excluding itself
//                if class_getSuperclass(currentClass) is parentProtocol && !exceptions.contains(where: { $0 == currentClass }) {
//                    result.append(currentClass)
//                }
//            }
//        }
//
//        return result
//    }

    static func findClassesImplementing<P>(_ protocolToImpliment: P, excluding exceptions: [AnyClass] = []) -> [AnyClass] where P: Protocol {
        var classesImplementingProtocol: [AnyClass] = []
        let expectedClassCount = objc_getClassList(nil, 0)

        guard expectedClassCount > 0 else {
            return []
        }

        let allClasses = UnsafeMutablePointer<AnyClass>.allocate(capacity: Int(expectedClassCount))
        let autoreleasingAllClasses = AutoreleasingUnsafeMutablePointer<AnyClass>(allClasses)
        let actualClassCount = objc_getClassList(autoreleasingAllClasses, expectedClassCount)

        for i in 0..<actualClassCount {
            let currentClass: AnyClass = allClasses[Int(i)]
            if class_conformsToProtocol(currentClass, protocolToImpliment),
               !exceptions.contains(where: { $0 == currentClass }){
                classesImplementingProtocol.append(currentClass)
            }
        }

        allClasses.deallocate()

        return classesImplementingProtocol
    }
}
