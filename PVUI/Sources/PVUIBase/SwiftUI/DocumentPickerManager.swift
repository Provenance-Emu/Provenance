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
        // Reset any existing state first to ensure a clean start
        resetState()
        
        ILOG("DocumentPickerManager: Showing document picker with new callback")
        
        // Store the callback immediately
        self.importCallback = onImport
        
        // Set the processing flag to prevent duplicate activations
        isProcessingImport = true
        
        // Present the document picker with minimal delay
        // Using a shorter delay to reduce the chance of state conflicts
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Set the flag to show the document picker
            ILOG("DocumentPickerManager: Presenting document picker sheet")
            self.isShowingDocumentPicker = true
        }
    }
    
    /// Called when document picker completes
    public func documentPickerCompleted(urls: [URL]?) {
        ILOG("DocumentPickerManager: Document picker completed with \(urls?.count ?? 0) URLs")
        
        // Capture the current callback before resetting it
        let currentCallback = importCallback
        
        // Reset state immediately to avoid any potential conflicts
        // This is important - we need to reset the state before executing the callback
        // to prevent SwiftUI view update cycles from interfering
        isShowingDocumentPicker = false
        isProcessingImport = false
        importCallback = nil
        
        // Execute the callback if we have URLs
        if let urls = urls, !urls.isEmpty, let callback = currentCallback {
            ILOG("DocumentPickerManager: Executing callback with \(urls.count) URLs")
            
            // Execute immediately on the main thread to ensure it runs even if the view service terminates
            DispatchQueue.main.async {
                callback(urls)
            }
            
            // Also set up a backup execution with a delay in case the immediate execution is interrupted
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                ILOG("DocumentPickerManager: Backup execution of callback with \(urls.count) URLs")
                callback(urls)
            }
        } else if urls?.isEmpty ?? true {
            VLOG("DocumentPickerManager: Document picker was cancelled or returned no URLs")
        }
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
