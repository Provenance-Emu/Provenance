//
//  RetroIndeterminateSpinner.swift
//  PVUI
//
//  Created by Joseph Mattiello on 1/8/26.
//

import SwiftUI
import PVThemes
import PVRealm
import PVLibrary
import PVLogging
import RealmSwift

/// RetroWave-styled indeterminate progress spinner
public struct RetroIndeterminateSpinner: View {
    @State private var isAnimating: Bool = false

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 3)

            Circle()
                .trim(from: 0.08, to: 0.68)
                .stroke(
                    AngularGradient(
                        colors: [.retroPink, .retroBlue, .retroPink],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: isAnimating)
        }
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}
