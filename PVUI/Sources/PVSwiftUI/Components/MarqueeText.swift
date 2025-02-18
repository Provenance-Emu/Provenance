import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    let delay: Double
    let speed: Double
    let loop: Bool

    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var isAnimating: Bool = false

    init(text: String, font: Font = .system(size: 15, weight: .bold, design: .monospaced), delay: Double = 1.0, speed: Double = 50.0, loop: Bool = true) {
        self.text = text
        self.font = font
        self.delay = delay
        self.speed = speed
        self.loop = loop
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize()
                    .background(GeometryReader { textGeometry in
                        Color.clear.onAppear {
                            // Calculate text width with a small buffer
                            let textSize = text.size(withAttributes: [.font: UIFont.systemFont(ofSize: 15, weight: .bold)])
                            textWidth = textSize.width + 10 /// Add 10pt buffer
                            containerWidth = geometry.size.width
                            if textWidth > containerWidth {
                                startAnimation()
                            }
                        }
                    })
                    .offset(x: offset)
                    .animation(.linear(duration: Double(textWidth - containerWidth) / speed).delay(delay), value: offset)
                    .onChange(of: text) { _ in
                        offset = 0
                        startAnimation()
                    }
            }
            .frame(width: containerWidth, alignment: .leading)
            .clipped()
            .contentShape(Rectangle())
        }
        .frame(height: 20) // Fixed height to prevent layout issues
        .clipped()
    }

    private func startAnimation() {
        guard textWidth > containerWidth else { return }

        // Initial pause
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.linear(duration: Double(textWidth - containerWidth) / speed)) {
                offset = -(textWidth - containerWidth)
            }

            // Pause at end
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + Double(textWidth - containerWidth) / speed) {
                withAnimation(.linear(duration: Double(textWidth - containerWidth) / speed).delay(delay)) {
                    offset = 0
                }

                if loop {
                    // Pause at start before repeating
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay * 2 + Double(textWidth - containerWidth) * 2 / speed) {
                        startAnimation()
                    }
                }
            }
        }
    }
}
