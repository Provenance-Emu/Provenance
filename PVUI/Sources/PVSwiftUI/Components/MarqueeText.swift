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
        font: Font = .system(size: 14, weight: .bold, design: .monospaced),
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

    /// Calculate accurate text width with proper attributes
    private func calculateTextWidth(text: String, font: UIFont) -> CGFloat {
        // Check if font is monospaced
        if font.isMonospaced {
            // For monospaced fonts, we can calculate width directly
            // Get width of a single character (using 'M' as reference)
            let charWidth = ("M" as NSString).size(withAttributes: [.font: font]).width
            // Multiply by string length for total width
            return ceil(charWidth * CGFloat(text.count))
        }

        // Fallback to boundingRect for non-monospaced fonts
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]

        let size = (text as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesFontLeading, .usesLineFragmentOrigin],
            attributes: attributes,
            context: nil
        )

        return ceil(size.width)
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
                                    startAnimation()
                                }
                            }
                        }
                    )
                    .offset(x: offset)
            }
            .frame(width: containerWidth, alignment: .leading)
            .clipped()
            .contentShape(Rectangle())
        }
        .frame(height: 20)
        .clipped()
        .onAppear {
            isVisible = true
            if textWidth > containerWidth {
                startAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
            isVisible = false
        }
        .onChange(of: text) { newText in
            resetAnimation()
        }
    }

    private func stopAnimation() {
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

        let workItem = DispatchWorkItem { [self] in
            // Initial pause
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard isVisible else { return }
                withAnimation(.linear(duration: Double(textWidth - containerWidth) / speed)) {
                    offset = -(textWidth - containerWidth)
                }

                // Pause at end
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + Double(textWidth - containerWidth) / speed) {
                    guard isVisible else { return }
                    withAnimation(.linear(duration: Double(textWidth - containerWidth) / speed).delay(delay)) {
                        offset = 0
                    }

                    if loop {
                        // Pause at start before repeating
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay * 2 + Double(textWidth - containerWidth) * 2 / speed) {
                            guard isVisible else { return }
                            startAnimation()
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

// Add extension for UIFont to check if monospaced
private extension UIFont {
    var isMonospaced: Bool {
        // Check font traits for monospace
        let traits = fontDescriptor.symbolicTraits
        return traits.contains(.traitMonoSpace)
    }
}
