import SwiftUI
import PVCoreAudio
import Accelerate

/// A SwiftUI Shape that draws a waveform path based on amplitude data
struct WaveformPath: Shape {
    /// The amplitude data to visualize
    let amplitudes: [CGFloat]
    
    /// Create a path for the waveform
    /// - Parameter rect: The rectangle to draw the path in
    /// - Returns: The path representing the waveform
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let midY = height / 2
        
        // Calculate point spacing
        let pointCount = amplitudes.count
        let pointSpacing = width / CGFloat(max(1, pointCount - 1))
        
        var path = Path()
        
        // Start at the left edge
        if pointCount > 0 {
            let startY = midY - (amplitudes[0] * midY)
            path.move(to: CGPoint(x: 0, y: startY))
            
            // Draw lines to each point
            for i in 1..<pointCount {
                let x = CGFloat(i) * pointSpacing
                let y = midY - (amplitudes[i] * midY)
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        return path
    }
}

/// A mirror waveform path that reflects the top waveform to create a complete visualization
struct MirrorWaveformPath: Shape {
    /// The amplitude data to visualize
    let amplitudes: [CGFloat]
    
    /// Create a path for the mirrored waveform
    /// - Parameter rect: The rectangle to draw the path in
    /// - Returns: The path representing the mirrored waveform
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let midY = height / 2
        
        // Calculate point spacing
        let pointCount = amplitudes.count
        let pointSpacing = width / CGFloat(max(1, pointCount - 1))
        
        var path = Path()
        
        // Start at the left edge
        if pointCount > 0 {
            // Top waveform
            let startY = midY - (amplitudes[0] * midY)
            path.move(to: CGPoint(x: 0, y: startY))
            
            // Draw lines to each point for top waveform
            for i in 1..<pointCount {
                let x = CGFloat(i) * pointSpacing
                let y = midY - (amplitudes[i] * midY)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // Bottom waveform (mirror of top)
            // Start from the right edge
            let lastIndex = pointCount - 1
            let lastX = CGFloat(lastIndex) * pointSpacing
            let lastY = midY + (amplitudes[lastIndex] * midY)
            path.addLine(to: CGPoint(x: lastX, y: lastY))
            
            // Draw lines back to the left for bottom waveform
            for i in (0..<lastIndex).reversed() {
                let x = CGFloat(i) * pointSpacing
                let y = midY + (amplitudes[i] * midY)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // Close the path
            path.closeSubpath()
        }
        
        return path
    }
}
