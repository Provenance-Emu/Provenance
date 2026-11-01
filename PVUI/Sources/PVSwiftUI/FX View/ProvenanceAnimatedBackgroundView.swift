//
//  ProvenanceAnimatedBackgroundView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/25/24.
//

import Foundation
import SwiftUI
import PVThemes
import PVUIBase

@available(iOS 18.0, *)
public struct ProvenanceAnimatedBackgroundView: View {
    public var body: some View {
        RetroTheme.RetroBackgroundView()
            .environmentObject(ThemeManager.shared)
    }
}

@available(iOS 18.0, *)
#Preview {
    ProvenanceAnimatedBackgroundView()
}
