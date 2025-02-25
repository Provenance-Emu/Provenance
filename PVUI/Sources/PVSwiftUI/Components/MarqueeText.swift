import SwiftUI
import os

/// Logger for MarqueeText animations
private let logger = Logger(subsystem: "com.provenance.pvui", category: "MarqueeText")

/// A text view that automatically scrolls when content is too long
struct MarqueeText: View {
    let text: String
    let font: Font
    let delay: Double
    let speed: Double
    let loop: Bool

    /// Minimum font size we'll allow after scaling
    private let minimumFontSize: CGFloat = 8.0

    /// Default text style to use for scaling
    private let textStyle: UIFont.TextStyle = .body

    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var isVisible: Bool = false
    @State private var animationWorkItem: DispatchWorkItem?
    private let id = UUID()

    init(
        text: String,
        font: Font = .system(size: 15, weight: .bold, design: .monospaced),
        delay: Double = 1.0,
        speed: Double = 50.0,
        loop: Bool = true
    ) {
        self.text = text
        self.font = font
        self.delay = delay
        self.speed = speed
        self.loop = loop
    }

    /// Convert SwiftUI font to UIFont with proper scaling
    private func scaledFont(from swiftUIFont: Font) -> UIFont {
        // Extract size and weight from SwiftUI font if possible, or use defaults
        let baseSize: CGFloat = 14
        let baseWeight: UIFont.Weight = .bold

        // Create base monospaced font
        let baseFont = UIFont.monospacedSystemFont(ofSize: baseSize, weight: baseWeight)

        // Create metrics with our text style
        let metrics = UIFontMetrics(forTextStyle: textStyle)

        // Scale the font but ensure it doesn't go below our minimum
        let scaledFont = metrics.scaledFont(for: baseFont)
        if scaledFont.pointSize < minimumFontSize {
            return baseFont.withSize(minimumFontSize)
        }
        return scaledFont
    }

    /// Calculate accurate text width with proper attributes
    private func calculateTextWidth(text: String, font: UIFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: 0  // Ensure no extra kerning is applied
        ]

        // Use NSAttributedString for more accurate measurement
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        // Add a small proportional buffer (2% of text width)
        let buffer = ceil(boundingRect.width * 0.02)
        return ceil(boundingRect.width + buffer)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize()
                    .background(
                        GeometryReader { textGeometry in
                            Color.clear.onAppear {
                                /// Get properly scaled font
                                let uiFont = scaledFont(from: font)

                                /// Calculate accurate text width
                                textWidth = calculateTextWidth(text: text, font: uiFont)
                                containerWidth = geometry.size.width
                                logger.debug("Text measurements: text='\(text)', width=\(textWidth), container=\(containerWidth), fontSize=\(uiFont.pointSize)")

                                if textWidth > containerWidth && isVisible {
//                                    logger.debug("Starting animation for text: '\(text)'")
                                    startAnimation()
                                }
                            }
                        }
                    )
                    .offset(x: offset)
//                    .onChange(of: offset) { newOffset in
//                        logger.debug("Offset changed for '\(text)': \(newOffset)")
//                    }
            }
            .frame(width: containerWidth, alignment: .leading)
            .clipped()
            .contentShape(Rectangle())
        }
        .frame(height: 20)
        .clipped()
        .onAppear {
            logger.debug("MarqueeText appeared: '\(text)'")
            isVisible = true
            if textWidth > containerWidth {
                startAnimation()
            }
        }
        .onDisappear {
            logger.debug("MarqueeText disappeared: '\(text)'")
            stopAnimation()
            isVisible = false
        }
        .onChange(of: text) { newText in
            logger.debug("Text changed from '\(text)' to '\(newText)'")
            resetAnimation()
        }
    }

    private func stopAnimation() {
        logger.debug("Stopping animation for '\(text)'")
        animationWorkItem?.cancel()
        animationWorkItem = nil
        withAnimation(.linear(duration: 0.2)) {
            offset = 0
        }
    }

    private func resetAnimation() {
        stopAnimation()
        if isVisible && textWidth > containerWidth {
            startAnimation()
        }
    }

    private func startAnimation() {
        guard textWidth > containerWidth, isVisible else { return }

        // Cancel any existing animation
        stopAnimation()

        logger.debug("Animation cycle starting for '\(text)'")

        let workItem = DispatchWorkItem { [self] in
            // Initial pause
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard isVisible else { return }
                withAnimation(.linear(duration: Double(textWidth - containerWidth) / speed)) {
                    offset = -(textWidth - containerWidth)
                    logger.debug("Scrolling to end for '\(text)'")
                }

                // Pause at end
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + Double(textWidth - containerWidth) / speed) {
                    guard isVisible else { return }
                    withAnimation(.linear(duration: Double(textWidth - containerWidth) / speed).delay(delay)) {
                        offset = 0
                        logger.debug("Resetting to start for '\(text)'")
                    }

                    if loop {
                        // Pause at start before repeating
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay * 2 + Double(textWidth - containerWidth) * 2 / speed) {
                            guard isVisible else { return }
                            startAnimation()
                            logger.debug("Restarting animation cycle for '\(text)'")
                        }
                    }
                }
            }
        }

        animationWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }
}

#if DEBUG
struct MarqueeText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            MarqueeText(text: "Short text")
            MarqueeText(text: "This is a very long text that should scroll because it doesn't fit")
            MarqueeText(text: "Another long text", loop: false)
        }
        .padding()
    }
}
#endif
