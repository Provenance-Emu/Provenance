//
//  HoverEffect.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/8/25.
//

import SwiftUI

/// Hover effect modifier for retrowave rows
public struct HoverEffect: ViewModifier {
    @State private var isHovered = false
    
    public init() { }
    
    public func body(content: Content) -> some View {
        content
            .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        #if !os(tvOS)
            .onHover { hovering in
                isHovered = hovering
            }
        #else
        // TODO: TVOS version of hover
        #endif
    }
}
