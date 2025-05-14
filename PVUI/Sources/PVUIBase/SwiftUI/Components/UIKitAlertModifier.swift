//
//  UIKitAlertModifier.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import PVUIBase

/*
 Usage:
 struct ContentView: View {
     @State private var showAlert = false

     var body: some View {
         Button("Show Alert") {
             showAlert = true
         }
         .uiKitAlert(
             "Title",
             message: "Message",
             isPresented: $showAlert
             preferredContentSize: CGSize(width: 500, height: 300)
         ) {
             UIAlertAction(title: "OK", style: .default) { _ in
                 print("OK tapped")
                 showAlert = false
             }
             UIAlertAction(title: "Cancel", style: .cancel) { _ in
                print("Cancel tapped")
                 showAlert = false
            }
         }
     }
 }
 */

// Make the builder public
@resultBuilder
public struct UIKitAlertActionBuilder {
    public static func buildBlock(_ components: [UIAlertAction]...) -> [UIAlertAction] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ expression: UIAlertAction) -> [UIAlertAction] {
        [expression]
    }

    public static func buildExpression(_ expression: [UIAlertAction]) -> [UIAlertAction] {
        expression
    }

    public static func buildEither(first: [UIAlertAction]) -> [UIAlertAction] {
        first
    }

    public static func buildEither(second: [UIAlertAction]) -> [UIAlertAction] {
        second
    }

    public static func buildOptional(_ component: [UIAlertAction]?) -> [UIAlertAction] {
        component ?? []
    }

    public static func buildArray(_ components: [[UIAlertAction]]) -> [UIAlertAction] {
        components.flatMap { $0 }
    }
}

// Make the modifier public
public struct UIKitAlertModifier: ViewModifier {
    let title: String
    let message: String
    @Binding var isPresented: Bool
    @Binding var textValue: String?
    let preferredContentSize: CGSize
    let textField: ((UITextField) -> Void)?
    let buttons: [UIAlertAction]

    public init(
        title: String,
        message: String,
        isPresented: Binding<Bool>,
        textValue: Binding<String?>? = nil,
        preferredContentSize: CGSize,
        textField: ((UITextField) -> Void)? = nil,
        buttons: [UIAlertAction]
    ) {
        self.title = title
        self.message = message
        self._isPresented = isPresented
        self._textValue = textValue ?? .constant(nil)
        self.preferredContentSize = preferredContentSize
        self.textField = textField
        self.buttons = buttons
    }

    public func body(content: Content) -> some View {
        content.background(
            UIKitAlertWrapper(
                title: title,
                message: message,
                isPresented: $isPresented,
                textValue: $textValue,
                buttons: buttons,
                preferredContentSize: preferredContentSize,
                textField: textField
            )
        )
    }
}

// UIKit Alert wrapper as UIViewController
struct UIKitAlertWrapper: UIViewControllerRepresentable {
    // Use a class type to track presentation state
    class AlertState {
        var hasBeenPresented = false
    }
    let title: String
    let message: String
    @Binding var isPresented: Bool
    @Binding var textValue: String?
    let buttons: [UIAlertAction]
    let preferredContentSize : CGSize
    let textField: ((UITextField) -> Void)?

    // MARK: - Helper methods to find presenting ViewController
    private static func getKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first { $0.isKeyWindow }
    }

    private static func getTopMostViewController() -> UIViewController? {
        guard let keyWindow = getKeyWindow(), var topController = keyWindow.rootViewController else {
            DLOG("UIKitAlertModifier: Could not find key window or root view controller.")
            return nil
        }
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        return topController
    }

    func makeUIViewController(context: Context) -> UIViewController {
        // This UIViewController is just a placeholder for the modifier's lifecycle.
        // We won't present from it directly.
        return UIViewController()
    }

    @MainActor
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        let coordinator = context.coordinator

        if isPresented {
            if coordinator.presentedAlert == nil { // Only present if our coordinator isn't tracking an alert
                DLOG("UIKitAlertModifier: Presenting alert with title: \(title)")

                let alert = TVAlertController(title: title, message: message, preferredStyle: .alert)

                if let textFieldConfig = textField {
                    alert.addTextField { textField in
                        textField.text = self.textValue
                        textFieldConfig(textField)
                        textField.addTarget(
                            context.coordinator,
                            action: #selector(Coordinator.textFieldDidChange(_:)),
                            for: .editingChanged
                        )
                    }
                }

                buttons.forEach { alert.addAction($0) }

                // Use captured binding and weak coordinator for safety in the closure
                // Pass the binding directly to the closure
                alert.didDismiss = { [weak coordinator, weakSelf = self] in // Capture self weakly
                    DLOG("UIKitAlertModifier: Alert dismissed callback, updating isPresented state")
                    DispatchQueue.main.async {
                        self.isPresented = false // Modify self's isPresented property
                        coordinator?.presentedAlert = nil // Clear the tracked alert
                    }
                }

                // Present the alert from the top-most view controller
                // Dispatch async to avoid issues with view updates cycle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { // Reduced delay slightly
                    guard let presentingVC = Self.getTopMostViewController() else {
                        DLOG("UIKitAlertModifier: Could not find a suitable view controller to present alert from. Aborting presentation.")
                        // Important: If presentation fails, reset isPresented to false to avoid an inconsistent state.
                        DispatchQueue.main.async {
                            self.isPresented = false // Access self.isPresented directly
                        }
                        return
                    }

                    if presentingVC.presentedViewController == nil {
                        presentingVC.present(alert, animated: true) {
                            coordinator.presentedAlert = alert // Track after successful presentation
                        }
                    } else {
                        DLOG("UIKitAlertModifier: Topmost view controller is already presenting: \(String(describing: presentingVC.presentedViewController)). Not presenting our alert.")
                        // If another alert is already up, we might not present ours to avoid conflicts.
                        // Resetting isPresented to false indicates our alert couldn't be shown.
                        DispatchQueue.main.async {
                            self.isPresented = false // Access self.isPresented directly
                        }
                    }
                }
            }
            // If coordinator.presentedAlert is not nil, our alert is presumably already shown or being shown.
        } else { // isPresented is false
            if let alertToDismiss = coordinator.presentedAlert {
                if !alertToDismiss.isBeingDismissed {
                    DLOG("UIKitAlertModifier: isPresented is false. Dismissing alert programmatically.")
                    // The alert's own didDismiss closure (defined above) will handle setting
                    // capturedIsPresentedBinding = false and coordinator.presentedAlert = nil.
                    alertToDismiss.presentingViewController?.dismiss(animated: true, completion: nil)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(textValue: $textValue)
    }

    class Coordinator: NSObject {
        @Binding var textValue: String?
        weak var presentedAlert: TVAlertController? // Weak reference to the alert controller

        init(textValue: Binding<String?>) {
            self._textValue = textValue
        }

        @objc func textFieldDidChange(_ textField: UITextField) {
            self.textValue = textField.text
        }
    }
}

// Extension to make the modifier easier to use
public extension View {
    func uiKitAlert(
        _ title: String,
        message: String,
        isPresented: Binding<Bool>,
        textValue: Binding<String?>? = nil, // Make it optional to match init
        preferredContentSize: CGSize = CGSize(width: 300, height: 200), // Provide default
        textField: ((UITextField) -> Void)? = nil,
        @UIKitAlertActionBuilder buttons: () -> [UIAlertAction]
    ) -> some View {
        self.modifier(
            UIKitAlertModifier(
                title: title,
                message: message,
                isPresented: isPresented,
                textValue: textValue, // Pass it through
                preferredContentSize: preferredContentSize,
                textField: textField,
                buttons: buttons()
            )
        )
    }
}

#if DEBUG
struct UIKitAlertPreview: View {
    @State private var showAlert1 = false
    @State private var alert1Text: String? = "Initial Text"

    @State private var showAlert2 = false

    var body: some View {
        VStack(spacing: 20) {
            Button("Show Alert with TextField") {
                alert1Text = "Initial Text for Alert 1"
                showAlert1 = true
            }
            .uiKitAlert(
                "Text Field Alert",
                message: "Enter some text below.",
                isPresented: $showAlert1,
                textValue: $alert1Text,
                preferredContentSize: CGSize(width: 400, height: 250),
                textField: { textField in
                    textField.placeholder = "Enter text here"
                    textField.keyboardType = .default
                }
            ) {
                UIAlertAction(title: "Submit", style: .default) { _ in
                    print("Submitted: \(alert1Text ?? "nil")")
                }
                UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    print("Cancelled text field alert")
                }
            }
            Text("Text Field Value: \(alert1Text ?? "nil")")

            Button("Show Simple Alert") {
                showAlert2 = true
            }
            .uiKitAlert(
                "Simple Alert",
                message: "This is a simple alert without a text field.",
                isPresented: $showAlert2,
                preferredContentSize: CGSize(width: 300, height: 180)
            ) {
                UIAlertAction(title: "OK", style: .default) { _ in
                    print("OK tapped on simple alert")
                }
                UIAlertAction(title: "More", style: .default) { _ in
                    print("More tapped")
                }
                UIAlertAction(title: "Destroy", style: .destructive) { _ in
                    print("Destroy tapped")
                }
                UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    print("Cancel tapped on simple alert")
                }
            }
        }
        .padding()
    }
}

#Preview("UIKitAlertPreview") {
    UIKitAlertPreview()
}
#endif
