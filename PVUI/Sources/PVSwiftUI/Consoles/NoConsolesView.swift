//
//  NoConsolesView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/22/24.
//

import SwiftUI
import PVThemes
import AnimatedGradient

struct PVAnimatedGradient: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    var body: some View {
        AnimatedLinearGradient(colors: [
            .Provenance.blue,
            currentPalette.settingsCellBackground!.swiftUIColor,
            currentPalette.gameLibraryBackground.swiftUIColor,
            currentPalette.settingsCellBackground!.swiftUIColor])
        .numberOfSimultaneousColors(3)
        .setAnimation(.bouncy(duration: 5))
        .gradientPoints(start: .topTrailing, end: .bottomLeading)
        .ignoresSafeArea()
    }
}

struct NoConsolesView: SwiftUI.View {
    weak var delegate: PVMenuDelegate!

    var body: some SwiftUI.View {
        ZStack {
            if #available(iOS 18.0, *) {
                ProvenanceAnimatedBackgroundView()
            } else {
                PVAnimatedGradient()
            }
            
            VStack {
                Group {
                    Text("No Games Found")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .backgroundStyle(.secondary)
                        .tag("no consoles")
                        .blendMode(.difference)

                    Button(action: {
                        delegate?.didTapImports()
                    }) {
                        HStack {
                            Image(systemName: "checklist")
                            Text("Add Games")
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top, 20)
                }
                .shadow(radius: 5, x: 0, y: 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))
            .edgesIgnoringSafeArea(.bottom)
        }
    }
}

#if DEBUG
#Preview {
    NoConsolesView()
}
#endif
