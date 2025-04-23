import SwiftUI
import PVThemes

/// A retrowave-themed option picker for selecting between different visualizer modes
public struct RetrowaveOptionPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [(value: T, label: String)]
    let title: String
    
    @State private var isHovering = false
    @State private var animationAmount: CGFloat = 1.0
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(title: String, selection: Binding<T>, options: [(value: T, label: String)]) {
        self.title = title
        self._selection = selection
        self.options = options
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Title
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Color.retroPink)
                .padding(.bottom, 4)
            
            // Options
            HStack(spacing: 0) {
                ForEach(0..<options.count, id: \.self) { index in
                    optionButton(for: options[index], isFirst: index == 0, isLast: index == options.count - 1)
                }
            }
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.6) : Color.black.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.retroPink, Color.retroPurple, Color.retroCyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.retroPink.opacity(0.5), radius: 8, x: 0, y: 0)
            )
        }
        .padding(.horizontal, 16)
    }
    
    private func optionButton(for option: (value: T, label: String), isFirst: Bool, isLast: Bool) -> some View {
        let isSelected = selection == option.value
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selection = option.value
                animationAmount = 1.2
                
                // Reset animation after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animationAmount = 1.0
                }
            }
        }) {
            Text(option.label)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? Color.white : Color.gray)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: isFirst ? 10 : isLast ? 10 : 0)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.retroPink.opacity(0.8), Color.retroPurple.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: isFirst ? 10 : isLast ? 10 : 0)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.retroPink, Color.retroCyan],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .shadow(color: Color.retroPink.opacity(0.5), radius: 4, x: 0, y: 0)
                                .scaleEffect(animationAmount)
                                .animation(.easeInOut(duration: 0.2), value: animationAmount)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: isFirst ? 10 : isLast ? 10 : 0))
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct RetrowaveOptionPicker_Previews: PreviewProvider {
    enum VisualizerMode: String, CaseIterable {
        case off = "Off"
        case standard = "Standard"
        case metal = "Metal"
    }
    
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            RetrowaveOptionPicker(
                title: "Visualizer Mode",
                selection: .constant(VisualizerMode.metal),
                options: VisualizerMode.allCases.map { ($0, $0.rawValue) }
            )
            .padding()
        }
    }
}
