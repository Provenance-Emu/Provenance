//
//  BootupRetroGrid.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/1/25.
//

import SwiftUI

// Retrowave grid background
public struct BootupRetroGrid: View {
    public var offset: CGFloat
    
    public init(offset: CGFloat) {
        self.offset = offset
    }
    
    public var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color(red: 0.1, green: 0.0, blue: 0.2),
                    Color(red: 0.2, green: 0.0, blue: 0.3)
                ]),
                startPoint: .bottom,
                endPoint: .top
            )
            
            // Horizontal grid lines
            VStack(spacing: 15) {
                ForEach(0..<50, id: \.self) { _ in
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.clear, .retroPink.opacity(0.5), .clear]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(height: 1)
                }
            }
            .offset(y: offset)
            
            // Vertical grid lines
            HStack(spacing: 15) {
                ForEach(0..<50, id: \.self) { _ in
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.clear, .retroPink.opacity(0.3), .clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 1)
                }
            }
            .offset(y: offset)
            
            // Horizon line
            Rectangle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.retroPink, .retroPurple]),
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 2)
                .offset(y: offset + 200)
                .blur(radius: 2)
        }
    }
}
