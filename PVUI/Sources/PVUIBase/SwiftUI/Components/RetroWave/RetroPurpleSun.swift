//
//  RetroPurpleSun.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/1/25.
//

import SwiftUI

// Retrowave sun element
public struct RetroPurpleSun: View {
    public var offset: CGFloat
    
    public init(offset: CGFloat) {
        self.offset = offset
    }
    
    public var body: some View {
        ZStack {
            // Sun circles
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .stroke(LinearGradient(
                        gradient: Gradient(colors: [.retroPurple, .retroPink]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ), lineWidth: 2)
                    .frame(width: 100 + CGFloat(i * 40))
                    .opacity(1.0 - Double(i) * 0.2)
            }
        }
        .offset(y: offset + 300)
        .blur(radius: 1)
    }
}
