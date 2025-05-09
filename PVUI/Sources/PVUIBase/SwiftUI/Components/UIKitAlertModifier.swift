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

    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }

    @MainActor
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Track if we've already presented an alert to avoid duplicate presentations
        let alertAlreadyPresented = uiViewController.presentedViewController is TVAlertController
        
        // Store a reference to the presented alert controller for state tracking
        let presentedAlert = alertAlreadyPresented ? uiViewController.presentedViewController as? TVAlertController : nil
        
        // Only handle presentation state changes
        if isPresented && !alertAlreadyPresented {
            DLOG("UIKitAlertModifier: Presenting alert with title: \(title ?? "nil")")
            
            // Create and present the alert
            let alert = TVAlertController(title: title, message: message, preferredStyle: .alert)
            
            // Add text field if needed
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
            
            // Add buttons
            buttons.forEach { alert.addAction($0) }
            
            // Set a completion handler to update the binding
            // This should only be called when the alert is actually dismissed by user interaction
            // or programmatically, not during view updates
            alert.didDismiss = { [isPresented] in
                DLOG("UIKitAlertModifier: Alert dismissed, updating isPresented state")
                DispatchQueue.main.async {
                    // Capture binding directly since we can't use weak self on a struct
                    self.isPresented = false
                }
            }
            
            // Present the alert - use a slight delay to avoid conflicts with SwiftUI view updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if uiViewController.presentedViewController == nil {
                    uiViewController.present(alert, animated: true)
                }
            }
        } else if !isPresented && alertAlreadyPresented {
            // Only dismiss if our alert is being presented and isPresented is false
            // and the alert was previously presented by user interaction
            DLOG("UIKitAlertModifier: Entered dismissal check. isPresented: \(isPresented), alertAlreadyPresented: \(alertAlreadyPresented), presentedAlert: \(String(describing: presentedAlert)), presentedAlert.presentingViewController: \(String(describing: presentedAlert?.presentingViewController))")
            if let presentedAlert = presentedAlert, presentedAlert.presentingViewController != nil {
                DLOG("UIKitAlertModifier: Dismissing alert programmatically. Call stack:\n\(Thread.callStackSymbols.joined(separator: "\n"))")
                uiViewController.dismiss(animated: true)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(textValue: $textValue)
    }

    class Coordinator: NSObject {
        @Binding var textValue: String?

        init(textValue: Binding<String?>) {
            self._textValue = textValue
        }

        @objc func textFieldDidChange(_ textField: UITextField) {
            self.textValue = textField.text
        }
    }
}

// Make the extension public
public extension View {
    func uiKitAlert(
        _ title: String,
        message: String,
        isPresented: Binding<Bool>,
        textValue: Binding<String?>? = nil,
        preferredContentSize: CGSize = CGSize(width: 500, height: 300),
        textField: ((UITextField) -> Void)? = nil,
        @UIKitAlertActionBuilder buttons: () -> [UIAlertAction]
    ) -> some View {
        modifier(UIKitAlertModifier(
            title: title,
            message: message,
            isPresented: isPresented,
            textValue: textValue,
            preferredContentSize: preferredContentSize,
            textField: textField,
            buttons: buttons()
        ))
    }
}
