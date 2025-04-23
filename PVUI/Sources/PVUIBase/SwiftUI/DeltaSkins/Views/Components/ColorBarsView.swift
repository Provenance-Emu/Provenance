import SwiftUI

struct ColorBarsView: View {
    @State private var patternIndex = 0
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var currentPattern: DeltaSkinTestPattern {
        DeltaSkinTestPattern.allCases[patternIndex]
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(Array(currentPattern.colors.enumerated()), id: \.offset) { _, color in
                    Rectangle()
                        .fill(color)
                }
            }
            .overlay(
                Text(currentPattern.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .shadow(radius: 1)
                    .padding(4),
                alignment: .topLeading
            )
        }
        .onReceive(timer) { _ in
            withAnimation {
                patternIndex = (patternIndex + 1) % DeltaSkinTestPattern.allCases.count
            }
        }
    }
}
