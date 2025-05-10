//
//  RetroProgressView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes

/// A progress indicator with retrowave styling
public struct RetroProgressView: View {
    // MARK: - Properties
    
    /// Title of the progress view
    let title: String
    
    /// Current progress value
    let current: Int
    
    /// Total progress value
    let total: Int
    
    /// Color of the progress bar
    let color: Color
    
    /// Optional custom text to display
    let customText: String?
    
    /// Computed progress percentage
    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(current) / CGFloat(total)
    }
    
    // MARK: - Initialization
    
    /// Creates a new RetroProgressView
    /// - Parameters:
    ///   - title: Title of the progress view
    ///   - current: Current progress value
    ///   - total: Total progress value
    ///   - color: Color of the progress bar
    ///   - customText: Optional custom text to display
    public init(
        title: String,
        current: Int,
        total: Int,
        color: Color,
        customText: String? = nil
    ) {
        self.title = title
        self.current = current
        self.total = total
        self.color = color
        self.customText = customText
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title and progress text
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                if let customText = customText {
                    Text(customText)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("\(current)/\(total)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Progress bar
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 6)
                
                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.7), color]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, progress * UIScreen.main.bounds.width * 0.8), height: 6)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
    }
}

#if DEBUG
struct RetroProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            RetroTheme.retroDarkBlue.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                RetroProgressView(
                    title: "File Recovery",
                    current: 45,
                    total: 100,
                    color: RetroTheme.retroBlue
                )
                
                RetroProgressView(
                    title: "ROM Scanning",
                    current: 75,
                    total: 100,
                    color: RetroTheme.retroPurple
                )
                
                RetroProgressView(
                    title: "Upload Progress",
                    current: 30,
                    total: 100,
                    color: RetroTheme.retroPink,
                    customText: "30% (2 in queue)"
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.7))
            )
            .padding()
        }
    }
}
#endif
