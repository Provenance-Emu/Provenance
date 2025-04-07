import SwiftUI
import Combine
import PVLogging

/// A manager class that handles document picker presentation
/// This is used as an environment object to allow any view to trigger the document picker
public class DocumentPickerManager: ObservableObject {
    /// Whether the document picker is currently being shown
    @Published public var isShowingDocumentPicker = false
    
    /// The callback to be executed when files are imported
    @Published public var importCallback: (([URL]) -> Void)?
    
    /// Flag to prevent state updates during view redraws
    private var isProcessingImport = false
    
    /// Timer to delay state updates to avoid SwiftUI view update conflicts
    private var stateResetTimer: Timer?
    
    /// Shared instance for app-wide use
    public static let shared = DocumentPickerManager()
    
    private init() {
        // Add a subscriber to reset the processing flag when the picker is dismissed
        // This helps prevent state conflicts
        $isShowingDocumentPicker
            .dropFirst() // Skip the initial value
            .sink { [weak self] isShowing in
                if !isShowing {
                    // Delay the reset of the processing flag to ensure the view hierarchy has settled
                    // This prevents premature dismissal during view redraws
                    self?.stateResetTimer?.invalidate()
                    self?.stateResetTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                        DispatchQueue.main.async {
                            self?.isProcessingImport = false
                            VLOG("DocumentPickerManager: Reset processing flag after picker dismissal")
                        }
                    }
                } else {
                    VLOG("DocumentPickerManager: Document picker is now showing")
                }
            }
            .store(in: &cancellables)
    }
    
    /// Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Shows the document picker and sets up the import callback
    public func showDocumentPicker(onImport: @escaping ([URL]) -> Void) {
        // Prevent multiple activations during view redraws
        guard !isProcessingImport else {
            VLOG("DocumentPickerManager: Ignoring duplicate showDocumentPicker call, already processing")
            return
        }
        
        ILOG("DocumentPickerManager: Showing document picker")
        
        // Set the processing flag to prevent duplicate activations
        isProcessingImport = true
        
        // Store the callback
        self.importCallback = onImport
        
        // Use a slight delay to break the current render cycle
        // This helps prevent SwiftUI state conflicts that can cause premature dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            // Only set if still processing (to prevent race conditions)
            if self.isProcessingImport {
                self.isShowingDocumentPicker = true
                VLOG("DocumentPickerManager: Set isShowingDocumentPicker to true")
            }
        }
    }
    
    /// Called when document picker completes
    public func documentPickerCompleted(urls: [URL]?) {
        ILOG("DocumentPickerManager: Document picker completed with \(urls?.count ?? 0) URLs")
        
        // Execute the callback if we have URLs
        if let urls = urls, !urls.isEmpty, let callback = importCallback {
            // Use a slight delay to ensure the view hierarchy has settled
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                callback(urls)
            }
        } else if urls?.isEmpty ?? true {
            VLOG("DocumentPickerManager: Document picker was cancelled or returned no URLs")
        }
        
        // Reset the callback
        importCallback = nil
    }
    
    /// Manually reset state - can be called when needed to clear any stuck state
    public func resetState() {
        ILOG("DocumentPickerManager: Manually resetting state")
        isProcessingImport = false
        isShowingDocumentPicker = false
        importCallback = nil
        stateResetTimer?.invalidate()
        stateResetTimer = nil
    }
}
