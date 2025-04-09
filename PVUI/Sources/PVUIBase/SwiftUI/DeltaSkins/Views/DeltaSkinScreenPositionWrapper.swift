import SwiftUI
import PVLogging

/// Wrapper view that calculates and broadcasts screen positions, regardless of whether color bars are visible
struct DeltaSkinScreenPositionWrapper: View {
    let skin: any DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let filters: Set<TestPatternEffect>
    let size: CGSize
    let screenAspectRatio: CGFloat?
    let isInEmulator: Bool
    
    @Environment(\.skinLayout) var layout
    
    private var effectiveAspectRatio: CGFloat {
        screenAspectRatio ?? (4.0/3.0)  // Default to 4:3 if none specified
    }
    
    private func hasScreenPosition(for traits: DeltaSkinTraits) -> Bool {
        // Check both formats
        if let screens = skin.screens(for: traits), !screens.isEmpty {
            return true
        }

        // Check if representation has gameScreenFrame
        if let representations = skin.jsonRepresentation["representations"] as? [String: Any],
           let deviceRep = representations[traits.device.rawValue] as? [String: Any],
           let displayRep = deviceRep[traits.displayType.rawValue] as? [String: Any],
           let orientationRep = displayRep[traits.orientation.rawValue] as? [String: Any],
           orientationRep["gameScreenFrame"] != nil {
            return true
        }

        return false
    }
    
    private func calculateScreenFrame() -> CGRect? {
        guard let layout = layout else { return nil }
        
        if hasScreenPosition(for: traits) {
            // Use explicit screen position from skin
            if let mappingSize = skin.mappingSize(for: traits) {
                let scale = min(
                    size.width / mappingSize.width,
                    size.height / mappingSize.height
                )
                let xOffset = (size.width - (mappingSize.width * scale)) / 2
                let yOffset = (size.height - (mappingSize.height * scale)) / 2
                let offset = CGPoint(x: xOffset, y: yOffset)
                
                if let screens = skin.screens(for: traits), let screen = screens.first {
                    if let outputFrame = screen.outputFrame {
                        let finalFrame = scaledFrame(
                            outputFrame,
                            mappingSize: mappingSize,
                            scale: scale,
                            offset: offset
                        )
                        
                        // Broadcast the frame position
                        broadcastFramePosition(finalFrame, outputFrame: outputFrame, mappingSize: mappingSize, scale: scale, offset: offset, screenId: screen.id)
                        
                        return finalFrame
                    }
                } else {
                    // Default single screen
                    let outputFrame = DeltaSkinDefaults.defaultScreenFrame(
                        for: skin.gameType,
                        in: mappingSize,
                        buttons: skin.buttons(for: traits),
                        isPreview: false
                    )
                    
                    let finalFrame = scaledFrame(
                        outputFrame,
                        mappingSize: mappingSize,
                        scale: scale,
                        offset: offset
                    )
                    
                    // Broadcast the frame position
                    broadcastFramePosition(finalFrame, outputFrame: outputFrame, mappingSize: mappingSize, scale: scale, offset: offset)
                    
                    return finalFrame
                }
            }
        } else {
            // Calculate position based on available space
            guard let buttons = skin.buttons(for: traits) else { return nil }
            
            // Calculate available space above skin
            let exclusionSpace = size.height - layout.height
            
            // Find topmost button
            guard let topButton = buttons.min(by: { $0.frame.minY < $1.frame.minY }) else { return nil }
            
            // Use full width of skin for screen width
            let screenWidth = layout.width
            
            // Calculate height based on aspect ratio
            let screenHeight = screenWidth / effectiveAspectRatio
            
            // Center in available space above skin
            let availableSpace = layout.yOffset  // Space between top of view and skin
            
            let x = (size.width - screenWidth) / 2
            let y = (availableSpace - screenHeight) / 2  // Center vertically in available space
            
            let finalFrame = CGRect(
                x: x,
                y: y,
                width: screenWidth,
                height: screenHeight
            )
            
            // Broadcast the frame position
            broadcastFramePosition(finalFrame)
            
            return finalFrame
        }
        
        return nil
    }
    
    private func scaledFrame(_ frame: CGRect, mappingSize: CGSize, scale: CGFloat, offset: CGPoint) -> CGRect {
        return CGRect(
            x: (frame.origin.x * scale) + offset.x,
            y: (frame.origin.y * scale) + offset.y,
            width: frame.size.width * scale,
            height: frame.size.height * scale
        )
    }
    
    private func broadcastFramePosition(_ frame: CGRect, outputFrame: CGRect? = nil, mappingSize: CGSize? = nil, scale: CGFloat? = nil, offset: CGPoint? = nil, screenId: String? = nil) {
        // Only broadcast if we're in the emulator
        if isInEmulator {
            var frameInfo: [String: Any] = [
                "frame": NSValue(cgRect: frame)
            ]
            
            if let outputFrame = outputFrame {
                frameInfo["outputFrame"] = NSValue(cgRect: outputFrame)
            }
            
            if let mappingSize = mappingSize {
                frameInfo["mappingSize"] = NSValue(cgSize: mappingSize)
            }
            
            if let scale = scale {
                frameInfo["scale"] = scale
            }
            
            if let offset = offset {
                frameInfo["offset"] = NSValue(cgPoint: offset)
            }
            
            if let screenId = screenId {
                frameInfo["screenId"] = screenId
            }
            
            // Log the frame being broadcast
            DLOG("Broadcasting screen position frame: \(frame)")
            
            // Broadcast the frame via NotificationCenter
            NotificationCenter.default.post(
                name: NSNotification.Name("DeltaSkinColorBarsFrameUpdated"),
                object: nil,
                userInfo: frameInfo
            )
        }
    }
    
    var body: some View {
        ZStack {
            // Only show the color bars if we're not in the emulator
            if !isInEmulator {
                DeltaSkinScreenLayer(
                    skin: skin,
                    traits: traits,
                    filters: filters,
                    size: size,
                    screenAspectRatio: screenAspectRatio
                )
            } else {
                // In emulator mode, we still need to calculate and broadcast the position
                // but we don't actually render anything visible
                Color.clear
                    .onAppear {
                        // Calculate and broadcast the frame on appear
                        _ = calculateScreenFrame()
                    }
                    .onChange(of: size) { _ in
                        // Recalculate when the size changes
                        _ = calculateScreenFrame()
                    }
                    .onChange(of: layout) { _ in
                        // Recalculate when the layout changes
                        _ = calculateScreenFrame()
                    }
            }
        }
    }
}
