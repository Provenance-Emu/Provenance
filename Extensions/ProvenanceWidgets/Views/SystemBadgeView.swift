//
//  SystemBadgeView.swift
//  ProvenanceWidgets
//
//  Created by Provenance Emu on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import SwiftUI

/// Small pill-shaped badge showing the abbreviated system name.
struct SystemBadgeView: View {
    let systemShortName: String

    var body: some View {
        Text(systemShortName.isEmpty ? "???" : systemShortName)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Color.accentColor.opacity(0.85))
            )
    }
}
#endif
