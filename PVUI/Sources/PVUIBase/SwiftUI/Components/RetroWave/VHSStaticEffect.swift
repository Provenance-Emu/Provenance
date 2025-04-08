//
//  VHSStaticEffect.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/7/25.
//

import SwiftUI

/// A view that creates a VHS static effect
public struct VHSStaticEffect: View {
    @State private var phase: CGFloat = 0
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Draw random noise pattern
                for _ in 0..<500 {
                    let x = CGFloat.random(in: 0..<size.width)
                    let y = CGFloat.random(in: 0..<size.height)
                    let rect = CGRect(x: x, y: y, width: CGFloat.random(in: 1...3), height: CGFloat.random(in: 1...3))
                    
                    context.fill(Path(rect), with: .color(Color.white.opacity(CGFloat.random(in: 0.1...0.5))))
                }
                
                // Draw horizontal tracking lines
                for i in 0..<Int(size.height / 20) {
                    let y = CGFloat(i) * 20 + phase.truncatingRemainder(dividingBy: 20)
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(Color.white.opacity(0.3)))
                }
            }
        }
        .onAppear {
            // Animate the static effect
            withAnimation(.linear(duration: 0.1).repeatForever(autoreverses: false)) {
                phase = 100
            }
        }
    }
}

/// A view that creates a scanline effect
public struct RetroScanlineEffect: View {
    public init() {}
    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 4) {
                ForEach(0..<Int(geometry.size.height / 4) + 1, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(height: 1)
                    Spacer()
                        .frame(height: 3)
                }
            }
        }
    }
}

/// A view that creates a VHS tracking line effect
public struct RetroTrackingLine: View {
    @State private var position: CGFloat = 0
    
    public init() {}
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background line
                Rectangle()
                    .fill(Color.retroBlack)
                    .frame(height: 4)
                
                // Moving tracking line
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .retroBlue.opacity(0.5),
                        .retroPink,
                        .retroBlue.opacity(0.5),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 100, height: 4)
                .offset(x: position)
            }
            .onAppear {
                // Animate the tracking line
                withAnimation(
                    .linear(duration: 4)
                    .repeatForever(autoreverses: false)
                ) {
                    position = geometry.size.width
                }
            }
        }
    }
}
