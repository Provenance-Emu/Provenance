//
//  ScrollOffsetPreferenceKey.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/12/25.
//

import SwiftUI

/// Preference key for tracking scroll offset
public struct ScrollOffsetPreferenceKey: PreferenceKey {
    public static var defaultValue: CGFloat = 0
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
