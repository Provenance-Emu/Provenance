///
/// RetroAlertView.swift
/// Provenance
///
/// A native SwiftUI alert replacement with RetroWave styling
/// Created by Joseph Mattiello on 04/07/25.
///

import SwiftUI
import PVThemes

/// A retrowave-themed alert view that replaces UIKit alerts with native SwiftUI
public struct RetroAlertView<Content: View>: View {
    // MARK: - Properties
    
    /// The title of the alert
    private let title: String
    
    /// The message of the alert
    private let message: String
    
    /// Binding to control presentation
    @Binding private var isPresented: Bool
    
    /// Optional text field binding
    private let textFieldBinding: Binding<String?>?
    
    /// Text field configuration
    private let textFieldConfiguration: ((UITextField) -> Void)?
    
    /// Content builder for buttons
    private let content: Content
    
    /// Animation state for glow effect
    @State private var glowOpacity: Double = 0.7
    
    // MARK: - Initialization
    
    /// Creates a new RetroAlertView
    /// - Parameters:
    ///   - title: The title of the alert
    ///   - message: The message of the alert
    ///   - isPresented: Binding to control presentation
    ///   - textFieldBinding: Optional binding for text field value
    ///   - textFieldConfiguration: Optional configuration for the text field
    ///   - content: Content builder for buttons
    public init(
        title: String,
        message: String,
        isPresented: Binding<Bool>,
        textFieldBinding: Binding<String?>? = nil,
        textFieldConfiguration: ((UITextField) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.message = message
        self._isPresented = isPresented
        self.textFieldBinding = textFieldBinding
        self.textFieldConfiguration = textFieldConfiguration
        self.content = content()
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Optional: Dismiss on background tap
                    // isPresented = false
                }
            
            // Alert container
            VStack(spacing: 20) {
                // Title
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                
                // Message
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                // Text field if provided
                if let textBinding = textFieldBinding {
                    RetroTextField(text: textBinding, configuration: textFieldConfiguration)
                        .padding(.horizontal, 20)
                        .padding(.top, 5)
                }
                
                // Buttons
                content
                    .padding(.bottom, 20)
                    .padding(.horizontal, 20)
            }
            .frame(width: 300)
            .background(
                ZStack {
                    // Base background
                    Color.retroBlack
                    
                    // Grid pattern
                    RetroAlertGridPattern()
                        .opacity(0.3)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroBlue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: Color.retroPink.opacity(glowOpacity), radius: 15, x: 0, y: 0)
            .onAppear {
                // Animate glow effect
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowOpacity = 0.4
                }
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Supporting Views

/// A retrowave-styled text field
public struct RetroTextField: View {
    @Binding var text: String?
    let configuration: ((UITextField) -> Void)?
    
    public var body: some View {
        ZStack {
            // Text field background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.retroBlack.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
            
            // Use UITextField wrapper for advanced configuration
            UIKitTextField(text: $text, configuration: configuration)
                .padding(.horizontal, 10)
                .frame(height: 40)
        }
        .frame(height: 40)
    }
}

/// UITextField wrapper for SwiftUI
struct UIKitTextField: UIViewRepresentable {
    @Binding var text: String?
    let configuration: ((UITextField) -> Void)?
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.textColor = .white
        textField.backgroundColor = .clear
        textField.tintColor = UIColor(Color.retroBlue)
        textField.returnKeyType = .done
        textField.autocorrectionType = .no
        
        // Apply custom configuration if provided
        configuration?(textField)
        
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: UIKitTextField
        
        init(_ parent: UIKitTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

/// A grid pattern view for retrowave aesthetic
private struct RetroAlertGridPattern: View {
    public var body: some View {
        ZStack {
            // Horizontal lines
            VStack(spacing: 15) {
                ForEach(0..<10) { _ in
                    Color.retroBlue.opacity(0.2)
                        .frame(height: 1)
                }
            }
            
            // Vertical lines
            HStack(spacing: 15) {
                ForEach(0..<10) { _ in
                    Color.retroBlue.opacity(0.2)
                        .frame(width: 1)
                }
            }
        }
    }
}

// MARK: - Button Styles

/// A retrowave-styled button
public struct RetroButton: View {
    let title: String
    let action: () -> Void
    let isPrimary: Bool
    
    public init(title: String, isPrimary: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isPrimary = isPrimary
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(
                    isPrimary ? 
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            gradient: Gradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.5)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: isPrimary ? Color.retroPink.opacity(0.5) : Color.clear, radius: 5, x: 0, y: 0)
        }
    }
}

// MARK: - View Modifier

/// A view modifier to present a RetroAlertView
public struct RetroAlertModifier<AlertContent: View>: ViewModifier {
    let title: String
    let message: String
    @Binding var isPresented: Bool
    let textFieldBinding: Binding<String?>?
    let textFieldConfiguration: ((UITextField) -> Void)?
    let alertContent: () -> AlertContent
    
    public init(
        title: String,
        message: String,
        isPresented: Binding<Bool>,
        textFieldBinding: Binding<String?>? = nil,
        textFieldConfiguration: ((UITextField) -> Void)? = nil,
        @ViewBuilder alertContent: @escaping () -> AlertContent
    ) {
        self.title = title
        self.message = message
        self._isPresented = isPresented
        self.textFieldBinding = textFieldBinding
        self.textFieldConfiguration = textFieldConfiguration
        self.alertContent = alertContent
    }
    
    public func body(content: Content) -> some View {
        ZStack {
            content
            
            if isPresented {
                RetroAlertView(
                    title: title,
                    message: message,
                    isPresented: $isPresented,
                    textFieldBinding: textFieldBinding,
                    textFieldConfiguration: textFieldConfiguration,
                    content: alertContent
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isPresented)
            }
        }
    }
}

// MARK: - View Extension

public extension View {
    /// Presents a RetroAlertView when the binding is true
    /// - Parameters:
    ///   - title: The title of the alert
    ///   - message: The message of the alert
    ///   - isPresented: Binding to control presentation
    ///   - textFieldBinding: Optional binding for text field value
    ///   - textFieldConfiguration: Optional configuration for the text field
    ///   - content: Content builder for buttons
    /// - Returns: A view with the alert modifier applied
    func retroAlert<Content: View>(
        _ title: String,
        message: String,
        isPresented: Binding<Bool>,
        textFieldBinding: Binding<String?>? = nil,
        textFieldConfiguration: ((UITextField) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(
            RetroAlertModifier(
                title: title,
                message: message,
                isPresented: isPresented,
                textFieldBinding: textFieldBinding,
                textFieldConfiguration: textFieldConfiguration,
                alertContent: content
            )
        )
    }
}
