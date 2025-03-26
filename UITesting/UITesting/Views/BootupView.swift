//
//  BootupView.swift
//  UITesting
//
//  Created by Cascade on 3/26/25.
//

import SwiftUI
import PVSwiftUI
import PVUIBase
import PVThemes
import PVLogging

struct BootupView: View {
    @EnvironmentObject var bootupStateManager: AppBootupState
    @EnvironmentObject var themeManager: ThemeManager
    
    init() {
        ILOG("ContentView: App is not initialized, showing BootupView")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image("AppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .cornerRadius(20)
            
            Text("Provenance")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(bootupStateManager.currentState.localizedDescription)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentPalette.defaultTintColor.swiftUIColor))
                .scaleEffect(1.5)
                .padding()
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            ILOG("BootupView: Appeared, current state: \(bootupStateManager.currentState.localizedDescription)")
        }
    }
}

#Preview {
    BootupView()
        .environmentObject(AppState.shared.bootupStateManager)
        .environmentObject(ThemeManager.shared)
}
