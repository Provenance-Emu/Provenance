//
//  RetroGridPattern.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/7/25.
//

import SwiftUI

/// A retrowave grid pattern view
public struct RetroGridPattern: View {
    public init() {}
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Horizontal lines
                VStack(spacing: 20) {
                    ForEach(0..<Int(geometry.size.height / 20) + 1, id: \.self) { _ in
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.retroBlue.opacity(0.3))
                    }
                }
                
                // Vertical lines
                HStack(spacing: 20) {
                    ForEach(0..<Int(geometry.size.width / 20) + 1, id: \.self) { _ in
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(.retroBlue.opacity(0.3))
                    }
                }
            }
        }
    }
}

//
///// A grid pattern view for retrowave aesthetic
//public struct RetroGridPattern: View {
//    public var body: some View {
//        ZStack {
//            // Horizontal lines
//            VStack(spacing: 15) {
//                ForEach(0..<10) { _ in
//                    Color.retroBlue.opacity(0.2)
//                        .frame(height: 1)
//                }
//            }
//            
//            // Vertical lines
//            HStack(spacing: 15) {
//                ForEach(0..<10) { _ in
//                    Color.retroBlue.opacity(0.2)
//                        .frame(width: 1)
//                }
//            }
//        }
//    }
//}
