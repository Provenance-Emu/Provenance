import SwiftUI

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollViewOffsetModifier: ViewModifier {
    let coordinateSpace: String
    @Binding var offset: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: ScrollViewOffsetPreferenceKey.self,
                            value: proxy.frame(in: .named(coordinateSpace)).minY
                        )
                }
            )
            .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
                offset = value
            }
    }
}

extension View {
    func trackScrollOffset(coordinateSpace: String = "scroll", offset: Binding<CGFloat>) -> some View {
        modifier(ScrollViewOffsetModifier(coordinateSpace: coordinateSpace, offset: offset))
    }
}
