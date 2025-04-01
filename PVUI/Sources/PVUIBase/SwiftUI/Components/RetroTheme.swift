import SwiftUI
import PVUIBase

/// RetroTheme provides retrowave styling elements for the Settings UI
public struct RetroTheme {
    // MARK: - Colors
    public static let retroPink = Color(red: 0.99, green: 0.11, blue: 0.55)
    public static let retroPurple = Color(red: 0.53, green: 0.11, blue: 0.91)
    public static let retroBlue = Color(red: 0.0, green: 0.75, blue: 0.95)
    public static let retroDarkBlue = Color(red: 0.05, green: 0.05, blue: 0.2)
    public static let retroBlack = Color(red: 0.05, green: 0.0, blue: 0.1)
    
    // MARK: - Gradients
    public static let retroGradient = LinearGradient(
        gradient: Gradient(colors: [retroPink, retroPurple, retroBlue]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let retroHorizontalGradient = LinearGradient(
        gradient: Gradient(colors: [retroPink, retroPurple, retroBlue]),
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Text Styles
    public static func retroTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(retroHorizontalGradient)
    }
    
    public static func retroText(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.white)
    }
    
    // MARK: - Background Styles
    public static var retroBackground: some View {
        ZStack {
            // Dark background
            retroBlack.edgesIgnoringSafeArea(.all)
            
            // Grid overlay
            RetroGridView()
                .edgesIgnoringSafeArea(.all)
                .opacity(0.3)
        }
    }
    
    // MARK: - Button Styles
    public struct RetroButtonStyle: ButtonStyle {
        public func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    configuration.isPressed ? RetroTheme.retroPink : RetroTheme.retroPink,
                                    lineWidth: 2
                                )
                        )
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Section Styles
    public struct RetroSectionStyle: ViewModifier {
        public func body(content: Content) -> some View {
            content
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(RetroTheme.retroGradient, lineWidth: 1)
                        )
                )
                .shadow(color: RetroTheme.retroPurple.opacity(0.3), radius: 10, x: 0, y: 5)
        }
    }
    
    // MARK: - Toggle Style
    public struct RetroToggleStyle: ToggleStyle {
        @State private var isAnimating = false
        
        public init() {}
        
        public func makeBody(configuration: Configuration) -> some View {
            HStack {
                configuration.label
                
                Spacer()
                
                ZStack {
                    // Background track
                    Group {
                        if configuration.isOn {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(gradient: Gradient(colors: [retroPurple.opacity(0.6), retroBlue.opacity(0.6)]),
                                                   startPoint: .leading,
                                                   endPoint: .trailing))
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.5))
                        }
                    }
                    .frame(width: 50, height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [retroPink, retroBlue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                    
                    // Thumb/knob
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.white, .gray.opacity(0.7)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 24, height: 24)
                            .shadow(color: configuration.isOn ? retroPink.opacity(0.7) : Color.black.opacity(0.3),
                                    radius: configuration.isOn ? 5 : 2)
                        
                        // Glow effect when on
                        if configuration.isOn {
                            Circle()
                                .fill(retroPink)
                                .frame(width: 10, height: 10)
                                .blur(radius: 3)
                                .opacity(isAnimating ? 0.7 : 0.4)
                                .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                                .onAppear { isAnimating = true }
                        }
                    }
                    .offset(x: configuration.isOn ? 11 : -11)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: configuration.isOn)
                }
                .onTapGesture {
                    withAnimation {
                        configuration.isOn.toggle()
                    }
                }
            }
        }
    }
    
    // MARK: - Supporting Views
    
    /// RetroGrid creates a grid background for retrowave aesthetic
    public struct RetroGridView: View {
        public var body: some View {
            GeometryReader { geometry in
                ZStack {
                    // Horizontal grid lines
                    VStack(spacing: 20) {
                        ForEach(0..<Int(geometry.size.height / 20) + 1, id: \.self) { index in
                            Rectangle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [.clear, RetroTheme.retroPink.opacity(0.3), .clear]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(height: 1)
                        }
                    }
                    
                    // Vertical grid lines
                    HStack(spacing: 20) {
                        ForEach(0..<Int(geometry.size.width / 20) + 1, id: \.self) { index in
                            Rectangle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [.clear, RetroTheme.retroPink.opacity(0.2), .clear]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .frame(width: 1)
                        }
                    }
                }
            }
        }
    }
    
    /// RetroIcon creates a stylized icon with retrowave styling
    struct RetroIcon: View {
        let systemName: String
        
        var body: some View {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .strokeBorder(RetroTheme.retroGradient, lineWidth: 1.5)
                    )
                
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RetroTheme.retroHorizontalGradient)
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    func retroSectionStyle() -> some View {
        self.modifier(RetroTheme.RetroSectionStyle())
    }
}
