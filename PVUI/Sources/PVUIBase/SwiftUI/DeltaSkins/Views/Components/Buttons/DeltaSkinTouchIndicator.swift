import SwiftUI

/// Visual indicator for touch location on the skin
struct DeltaSkinTouchIndicator: View {
    let location: CGPoint

    init(at location: CGPoint) {
        self.location = location
    }

    var body: some View {
        Circle()
            .stroke(.yellow, lineWidth: 2)
            .background(Circle().fill(.yellow.opacity(0.3)))
            .frame(width: 20, height: 20)
            .position(location)
            .transition(.opacity)
    }
}

#Preview {
    DeltaSkinTouchIndicator(at: CGPoint(x: 100, y: 100))
        .frame(width: 200, height: 200)
        .background(Color.black)
}
