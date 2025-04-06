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
    
    /// Initialize the Dynamic Island circular waveform
    /// - Parameters:
    ///   - amplitudes: Array of amplitude values (0.0-1.0)
    ///   - islandWidth: Width of the Dynamic Island
    ///   - islandHeight: Height of the Dynamic Island
    ///   - amplitudeScale: Scale factor for the amplitude values
    ///   - padding: Padding around the Dynamic Island
    public init(
        amplitudes: [CGFloat],
        islandWidth: CGFloat = 126,
        islandHeight: CGFloat = 37,
        amplitudeScale: CGFloat = 5,
        padding: CGFloat = 2
    ) {
        self.amplitudes = amplitudes
        self.islandWidth = islandWidth
        self.islandHeight = islandHeight
        self.amplitudeScale = amplitudeScale
        self.padding = padding
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
            
            // Draw top right quarter-circle
            var currentIndex = 0
            let pointsPerQuarter = pointCount / 4
            
            // Top right quarter-circle
            for i in 0..<pointsPerQuarter {
                let angle = CGFloat.pi * 3/2 + CGFloat(i) / CGFloat(pointsPerQuarter) * CGFloat.pi / 2
                // Safely get amplitude with bounds checking
                let amplitude = currentIndex < amplitudes.count ? amplitudes[currentIndex] * amplitudeScale : 0
                currentIndex = (currentIndex + 1) % amplitudes.count
                
                let radius = cornerRadius + amplitude
                let x = startX + radius * cos(angle)
                let y = startY + radius * sin(angle)
                
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // Draw right side
            let rightX = center.x + baseWidth / 2
            let rightTopY = center.y - baseHeight / 2 + cornerRadius
            let rightBottomY = center.y + baseHeight / 2 - cornerRadius
            
            // Right side - straight line with variations
            for i in 0..<pointsPerQuarter {
                let t = CGFloat(i) / CGFloat(pointsPerQuarter)
                // Safely get amplitude with bounds checking
                let amplitude = currentIndex < amplitudes.count ? amplitudes[currentIndex] * amplitudeScale : 0
                currentIndex = (currentIndex + 1) % amplitudes.count
                
                let y = rightTopY + t * (rightBottomY - rightTopY)
                let x = rightX + amplitude
                
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // Bottom right quarter-circle
            for i in 0..<pointsPerQuarter {
                let angle = 0 + CGFloat(i) / CGFloat(pointsPerQuarter) * CGFloat.pi / 2
                // Safely get amplitude with bounds checking
                let amplitude = currentIndex < amplitudes.count ? amplitudes[currentIndex] * amplitudeScale : 0
                currentIndex = (currentIndex + 1) % amplitudes.count
                
                let radius = cornerRadius + amplitude
                let x = startX + radius * cos(angle)
                let y = rightBottomY + radius * sin(angle)
                
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // Bottom side - straight line with variations
            let bottomY = center.y + baseHeight / 2
            let bottomLeftX = center.x - baseWidth / 2 + cornerRadius
            let bottomRightX = center.x + baseWidth / 2 - cornerRadius
            
            for i in 0..<pointsPerQuarter {
                let t = CGFloat(i) / CGFloat(pointsPerQuarter)
                // Safely get amplitude with bounds checking
                let amplitude = currentIndex < amplitudes.count ? amplitudes[currentIndex] * amplitudeScale : 0
                currentIndex = (currentIndex + 1) % amplitudes.count
                
                let x = bottomRightX - t * (bottomRightX - bottomLeftX)
                let y = bottomY + amplitude
                
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // Bottom left quarter-circle
            for i in 0..<pointsPerQuarter {
                let angle = CGFloat.pi / 2 + CGFloat(i) / CGFloat(pointsPerQuarter) * CGFloat.pi / 2
                // Safely get amplitude with bounds checking
                let amplitude = currentIndex < amplitudes.count ? amplitudes[currentIndex] * amplitudeScale : 0
                currentIndex = (currentIndex + 1) % amplitudes.count // Wrap around if needed
                
                let radius = cornerRadius + amplitude
                let x = bottomLeftX - radius * cos(angle)
                let y = rightBottomY + radius * sin(angle)
                
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // Left side - straight line with variations
            let leftX = center.x - baseWidth / 2
            
            for i in 0..<pointsPerQuarter {
                let t = CGFloat(i) / CGFloat(pointsPerQuarter)
                // Safely get amplitude with bounds checking
                let amplitude = currentIndex < amplitudes.count ? amplitudes[currentIndex] * amplitudeScale : 0
                currentIndex = (currentIndex + 1) % amplitudes.count
                
                let y = rightBottomY - t * (rightBottomY - rightTopY)
                let x = leftX - amplitude
                
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // Top left quarter-circle
            for i in 0..<pointsPerQuarter {
                let angle = CGFloat.pi + CGFloat(i) / CGFloat(pointsPerQuarter) * CGFloat.pi / 2
                // Safely get amplitude with bounds checking
                let amplitude = currentIndex < amplitudes.count ? amplitudes[currentIndex] * amplitudeScale : 0
                currentIndex = (currentIndex + 1) % amplitudes.count
                
                let radius = cornerRadius + amplitude
                let x = bottomLeftX - radius * cos(angle)
                let y = startY - radius * sin(angle)
                
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // Top side - straight line with variations
            let topY = center.y - baseHeight / 2
            
            for i in 0..<pointsPerQuarter {
                let t = CGFloat(i) / CGFloat(pointsPerQuarter)
                // Safely get amplitude with bounds checking
                let amplitude = currentIndex < amplitudes.count ? amplitudes[currentIndex] * amplitudeScale : 0
                currentIndex = (currentIndex + 1) % amplitudes.count
                
                let x = bottomLeftX + t * (bottomRightX - bottomLeftX)
                let y = topY - amplitude
                
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // Close the path
            path.closeSubpath()
        }
    }
}
