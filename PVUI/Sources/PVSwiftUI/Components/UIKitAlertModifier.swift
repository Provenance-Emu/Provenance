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
             }
             UIAlertAction(title: "Cancel", style: .cancel)
         }
     }
 }
 */

public struct UIKitAlertModifier: ViewModifier {
    let title: String
    let message: String
    @Binding var isPresented: Bool
    let preferredContentSize = CGSize(width: 500, height: 300)

    let buttons: [UIAlertAction]
    
    func body(content: Content) -> some View {
        content.background(
            UIKitAlertWrapper(
                title: title,
                message: message,
                isPresented: $isPresented,
                buttons: buttons,
                preferredContentSize: preferredContentSize
            )
        )
    }
}

// UIKit Alert wrapper as UIViewController
struct UIKitAlertWrapper: UIViewControllerRepresentable {
    let title: String
    let message: String
    @Binding var isPresented: Bool
    let buttons: [UIAlertAction]
    let preferredContentSize = CGSize
    
    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented else { return }
        
//        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let alert = TVAlertController.init(title:title, message: message, preferredStyle: style)

        buttons.forEach { alert.addAction($0) }
        
        if uiViewController.presentedViewController == nil {
            uiViewController.present(alert, animated: true)
        }
    }
}

// SwiftUI View extension for easier usage
extension View {
    func uiKitAlert(
        _ title: String,
        message: String,
        isPresented: Binding<Bool>,
        @UIKitAlertActionBuilder buttons: () -> [UIAlertAction]
    ) -> some View {
        modifier(UIKitAlertModifier(
            title: title,
            message: message,
            isPresented: isPresented,
            buttons: buttons()
        ))
    }
}

// Result builder for cleaner button syntax
@resultBuilder
struct UIKitAlertActionBuilder {
    static func buildBlock(_ components: UIAlertAction...) -> [UIAlertAction] {
        components
    }
}
