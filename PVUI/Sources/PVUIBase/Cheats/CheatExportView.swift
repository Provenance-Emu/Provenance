/// Sheet for exporting a cheat code as a QR code, clipboard text, or share sheet.
///
/// This view is presented modally when the user long-presses or taps an export
/// button on a cheat row. It shows:
///  1. A large, scannable QR code image
///  2. The raw cheat code string
///  3. A **Copy** button (copies `format: code` to the clipboard)
///  4. A **Share** button (`ShareLink` targeting the QR image + raw text)
///
/// The cheat library premium IAP is checked via `DriverStoreManager` when
/// the view is embedded in the companion app. Within the main Provenance app
/// the view can be shown without a paywall (the lookup database is already there).

#if os(iOS)
import SwiftUI
import PVLibrary

// MARK: - CheatExportView

/// A sheet that displays a cheat code's QR code and sharing options.
public struct CheatExportView: View {

    // MARK: - Init

    public let entry: SharedCheatEntry

    public init(entry: SharedCheatEntry) {
        self.entry = entry
    }

    // MARK: - State

    @Environment(\.dismiss) private var dismiss
    @State private var isCopied = false
    @State private var qrImage: UIImage?

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    qrSection
                    metadataSection
                    actionSection
                }
                .padding()
            }
            .navigationTitle("Export Cheat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(
                        item: entry.code,
                        subject: Text(entry.name),
                        message: Text("[\(entry.format)] \(entry.code) — \(entry.gameName) on \(entry.systemName)")
                    )
                }
            }
        }
        .task { generateQR() }
    }

    // MARK: - Subviews

    private var qrSection: some View {
        Group {
            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 280)
                    .padding()
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                    .frame(width: 280, height: 280)
                    .overlay {
                        ProgressView()
                    }
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledRow(label: "Game",   value: entry.gameName)
            labeledRow(label: "System", value: entry.systemName)
            labeledRow(label: "Format", value: entry.format)
            Divider()
            Text(entry.code)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .textSelection(.enabled)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            Button {
                copyToClipboard()
            } label: {
                Label(isCopied ? "Copied!" : "Copy Code", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(isCopied ? .green : .accentColor)
            .animation(.easeInOut(duration: 0.2), value: isCopied)

            if let qrImage {
                ShareLink(
                    item: Image(uiImage: qrImage),
                    preview: SharePreview("\(entry.name) QR", image: Image(uiImage: qrImage))
                ) {
                    Label("Share QR Code", systemImage: "qrcode")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func labeledRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.subheadline)
        }
    }

    // MARK: - Actions

    private func copyToClipboard() {
        UIPasteboard.general.string = "[\(entry.format)] \(entry.code)"
        isCopied = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            isCopied = false
        }
    }

    private func generateQR() {
        let urlString = entry.qrURLString
        Task.detached(priority: .userInitiated) {
            let image = CheatQRCodeGenerator.qrCode(for: urlString)
            await MainActor.run { self.qrImage = image }
        }
    }
}

// MARK: - Preview

#Preview {
    CheatExportView(entry: SharedCheatEntry(
        name: "Infinite Lives",
        code: "9999-5EC0",
        format: "Game Genie",
        systemName: "Super Nintendo",
        gameName: "Super Mario World"
    ))
}

#endif // os(iOS)
