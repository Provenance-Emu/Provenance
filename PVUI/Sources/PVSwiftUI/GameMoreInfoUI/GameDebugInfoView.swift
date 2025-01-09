//
//  GameDebugInfoView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 12/9/24.
//

import SwiftUI

// MARK: - Debug Info View
struct GameDebugInfoView: View {
    let debugInfo: String

    var body: some View {
        ScrollView {
            Text(debugInfo)
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Debug Info")
    }
}
