//
//  RetroArchiveExtractionProgressView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes

/// A progress view for archive extraction with retrowave styling
public struct RetroArchiveExtractionProgressView: View {
    // MARK: - Properties
    
    /// Current progress value (0.0 to 1.0)
    let progress: Double
    
    /// Current archive filename
    let filename: String
    
    /// Start time of the extraction
    let startTime: Date?
    
    /// Number of extracted files
    let extractedFilesCount: Int
    
    /// Computed progress percentage
    private var progressPercent: Int {
        Int(progress * 100)
    }
    
    /// Computed time elapsed since start
    private var timeElapsed: Int {
        guard let startTime = startTime else { return 0 }
        return Int(Date().timeIntervalSince(startTime))
    }
    
    // MARK: - Initialization
    
    /// Creates a new RetroArchiveExtractionProgressView
    /// - Parameters:
    ///   - progress: Current progress value (0.0 to 1.0)
    ///   - filename: Current archive filename
    ///   - startTime: Start time of the extraction
    ///   - extractedFilesCount: Number of extracted files
    public init(
        progress: Double,
        filename: String,
        startTime: Date?,
        extractedFilesCount: Int
    ) {
        self.progress = progress
        self.filename = filename
        self.startTime = startTime
        self.extractedFilesCount = extractedFilesCount
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title and progress text
            HStack {
                Text("Extracting: \(filename.split(separator: "/").last ?? "")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(progressPercent)% (\(extractedFilesCount) files, \(formatTimeInterval(seconds: timeElapsed)))")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
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
                            gradient: Gradient(colors: [RetroTheme.retroPurple.opacity(0.7), RetroTheme.retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, CGFloat(progress) * UIScreen.main.bounds.width * 0.8), height: 6)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
    }
    
    // MARK: - Helper Methods
    
    /// Format time interval in seconds to a readable string
    private func formatTimeInterval(seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\(minutes)m \(remainingSeconds)s"
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }
}

#if DEBUG
struct RetroArchiveExtractionProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            RetroTheme.retroDarkBlue.edgesIgnoringSafeArea(.all)
            
            RetroArchiveExtractionProgressView(
                progress: 0.65,
                filename: "game.zip",
                startTime: Date().addingTimeInterval(-120),
                extractedFilesCount: 42
            )
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
