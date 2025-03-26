//
//  ErrorView.swift
//  UITesting
//
//  Created by Cascade on 3/26/25.
//

import SwiftUI
import PVSwiftUI
import PVUIBase
import PVThemes
import PVLogging

struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(themeManager.currentPalette.settingsCellText!.swiftUIColor)
            
            Text("Error During Bootup")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(error.localizedDescription)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: retryAction) {
                Text("Retry")
                    .font(.headline)
                    .padding()
                    .frame(minWidth: 150)
                    .background(themeManager.currentPalette.settingsCellBackground!.swiftUIColor)
                    .foregroundColor(themeManager.currentPalette.settingsCellText!.swiftUIColor)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            ILOG("ErrorView: Appeared with error: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ErrorView(error: NSError(domain: "com.provenance.error", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error message"]), retryAction: {})
        .environmentObject(ThemeManager.shared)
}
