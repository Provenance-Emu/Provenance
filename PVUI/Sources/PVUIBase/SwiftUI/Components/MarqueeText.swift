import SwiftUI
import PVLogging

/// A text view that automatically scrolls when content is too long
public struct MarqueeText: View {
    let text: String
    let font: Font
    let delay: Double
    let speed: Double
    let loop: Bool
    /// Initial delay before the first animation starts, allowing time for the user to read the beginning of the text
    let initialDelay: Double

    /// Minimum font size we'll allow after scaling
    private let minimumFontSize: CGFloat = 8.0

    /// Default text style to use for scaling
    private let textStyle: UIFont.TextStyle = .body

    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var isVisible: Bool = false
    @State private var animationWorkItem: DispatchWorkItem?
    /// Track whether the view is currently in the view hierarchy
    @State private var isInViewHierarchy: Bool = false
    /// Track whether the app is in the foreground
    @Environment(\.scenePhase) private var scenePhase
    /// Track if text width has been calculated
    @State private var hasCalculatedWidth: Bool = false
    private let id = UUID()

    /// Creates a marquee text view that scrolls when content is too long
    /// - Parameters:
    ///   - text: The text to display
    ///   - font: The font to use for the text
    ///   - delay: The delay between animations (pause at each end)
    ///   - speed: The speed of the animation (pixels per second)
    ///   - loop: Whether to loop the animation continuously
    ///   - initialDelay: The delay before the first animation starts, allowing the user to read the beginning of the text before it starts scrolling
    public init(
        text: String,
        font: Font = .system(size: 14, weight: .bold, design: .monospaced),
        delay: Double = 1.0,
        speed: Double = 50.0,
        loop: Bool = true,
        initialDelay: Double = 2.0 /// Default initial delay of 2 seconds
    ) {
        self.text = text
        self.font = font
        self.delay = delay
        self.speed = speed
        self.loop = loop
        self.initialDelay = initialDelay
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

    /// Check if the animation should be running based on all visibility factors
    private var shouldAnimationRun: Bool {
        /// Animation should run only if:
        /// 1. The view is in the view hierarchy
        /// 2. The text is wider than the container (or width hasn't been calculated yet)
        /// 3. The app is in the active scene phase
        return isInViewHierarchy && (!hasCalculatedWidth || textWidth > containerWidth) && scenePhase == .active
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize()
                    .background(
                        GeometryReader { textGeometry in
                            Color.clear.onAppear {
                                // Store the container width for later use
                                containerWidth = geometry.size.width
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
            /// Mark the view as in the hierarchy
            isInViewHierarchy = true

            /// Start animation if needed
            if shouldAnimationRun {
                startAnimation()
            }

            DLOG("MarqueeText appeared: '\(text.prefix(20))...'")
        }
        .onDisappear {
            /// Mark the view as not in the hierarchy and stop animation
            isInViewHierarchy = false
            stopAnimation()

            DLOG("MarqueeText disappeared: '\(text.prefix(20))...'")
        }
        .onChange(of: text) { newText in
            // Reset width calculation flag when text changes
            hasCalculatedWidth = false
            resetAnimation()
        }
        /// Monitor scene phase changes to pause/resume animations
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
        /// Use ViewModifier to detect when the view becomes visible or hidden
        .modifier(VisibilityAwareModifier(onVisibilityChanged: { isVisible in
            self.isVisible = isVisible
            if isVisible {
                if shouldAnimationRun {
                    startAnimation()
                }
            } else {
                stopAnimation()
            }
        }))
    }

    /// Handle scene phase changes (app going to background/foreground)
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            /// App came to foreground, restart animation if needed
            if shouldAnimationRun {
                startAnimation()
            }
            DLOG("MarqueeText scene active: '\(text.prefix(20))...'")
        case .inactive, .background:
            /// App went to background, pause animation
            stopAnimation()
            DLOG("MarqueeText scene inactive/background: '\(text.prefix(20))...'")
        @unknown default:
            break
        }
    }

    private func stopAnimation() {
        /// Cancel any pending animation work
        animationWorkItem?.cancel()
        animationWorkItem = nil

        /// Reset offset with a quick animation
        withAnimation(.linear(duration: 0.2)) {
            offset = 0
        }

        DLOG("MarqueeText animation stopped: '\(text.prefix(20))...'")
    }

    private func resetAnimation() {
        stopAnimation()
        if shouldAnimationRun {
            startAnimation()
        }
    }

    /// Calculate text width if it hasn't been calculated yet
    private func ensureTextWidthCalculated() {
        if !hasCalculatedWidth {
            /// Get properly scaled font
            let uiFont = scaledFont(from: font)

            /// Calculate accurate text width
            textWidth = calculateTextWidth(text: text, font: uiFont)
            hasCalculatedWidth = true

            DLOG("Text measurements: text='\(text)', width=\(textWidth), container=\(containerWidth), fontSize=\(uiFont.pointSize)")
        }
    }

    private func startAnimation() {
        guard shouldAnimationRun else {
            DLOG("MarqueeText animation not started (conditions not met): '\(text.prefix(20))...'")
            return
        }

        /// Calculate text width if needed
        ensureTextWidthCalculated()

        /// Check if text actually needs scrolling after width calculation
        if textWidth <= containerWidth {
            DLOG("MarqueeText animation not needed (text fits): '\(text.prefix(20))...'")
            return
        }

        /// Cancel any existing animation
        stopAnimation()

        let workItem = DispatchWorkItem { [self] in
            /// Use initialDelay for the first animation, then regular delay for subsequent ones
            let currentDelay = (offset == 0) ? initialDelay : delay

            /// Log the animation start with appropriate delay
            DLOG("Starting marquee animation for '\(text.prefix(20))...' with \(offset == 0 ? "initial" : "regular") delay of \(currentDelay)s")

            /// Initial pause
            DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) {
                /// Check if animation should still run
                guard shouldAnimationRun else { return }

                withAnimation(.linear(duration: Double(textWidth - containerWidth) / speed)) {
                    offset = -(textWidth - containerWidth)
                }

                /// Pause at end
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + Double(textWidth - containerWidth) / speed) {
                    /// Check if animation should still run
                    guard shouldAnimationRun else { return }

                    withAnimation(.linear(duration: Double(textWidth - containerWidth) / speed).delay(delay)) {
                        offset = 0
                    }

                    if loop {
                        /// Pause at start before repeating
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay * 2 + Double(textWidth - containerWidth) * 2 / speed) {
                            /// Check if animation should still run
                            guard shouldAnimationRun else { return }
                            startAnimation()
                        }
                    }
                }
            }
        }

        animationWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)

        DLOG("MarqueeText animation started: '\(text.prefix(20))...'")
    }
}

/// ViewModifier to detect when a view becomes visible or hidden
struct VisibilityAwareModifier: ViewModifier {
    let onVisibilityChanged: (Bool) -> Void

    func body(content: Content) -> some View {
        content
            .background(
                VisibilityDetector(onVisibilityChanged: onVisibilityChanged)
            )
    }
}

/// Helper view to detect visibility changes
struct VisibilityDetector: UIViewRepresentable {
    let onVisibilityChanged: (Bool) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            /// Check if the view is in a window and visible
            let isVisible = uiView.window != nil && !uiView.isHidden && uiView.alpha > 0 && uiView.frame.size != .zero

            /// Only report visibility changes
            if context.coordinator.lastIsVisible != isVisible {
                context.coordinator.lastIsVisible = isVisible
                onVisibilityChanged(isVisible)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var lastIsVisible: Bool?
    }
}

#if DEBUG
struct MarqueeText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            MarqueeText(text: "Short text")
                .background(Color.gray.opacity(0.2))

            MarqueeText(text: "This is a very long text that should scroll because it doesn't fit",
                       initialDelay: 1.0)
                .background(Color.gray.opacity(0.2))

            MarqueeText(text: "Another long text with default initial delay (2s)",
                       loop: false)
                .background(Color.gray.opacity(0.2))

            MarqueeText(text: "This text has a longer initial delay of 4 seconds",
                       initialDelay: 4.0)
                .background(Color.gray.opacity(0.2))
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
