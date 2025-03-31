import SwiftUI

/// Layer that renders the test pattern screens for a skin
struct DeltaSkinScreenLayer: View {
    let skin: any DeltaSkinProtocol
    let traits: DeltaSkinTraits
    let filters: Set<TestPatternEffect>
    let size: CGSize
    let screenAspectRatio: CGFloat?
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

    private struct ScreenDimensions {
        let width: CGFloat
        let height: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    private func logDimensions(
        _ dimensions: ScreenDimensions,
        layout: DeltaSkinView.SkinLayout,
        topButton: DeltaSkinButton,
        skinTopY: CGFloat,
        availableSpace: CGFloat
    ) {
        DLOG("""
        DeltaSkinScreenLayer dimensions:
          Container size: \(size)
          Layout: \(layout)
          Top button Y: \(topButton.frame.minY)
          Scaled top Y: \(skinTopY)
          Available space: \(availableSpace)
          Screen dimensions: \(dimensions)
        """)
    }

    private func calculateScreenDimensions(in exclusionSpace: CGFloat, layout: DeltaSkinView.SkinLayout) -> ScreenDimensions {
        guard let buttons = skin.buttons(for: traits),
              let topButton = buttons.min(by: { $0.frame.minY < $1.frame.minY }) else {
            return ScreenDimensions(width: 0, height: 0, x: 0, y: 0)
        }

        // Use full width of skin for screen width
        var screenWidth = layout.width

        // Calculate height based on aspect ratio
        let screenHeight = screenWidth / effectiveAspectRatio

        // Center in available space above skin
        let availableSpace = layout.yOffset  // Space between top of view and skin

        let dimensions = ScreenDimensions(
            width: screenWidth,
            height: screenHeight,
            x: (size.width - screenWidth) / 2,
            y: (availableSpace - screenHeight) / 2  // Center vertically in available space
        )

        DLOG("""
        Screen calculation details:
          Container height: \(size.height)
          Available space: \(availableSpace)
          Screen dimensions:
            - width: \(dimensions.width)
            - height: \(dimensions.height)
            - x: \(dimensions.x)
            - y: \(dimensions.y)
        """)

        return dimensions
    }

    var body: some View {
        if let layout = layout {
            // For skins without explicit screen position,
            // calculate screen area based on available space above skin
            if !hasScreenPosition(for: traits),
               let buttons = skin.buttons(for: traits) {
                // Calculate available space above skin
                let exclusionSpace = size.height - layout.height
                let dimensions = calculateScreenDimensions(in: exclusionSpace, layout: layout)

                DeltaSkinTestPatternView(
                    frame: CGRect(
                        x: dimensions.x,
                        y: dimensions.y,
                        width: dimensions.width,
                        height: dimensions.height
                    ),
                    filters: filters
                )
            } else {
                // Use normal screen positioning
                if let mappingSize = skin.mappingSize(for: traits) {
                    let scale = min(
                        size.width / mappingSize.width,
                        size.height / mappingSize.height
                    )
                    let xOffset = (size.width - (mappingSize.width * scale)) / 2
                    let yOffset = (size.height - (mappingSize.height * scale)) / 2
                    let offset = CGPoint(x: xOffset, y: yOffset)

                    Group {
                        if let explicitScreens = skin.screens(for: traits) {
                            // Render explicit screens (e.g. NDS dual screens)
                            ForEach(explicitScreens, id: \.id) { screen in
                                if let outputFrame = screen.outputFrame {
                                    let finalFrame = scaledFrame(
                                        outputFrame,
                                        mappingSize: mappingSize,
                                        scale: scale,
                                        offset: offset
                                    )
                                                                        
                                    DeltaSkinTestPatternView(
                                        frame: finalFrame,
                                        filters: filters
                                    ).onAppear {
                                        // DEBUG: Print the exact frame being used for color bars
                                        DLOG(
                                            """
                                            COLOR BARS FRAME: \(finalFrame) for screen \(screen.id)
                                            Original OutputFrame: \(outputFrame)
                                            MappingSize: \(mappingSize), Scale: \(scale), Offset: \(offset)
                                            """
                                            )
                                        
                                        // Broadcast the color bars frame via NotificationCenter
                                        // This will be used by the GPU view controller to match positioning
                                        let frameInfo: [String: Any] = [
                                            "frame": NSValue(cgRect: finalFrame),
                                            "screenId": screen.id,
                                            "outputFrame": NSValue(cgRect: outputFrame),
                                            "mappingSize": NSValue(cgSize: mappingSize),
                                            "scale": scale,
                                            "offset": NSValue(cgPoint: offset)
                                        ]
                                        
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("DeltaSkinColorBarsFrameUpdated"),
                                            object: nil,
                                            userInfo: frameInfo
                                        )
                                    }
                                }
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
                            
                            DeltaSkinTestPatternView(
                                frame: finalFrame,
                                filters: filters
                            ).onAppear {
                                // Broadcast the color bars frame via NotificationCenter
                                // This will be used by the GPU view controller to match positioning
                                let frameInfo: [String: Any] = [
                                    "frame": NSValue(cgRect: finalFrame),
                                    "outputFrame": NSValue(cgRect: outputFrame),
                                    "mappingSize": NSValue(cgSize: mappingSize),
                                    "scale": scale,
                                    "offset": NSValue(cgPoint: offset)
                                ]
                                
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("DeltaSkinColorBarsFrameUpdated"),
                                    object: nil,
                                    userInfo: frameInfo
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func scaledFrame(
        _ frame: CGRect,
        mappingSize: CGSize,
        scale: CGFloat,
        offset: CGPoint
    ) -> CGRect {
        CGRect(
            x: frame.minX * scale + offset.x,
            y: frame.minY * scale + offset.y,
            width: frame.width * scale,
            height: frame.height * scale
        )
    }
}
