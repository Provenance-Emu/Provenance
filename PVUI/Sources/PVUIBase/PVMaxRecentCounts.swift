//
//  PVMaxRecentCounts.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public func PVMaxRecentsCount() -> Int {
    #if os(tvOS)
        return 12
    #elseif os(iOS)
        #if EXTENSION
            return 9
        #else
    return UIApplication.shared.windows.first { $0.isKeyWindow }?.traitCollection.userInterfaceIdiom == .phone ? 6 : 9
        #endif
    #endif
}
