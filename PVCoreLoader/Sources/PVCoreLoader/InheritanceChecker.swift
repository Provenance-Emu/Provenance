//
//  InheritanceChecker.swift
//
//
//  Created by Joseph Mattiello on 6/13/24.
//

import Foundation
import ObjectiveC
import PVLogging
import Darwin

internal
struct ClassFinder {
    static func findSubclasses(of parentClass: AnyClass, excluding exceptions: [AnyClass] = []) -> [AnyClass] {
        guard #available(iOS 16.0, macOS 13.0, *) else {
            ELOG("objc_enumerateClasses is not available on this iOS version")
            return []
        }

        let exceptionsSet = Set(exceptions.map { ObjectIdentifier($0) })

        var allSubclasses = [AnyClass]()

        // Scan dynamic classes
        let dynamicClasses = objc_enumerateClasses(fromImage: .dynamicClasses, subclassing: parentClass)
        allSubclasses.append(contentsOf: dynamicClasses)

        // Scan main executable
        let mainClasses = objc_enumerateClasses(fromImage: .machHeader(#dsohandle), subclassing: parentClass)
        allSubclasses.append(contentsOf: mainClasses)

        // Get all loaded images
        var imageCount: UInt32 = 0
        let imageList = objc_copyImageNames(&imageCount)
        defer {
            free(UnsafeMutableRawPointer(mutating: imageList))
        }

        // Scan each image
        for i in 0..<Int(imageCount) {
            if let imageName = String(cString: imageList[i], encoding: .utf8) {
                // Get image handle using dlopen
                if let handle = dlopen(imageName, RTLD_NOLOAD) {
                    defer { dlclose(handle) }
                    let classes = objc_enumerateClasses(fromImage: .image(handle), subclassing: parentClass)
                    allSubclasses.append(contentsOf: classes)
                }
            }
        }

        // Filter and return
        return allSubclasses.filter { aClass in
            let classIdentifier = ObjectIdentifier(aClass)
            return !exceptionsSet.contains(classIdentifier)
        }
    }

    static func findClassesImplementing<P>(_ protocolToImplement: P, excluding exceptions: [AnyClass] = []) -> [AnyClass] where P: Protocol {
        guard #available(iOS 16.0, macOS 13.0, *) else {
            ELOG("objc_enumerateClasses is not available on this iOS version")
            return []
        }

        let exceptionsSet = Set(exceptions.map { ObjectIdentifier($0) })

        var allImplementingClasses = [AnyClass]()

        // Scan dynamic classes
        let dynamicClasses = objc_enumerateClasses(fromImage: .dynamicClasses, conformingTo: protocolToImplement)
        allImplementingClasses.append(contentsOf: dynamicClasses)

        // Scan main executable
        let mainClasses = objc_enumerateClasses(fromImage: .machHeader(#dsohandle), conformingTo: protocolToImplement)
        allImplementingClasses.append(contentsOf: mainClasses)

        // Get all loaded images
        var imageCount: UInt32 = 0
        let imageList = objc_copyImageNames(&imageCount)
        defer {
            free(UnsafeMutableRawPointer(mutating: imageList))
        }

        // Scan each image
        for i in 0..<Int(imageCount) {
            if let imageName = String(cString: imageList[i], encoding: .utf8) {
                // Get image handle using dlopen
                if let handle = dlopen(imageName, RTLD_NOLOAD) {
                    defer { dlclose(handle) }
                    let classes = objc_enumerateClasses(fromImage: .image(handle), conformingTo: protocolToImplement)
                    allImplementingClasses.append(contentsOf: classes)
                }
            }
        }

        // Filter and return
        return allImplementingClasses.filter { aClass in
            let classIdentifier = ObjectIdentifier(aClass)
            return !exceptionsSet.contains(classIdentifier)
        }
    }
}
