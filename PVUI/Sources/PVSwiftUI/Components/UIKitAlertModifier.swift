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

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented else {
            // Ensure any presented controller is dismissed
            if uiViewController.presentedViewController != nil {
                uiViewController.dismiss(animated: true)
            }
            return
        }

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

        if uiViewController.presentedViewController == nil {
            uiViewController.present(alert, animated: true)
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
