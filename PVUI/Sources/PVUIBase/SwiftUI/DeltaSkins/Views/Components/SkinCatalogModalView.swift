import SwiftUI

/// A modal wrapper for `SkinCatalogBrowserView` that provides a leading Done button.
public struct SkinCatalogModalView: View {
    private let preselectedSystem: String?

    @Environment(\.dismiss) private var dismiss

    /// Creates a modal catalog browser, optionally pre-filtered to a system.
    /// - Parameter preselectedSystem: A catalog system code (see `SystemIdentifier.skinCatalogSystemCode`), or nil for all systems.
    public init(preselectedSystem: String? = nil) {
        self.preselectedSystem = preselectedSystem
    }

    public var body: some View {
        NavigationStack {
            SkinCatalogBrowserView(preselectedSystem: preselectedSystem)
            #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { dismiss() }
                            .foregroundColor(RetroTheme.retroPink)
                    }
                }
        }
    }
}

