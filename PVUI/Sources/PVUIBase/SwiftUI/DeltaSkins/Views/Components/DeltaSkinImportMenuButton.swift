import SwiftUI

/// A toolbar menu that groups skin import and catalog download actions.
///
/// Use this wherever a skin "import" button exists, so users can also jump
/// directly to the remote skin catalog from the same control.
public struct DeltaSkinImportMenuButton: View {
    private let importAction: (() -> Void)?
    private let catalogAction: () -> Void

    /// Creates a menu button for importing local skins and opening the catalog.
    /// - Parameters:
    ///   - importAction: Action to trigger the local import flow (nil to omit the item, e.g. on tvOS).
    ///   - catalogAction: Action to open the remote skin catalog.
    public init(importAction: (() -> Void)? = nil, catalogAction: @escaping () -> Void) {
        self.importAction = importAction
        self.catalogAction = catalogAction
    }

    public var body: some View {
        Menu {
            if let importAction {
                Button(action: importAction) {
                    Label("Import from Files…", systemImage: "folder")
                }
            }

            Button(action: catalogAction) {
                Label("Download Skins…", systemImage: "arrow.down.circle")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(RetroTheme.retroHorizontalGradient)
        }
        .accessibilityLabel("Add skins")
    }
}
