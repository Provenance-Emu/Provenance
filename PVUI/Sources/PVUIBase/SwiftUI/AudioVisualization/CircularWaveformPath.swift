import SwiftUI

/// A SwiftUI Shape that draws a circular waveform path around the Dynamic Island
public struct CircularWaveformPath: Shape {
    private let amplitudes: [CGFloat]
    private let baseRadius: CGFloat
    private let amplitudeScale: CGFloat
    
    /// Initialize the circular waveform path
    /// - Parameters:
    ///   - amplitudes: Array of amplitude values (0.0-1.0)
    ///   - baseRadius: Base radius of the circle
    ///   - amplitudeScale: Scale factor for the amplitude values
    public init(
        amplitudes: [CGFloat],
        baseRadius: CGFloat = 30,
        amplitudeScale: CGFloat = 10
    ) {
        self.amplitudes = amplitudes
        self.baseRadius = baseRadius
        self.amplitudeScale = amplitudeScale
    }
    
    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        return Path { path in
            // Don't draw if we have no data
            guard !amplitudes.isEmpty else { return }
            
            // Calculate the angle step based on number of points
            let angleStep = (2 * CGFloat.pi) / CGFloat(amplitudes.count)
            
            // Start at the right side of the circle (0 radians)
            var currentAngle: CGFloat = 0
            
            // Move to the first point
            let firstRadius = baseRadius + (amplitudes.first ?? 0) * amplitudeScale
            let firstPoint = CGPoint(
                x: center.x + firstRadius * cos(currentAngle),
                y: center.y + firstRadius * sin(currentAngle)
            )
            path.move(to: firstPoint)
            
            // Draw lines to each point around the circle
            for amplitude in amplitudes.dropFirst() {
                currentAngle += angleStep
                
                // Calculate radius with amplitude
                let radius = baseRadius + amplitude * amplitudeScale
                
                // Calculate point on circle
                let point = CGPoint(
                    x: center.x + radius * cos(currentAngle),
                    y: center.y + radius * sin(currentAngle)
                )
                
                path.addLine(to: point)
            }
            
            // Close the path
            path.closeSubpath()
        }
    }
}

/// A modified circular waveform that wraps around the Dynamic Island
public struct DynamicIslandCircularWaveform: Shape {
    private let amplitudes: [CGFloat]
    private let islandWidth: CGFloat
    private let islandHeight: CGFloat
    private let amplitudeScale: CGFloat
    private let padding: CGFloat
    private let smoothFactor: CGFloat
    
    /// Initialize the Dynamic Island circular waveform
    /// - Parameters:
    ///   - amplitudes: Array of amplitude values (0.0-1.0)
    ///   - islandWidth: Width of the Dynamic Island
    ///   - islandHeight: Height of the Dynamic Island
    ///   - amplitudeScale: Scale factor for the amplitude values
    ///   - padding: Padding around the Dynamic Island
    ///   - smoothFactor: How much to smooth the waveform (0.0-1.0)
    public init(
        amplitudes: [CGFloat],
        islandWidth: CGFloat = 126,
        islandHeight: CGFloat = 37,
        amplitudeScale: CGFloat = 3,
        padding: CGFloat = 2,
        smoothFactor: CGFloat = 0.7
    ) {
        self.amplitudes = amplitudes
        self.islandWidth = islandWidth
        self.islandHeight = islandHeight
        self.amplitudeScale = amplitudeScale
        self.padding = padding
        self.smoothFactor = smoothFactor
    }
    
    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        return Path { path in
            // Don't draw if we have no data
            guard !amplitudes.isEmpty else { return }
            
            // Calculate the base shape of the Dynamic Island with padding
            let baseWidth = islandWidth + padding * 2
            let baseHeight = islandHeight + padding * 2
            let cornerRadius = baseHeight / 2
            
            // Ensure we have enough points (at least 16 for 4 sides with 4 points each)
            if amplitudes.count < 16 {
                // If we don't have enough points, just draw a simple outline
                let outlinePath = RoundedRectangle(cornerRadius: baseHeight / 2).path(in: rect)
                path.addPath(outlinePath)
                return
            }
            
            // Number of points to draw - ensure it's divisible by 4 for our quarters
            let pointCount = (amplitudes.count / 4) * 4
            
            // We'll split the points around the pill shape
            // Each quarter of the shape gets pointCount/4 points
            
            // Start at the top right corner
            let startX = center.x + baseWidth / 2 - cornerRadius
            let startY = center.y - baseHeight / 2
            
            path.move(to: CGPoint(x: startX, y: startY))
            
        }
    }
    
    // Create a smooth path that follows the Dynamic Island shape with amplitude variations
    private func createSmoothDynamicIslandPath(center: CGPoint, width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> Path {
        var path = Path()
        
        // Calculate key points of the pill shape
        let leftX = center.x - width / 2
        let rightX = center.x + width / 2
        let topY = center.y - height / 2
        let bottomY = center.y + height / 2
        
        // Corner centers
        let topLeftCenter = CGPoint(x: leftX + cornerRadius, y: topY + cornerRadius)
        let topRightCenter = CGPoint(x: rightX - cornerRadius, y: topY + cornerRadius)
        let bottomLeftCenter = CGPoint(x: leftX + cornerRadius, y: bottomY - cornerRadius)
        let bottomRightCenter = CGPoint(x: rightX - cornerRadius, y: bottomY - cornerRadius)
        
        // Number of points per segment
        let pointsPerSide = min(amplitudes.count / 4, 12) // Limit to avoid too many points
        let pointsPerCorner = min(amplitudes.count / 8, 6)
        
        // Starting point - top middle
        let startPoint = CGPoint(x: center.x, y: topY)
        path.move(to: startPoint)
        
        var currentIndex = 0
        
        // Function to get a smoothed amplitude
        func getSmoothedAmplitude() -> CGFloat {
            guard !amplitudes.isEmpty else { return 0 }
            
            let rawAmplitude = amplitudes[currentIndex % amplitudes.count]
            let nextIndex = (currentIndex + 1) % amplitudes.count
            let nextAmplitude = amplitudes[nextIndex]
            
            // Apply smoothing between points
            let smoothedAmplitude = rawAmplitude * (1 - smoothFactor) + nextAmplitude * smoothFactor
            currentIndex = (currentIndex + 1) % amplitudes.count
            
            return smoothedAmplitude * amplitudeScale
        }
        
        // Calculate the base shape of the Dynamic Island with padding
        let baseWidth = islandWidth + padding * 2
        let baseHeight = islandHeight + padding * 2
        let cornerRadius = baseHeight / 2
        
        // Draw right side
        let rightTopY = center.y - baseHeight / 2 + cornerRadius
        let rightBottomY = center.y + baseHeight / 2 - cornerRadius
        
        // Top right quadrant
        for i in 0..<pointsPerSide {
            let t = CGFloat(i) / CGFloat(pointsPerSide)
            let x = center.x + t * (topRightCenter.x - center.x)
            let amplitude = getSmoothedAmplitude()
            let y = topY - amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Top right corner
        for i in 0..<pointsPerCorner {
            let angle = -CGFloat.pi/2 + CGFloat(i) / CGFloat(pointsPerCorner) * CGFloat.pi/2
            let amplitude = getSmoothedAmplitude()
            let radius = cornerRadius + amplitude
            let x = topRightCenter.x + radius * cos(angle)
            let y = topRightCenter.y + radius * sin(angle)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Right side
        for i in 0..<pointsPerSide {
            let t = CGFloat(i) / CGFloat(pointsPerSide)
            let y = topRightCenter.y + t * (bottomRightCenter.y - topRightCenter.y)
            let amplitude = getSmoothedAmplitude()
            let x = rightX + amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Bottom right corner
        for i in 0..<pointsPerCorner {
            let angle = 0 + CGFloat(i) / CGFloat(pointsPerCorner) * CGFloat.pi/2
            let amplitude = getSmoothedAmplitude()
            let radius = cornerRadius + amplitude
            let x = bottomRightCenter.x + radius * cos(angle)
            let y = bottomRightCenter.y + radius * sin(angle)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Bottom side
        for i in 0..<pointsPerSide {
            let t = CGFloat(i) / CGFloat(pointsPerSide)
            let x = bottomRightCenter.x - t * (bottomRightCenter.x - bottomLeftCenter.x)
            let amplitude = getSmoothedAmplitude()
            let y = bottomY + amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Bottom left corner
        for i in 0..<pointsPerCorner {
            let angle = CGFloat.pi/2 + CGFloat(i) / CGFloat(pointsPerCorner) * CGFloat.pi/2
            let amplitude = getSmoothedAmplitude()
            let radius = cornerRadius + amplitude
            let x = bottomLeftCenter.x + radius * cos(angle)
            let y = bottomLeftCenter.y + radius * sin(angle)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Left side
        for i in 0..<pointsPerSide {
            let t = CGFloat(i) / CGFloat(pointsPerSide)
            let y = bottomLeftCenter.y - t * (bottomLeftCenter.y - topLeftCenter.y)
            let amplitude = getSmoothedAmplitude()
            let x = leftX - amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Top left corner
        for i in 0..<pointsPerCorner {
            let angle = CGFloat.pi + CGFloat(i) / CGFloat(pointsPerCorner) * CGFloat.pi/2
            let amplitude = getSmoothedAmplitude()
            let radius = cornerRadius + amplitude
            let x = topLeftCenter.x + radius * cos(angle)
            let y = topLeftCenter.y + radius * sin(angle)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Top side (back to start)
        for i in 0..<pointsPerSide {
            let t = CGFloat(i) / CGFloat(pointsPerSide)
            let x = topLeftCenter.x + t * (center.x - topLeftCenter.x)
            let amplitude = getSmoothedAmplitude()
            let y = topY - amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Close the path
        path.closeSubpath()
        return path
    }
}
