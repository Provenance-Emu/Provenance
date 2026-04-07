//
//  TVOSDisableFocusEffect.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/7/26.
//

import SwiftUI

#if os(tvOS)
public struct TVOSDisableFocusEffect: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        if #available(tvOS 17.0, *) {
            content.focusEffectDisabled()
        } else {
            content
        }
    }
}
#else
public struct TVOSDisableFocusEffect: ViewModifier {
    public init() {}
    
    public func body(content: Content) -> some View {
        content
    }
}
#endif

public extension View {
    func tvOSDisableFocusEffect() -> some View {
        modifier(TVOSDisableFocusEffect())
    }
}
