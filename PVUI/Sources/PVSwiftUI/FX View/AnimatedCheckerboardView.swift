import SwiftUI
import PVThemes

@available(iOS 18.0, *)
struct AnimatedCheckerboardView: View {
    
    @ObservedObject private var themeManager = ThemeManager.shared
    var currentPalette: any UXThemePalette { themeManager.currentPalette }

    // Computed properties for colors
    var color1: Color {
        currentPalette.gameLibraryBackground.swiftUIColor
    }
    
    var color2: Color {
        currentPalette.defaultTintColor?.swiftUIColor ?? .Provenance.blue
    }
    
    // Computed property for square size
    var squareSize: CGFloat {
        50 // Adjust this value to change the size of the squares
    }
    
    // Variables for animation speeds
    @State private var horizontalOffset: CGFloat = 0
    @State private var brightness: Double = 0.12
    
    let horizontalSpeed: Double = 1 // Adjust for faster/slower horizontal movement
    let brightnessSpeed: Double = 1.0 // Adjust for faster/slower brightness changes
    
    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geometry in
                let columns = Int(ceil(geometry.size.width / squareSize)) + 1
                let rows = Int(ceil(geometry.size.height / squareSize))
                
                ZStack {
                    ForEach(0..<rows, id: \.self) { row in
                        ForEach(0..<columns, id: \.self) { column in
                            Rectangle()
                                .fill(cellColor(row: row, column: column))
                                .frame(width: squareSize, height: squareSize)
                                .position(x: CGFloat(column) * squareSize + horizontalOffset,
                                          y: CGFloat(row) * squareSize + squareSize / 2)
                        }
                    }
                }
                .brightness(brightness - 1)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 10 / horizontalSpeed).repeatForever(autoreverses: false)) {
                horizontalOffset = -squareSize
            }
            withAnimation(.easeInOut(duration: 2 / brightnessSpeed).repeatForever(autoreverses: true)) {
                brightness = 0.5
            }
        }
    }
    
    private func cellColor(row: Int, column: Int) -> Color {
        let isEvenCell = (row + column) % 2 == 0
        return isEvenCell ? color1 : color2
    }
}

@available(iOS 18.0, *)
#Preview {
    AnimatedCheckerboardView()
}
