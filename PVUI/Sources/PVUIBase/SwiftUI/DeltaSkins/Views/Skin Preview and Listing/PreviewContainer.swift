//
//  PreviewContainer.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/30/25.
//

import SwiftUI

/// Container for preview image with rubber-like styling
public struct PreviewContainer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .aspectRatio(2/3, contentMode: .fit)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(10)
            .overlay {
                // Screen glare effect
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.1 : 0.2),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(10)
            }
    }
}
