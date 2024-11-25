//
//  ProvenanceAnimatedBackgroundView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/25/24.
//

import Foundation
import SwiftUI
import PVThemes

@available(iOS 18.0, *)
public struct ProvenanceAnimatedBackgroundView: View {
    public var body: some View {
        ZStack {
//            Color.Provenance.blue
            
            AnimatedColorsGridGradientView()
            
            AnimatedCheckerboardView()
                .blendMode(.difference)
                .luminanceToAlpha()

//            AnimatedColorsMeshGradientView()
//                .blendMode(.colorBurn)
//                .opacity(0.2)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

@available(iOS 18.0, *)
#Preview {
    ProvenanceAnimatedBackgroundView()
}
