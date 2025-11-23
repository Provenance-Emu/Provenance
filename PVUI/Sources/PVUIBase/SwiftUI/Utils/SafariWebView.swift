/// A wrapper for the Safari WebView in SwiftUI

#if canImport(SafariServices)
import SafariServices
import SwiftUI

/// Safari WebView wrapper for presenting SFSafariViewController in SwiftUI
public struct SafariWebView: UIViewControllerRepresentable {
    let url: URL
    let entersReaderIfAvailable: Bool
    
    public init(url: URL, entersReaderIfAvailable: Bool = false) {
        self.url = url
        self.entersReaderIfAvailable = entersReaderIfAvailable
    }
    
    public func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.barCollapsingEnabled = true
        config.entersReaderIfAvailable = entersReaderIfAvailable
        return SFSafariViewController(url: url, configuration: config)
    }
    
    public func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
#endif
