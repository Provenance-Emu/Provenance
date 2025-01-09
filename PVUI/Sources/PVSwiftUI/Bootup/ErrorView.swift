//
//  ErrorView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/26/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//


import SwiftUI
import PVLogging
import PVThemes

public struct ErrorView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    public let error: Error
    public let retryAction: () -> Void

    public init(error: Error, retryAction: @escaping () -> Void) {
        self.error = error
        self.retryAction = retryAction
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("An error occurred")
                .font(.title)
                .fontWeight(.bold)
            
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Retry") {
                ILOG("ErrorView: Retry button tapped")
                retryAction()
            }
            .padding()
            .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
            .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
            .cornerRadius(10)
        }
        .padding()
        .onAppear {
            ELOG("ErrorView: Appeared with error: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ErrorView(error: NSError(domain: "com.provenance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sample error message"]), retryAction: {
        print("Retry tapped in preview")
    })
}
