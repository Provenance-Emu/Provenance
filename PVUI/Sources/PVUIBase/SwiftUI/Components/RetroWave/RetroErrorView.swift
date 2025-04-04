//
//  RetroErrorView.swift
//  Provenance
//
//  Created by Joseph Mattiello' on 3/26/25.
//

import SwiftUI
import PVSwiftUI
import PVUIBase
import PVThemes
import PVLogging

public struct RetroErrorView: View {
    public let error: Error
    public let retryAction: (() -> Void)?
    
    @EnvironmentObject var themeManager: ThemeManager
    
    public init(error: Error, retryAction: @escaping (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }
    
    public var body: some View {
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
            
            if let retryAction {
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
                .buttonStyle(ProvenanceButtonStyle(isDestructive: false)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            ILOG("ErrorView: Appeared with error: \(error.localizedDescription)")
        }
    }
}

#Preview {
    RetroErrorView(error: NSError(domain: "com.provenance.error", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error message"]), retryAction: {})
        .environmentObject(ThemeManager.shared)
}
