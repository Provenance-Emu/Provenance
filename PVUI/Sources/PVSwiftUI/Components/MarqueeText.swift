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

    init(text: String, font: Font = .system(size: 15), delay: Double = 1.0, speed: Double = 50.0, loop: Bool = true) {
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
                            textWidth = textGeometry.size.width
                        }
                    })
                    .offset(x: offset)
                    .onAppear {
                        containerWidth = geometry.size.width
                        startAnimation()
                    }
                    .onChange(of: text) { _ in
                        offset = 0
                        startAnimation()
                    }
            }
            .clipped()
        }
    }

    private func startAnimation() {
        guard textWidth > containerWidth else { return }

        withAnimation(.linear(duration: (textWidth - containerWidth) / speed).delay(delay)) {
            offset = -(textWidth - containerWidth)
        }

        if loop {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + (textWidth - containerWidth) / speed) {
                offset = 0
                startAnimation()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + (textWidth - containerWidth) / speed) {
                withAnimation(.linear(duration: (textWidth - containerWidth) / speed).delay(delay)) {
                    offset = 0
                }
            }
        }
    }
}
