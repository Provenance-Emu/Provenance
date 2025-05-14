//
//  ScanlineEffect.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/1/25.
//

import SwiftUI

// Scanline effect
public struct ScanlineEffect: View {
    public var offset: CGFloat
    
    public init(offset: CGFloat) {
        self.offset = offset
    }
    
    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                ForEach(0..<Int(geometry.size.height / 4), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                }
            }
            .offset(y: offset.truncatingRemainder(dividingBy: 8))
        }
    }
}
