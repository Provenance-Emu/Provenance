import SwiftUI
import UniformTypeIdentifiers

#if !os(tvOS)
/// A button that presents a document picker when tapped
/// This component isolates the document picker presentation from the parent view's lifecycle
public struct DocumentPickerButton<Label: View>: View {
    private let label: Label
    private let onImport: ([URL]) -> Void
    @State private var isShowingPicker = false
    
    public init(onImport: @escaping ([URL]) -> Void, @ViewBuilder label: () -> Label) {
        self.onImport = onImport
        self.label = label()
    }
    
    public var body: some View {
        Button(action: {
            // Use DispatchQueue to delay the presentation slightly
            // This helps prevent conflicts with other view updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isShowingPicker = true
            }
        }) {
            label
        }
        .background(
            DocumentPickerRepresentable(isPresented: $isShowingPicker, onImport: onImport)
        )
    }
}

/// A UIViewControllerRepresentable wrapper for UIDocumentPickerViewController
/// This is used as a background element to present the picker
private struct DocumentPickerRepresentable: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImport: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented && uiViewController.presentedViewController == nil {
            let supportedTypes: [UTType] = [
                .item,      // Generic item
                .content,   // Generic content
                .data,      // Generic data
                .archive,   // Archives (zip, 7z, etc.)
            ]
            
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
            picker.allowsMultipleSelection = true
            picker.delegate = context.coordinator
            
            // Present the picker
            uiViewController.present(picker, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerRepresentable
        
        init(_ parent: DocumentPickerRepresentable) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onImport(urls)
            parent.isPresented = false
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}
#endif
