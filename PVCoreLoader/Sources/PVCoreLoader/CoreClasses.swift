//
//  CoreClasses.swift
//
//
//  Created by Joseph Mattiello on 6/13/24.
//

import Foundation
import PVLogging
import PVEmulatorCore
import PVPlists

public final class CoreClasses: Sendable {
    nonisolated(unsafe) public static let coreClasses: [ClassInfo] = {
        /// Exception classes
        let libRetroCoreClass: AnyClass? = NSClassFromString("PVLibRetroCore")
        let libRetroGLESCoreClass: AnyClass? = NSClassFromString("PVLibRetroGLESCore")

        /// 1. Find all subclasses of PVEmulatorCore

        // Skip nils with `compactMap`
        let parentClasses: [AnyClass] = [PVEmulatorCore.self, libRetroCoreClass, libRetroGLESCoreClass].compactMap { $0 }

        let subclasses = ClassFinder.findSubclasses(of: PVEmulatorCore.self, excluding: parentClasses)

        // Create [ClassInfo] from found classes
        let foundCoreClasses: [ClassInfo] = subclasses.compactMap { ClassInfo($0) }

        // Log class names using functional approach
        ILOG("CoreClasses: \n\(foundCoreClasses.map(\.debugDescription).joined(separator: "\n"))")

        /// 2. Protocol search
        let protocolImplimenters =  ClassFinder.findClassesImplementing(EmulatorCoreInfoPlistProvider.self, excluding: parentClasses)

        let protocolImplimentersClasses: [ClassInfo] = protocolImplimenters.compactMap { ClassInfo($0) }

        // Log class names using Protocol search approach
        ILOG("CoreClasses: \n\(protocolImplimentersClasses.map(\.debugDescription).joined(separator: "\n"))")

        /// 3. Merge foundCoreClasses and protocolImplimentersClasses
        var returnValues: [ClassInfo] = foundCoreClasses
        returnValues.append(contentsOf: protocolImplimentersClasses.filter { !foundCoreClasses.contains($0) })

        /// 4. Filter duplicates and sort by name
        returnValues = Array(Set<ClassInfo>.init(returnValues)).sorted { $0.className < $1.className }

        /// 5. return
        return returnValues
    }()
}
