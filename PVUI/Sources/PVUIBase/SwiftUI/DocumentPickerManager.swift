import SwiftUI
import Combine

/// A manager class that handles document picker presentation
/// This is used as an environment object to allow any view to trigger the document picker
public class DocumentPickerManager: ObservableObject {
    /// Whether the document picker is currently being shown
    @Published public var isShowingDocumentPicker = false
    
    /// The callback to be executed when files are imported
    @Published public var importCallback: (([URL]) -> Void)?
    
    /// Shared instance for app-wide use
    public static let shared = DocumentPickerManager()
    
    private init() {}
    
    /// Shows the document picker and sets up the import callback
    public func showDocumentPicker(onImport: @escaping ([URL]) -> Void) {
        self.importCallback = onImport
        self.isShowingDocumentPicker = true
    }
}
