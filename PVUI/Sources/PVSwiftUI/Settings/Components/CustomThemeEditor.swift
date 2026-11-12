#if os(iOS)
import ImageIO
import PhotosUI
import PVSettings
import PVThemes
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct CustomThemeEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CustomTheme
    @State private var preview: Preview = .library
    @State private var image: PhotosPickerItem?
    @State private var suggestions: [ThemeColor] = []
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var errorMessage: String?

    var onSave: (CustomTheme) -> Void

    init(theme: CustomTheme, onSave: @escaping (CustomTheme) -> Void) {
        _draft = State(initialValue: theme)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Live Preview") {
                Picker("Preview", selection: $preview) {
                    Text("Library").tag(Preview.library)
                    Text("Settings").tag(Preview.settings)
                }
                .pickerStyle(.segmented)
                themePreview
            }

            Section("Palette") {
                TextField("Theme Name", text: $draft.name)
                Toggle("Dark Appearance", isOn: $draft.dark)
                ForEach(ColorRole.allCases) { role in
                    VStack(alignment: .leading, spacing: 4) {
                        ColorPicker(role.title, selection: colorBinding(role), supportsOpacity: false)
                        if let contrast = minimumContrast(for: role), contrast < 4.5 {
                            Label {
                                Text("Contrast \(contrast.formatted(.number.precision(.fractionLength(1)))):1. Aim for 4.5:1.")
                            } icon: {
                                Image(systemName: "exclamationmark.circle")
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Colors from a Photo") {
                PhotosPicker(selection: $image, matching: .images) {
                    Label("Choose Photo", systemImage: "photo")
                }
                if !suggestions.isEmpty {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(suggestions, id: \.self) { swatch in
                                Menu {
                                    ForEach(ColorRole.allCases) { role in
                                        Button(role.title) { draft[keyPath: role.field] = swatch }
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(swatch.platformColor))
                                            .frame(height: 30)
                                            .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.2)) }
                                        Text(swatch.hex)
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.primary)
                                    }
                                    .frame(minWidth: 64, minHeight: 44)
                                }
                                .accessibilityLabel("Assign \(swatch.hex)")
                            }
                        }
                    }
                }
            }

            Section("Theme File") {
                Button("Import JSON", systemImage: "square.and.arrow.down") { isImporting = true }
                Button("Export JSON", systemImage: "square.and.arrow.up") { isExporting = true }
                    .disabled(!draft.hasValidName)
            }
        }
        .navigationTitle("Custom Theme")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save & Apply") {
                    draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(draft)
                    dismiss()
                }
                .disabled(!draft.hasValidName)
            }
        }
        .task(id: image) { await loadSuggestions(from: image) }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json], onCompletion: importTheme)
        .fileExporter(isPresented: $isExporting, document: ThemeDocument(theme: draft), contentType: .json, defaultFilename: "Provenance Theme") { result in
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
        .alert("Theme Editor", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private enum Preview: Hashable {
        case library, settings
    }

    private func minimumContrast(for role: ColorRole) -> Double? {
        guard role == .text || role == .accent else { return nil }
        let foreground = draft[keyPath: role.field]
        return min(foreground.contrastRatio(with: draft.background), foreground.contrastRatio(with: draft.surface))
    }

    private var themePreview: some View {
        let palette = EditableThemePalette(theme: draft)
        let text = Color(palette.gameLibraryText)
        let accent = Color(palette.defaultTintColor)
        let surface = Color(palette.gameLibraryHeaderBackground)
        return VStack(alignment: .leading, spacing: 12) {
            switch preview {
            case .library:
                Text("Recently Played")
                    .font(.headline)
                    .foregroundStyle(accent)
                Label("Game Library", systemImage: "gamecontroller")
                    .foregroundStyle(text)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(surface, in: RoundedRectangle(cornerRadius: 8))
            case .settings:
                Text("Appearance")
                    .font(.headline)
                    .foregroundStyle(accent)
                Toggle("Show Artwork", isOn: .constant(true))
                    .foregroundStyle(text)
                    .tint(accent)
                    .padding(10)
                    .background(surface, in: RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(palette.gameLibraryBackground), in: RoundedRectangle(cornerRadius: 12))
        .environment(\.colorScheme, draft.dark ? .dark : .light)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of the current palette")
    }

    private func colorBinding(_ role: ColorRole) -> Binding<Color> {
        Binding {
            Color(draft[keyPath: role.field].platformColor)
        } set: { value in
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            guard UIColor(value).getRed(&red, green: &green, blue: &blue, alpha: nil) else { return }
            func byte(_ component: CGFloat) -> UInt32 { UInt32((min(max(component, 0), 1) * 255).rounded()) }
            draft[keyPath: role.field] = ThemeColor(rgb: (byte(red) << 16) | (byte(green) << 8) | byte(blue))
        }
    }

    private func loadSuggestions(from item: PhotosPickerItem?) async {
        suggestions = []
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw ThemeEditorError.unreadableImage }
            let colors = await Task.detached(priority: .userInitiated) { ThemeImagePalette.colors(from: data) }.value
            guard !Task.isCancelled else { return }
            guard !colors.isEmpty else { throw ThemeEditorError.unreadableImage }
            suggestions = colors
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    private func importTheme(_ result: Result<URL, any Error>) {
        do {
            let url = try result.get()
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            let data = try file.read(upToCount: ThemeDocument.maximumSize + 1) ?? Data()
            draft = try ThemeDocument.decode(data)
            image = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private enum ColorRole: String, CaseIterable, Identifiable {
        case background, surface, text, accent

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .background: "Background"
            case .surface: "Cards and Panels"
            case .text: "Text"
            case .accent: "Accent"
            }
        }

        var field: WritableKeyPath<CustomTheme, ThemeColor> {
            switch self {
            case .background: \.background
            case .surface: \.surface
            case .text: \.text
            case .accent: \.accent
            }
        }
    }
}

private enum ThemeEditorError: LocalizedError {
    case unreadableImage, oversizedFile, unsupportedVersion, invalidName

    var errorDescription: String? {
        switch self {
        case .unreadableImage: String(localized: "Couldn't find colors in this photo.")
        case .oversizedFile: String(localized: "Theme files must be 64 KB or smaller.")
        case .unsupportedVersion: String(localized: "This theme file uses an unsupported version.")
        case .invalidName: String(localized: "A theme name must be between 1 and 60 characters.")
        }
    }
}

private struct ThemeDocument: FileDocument {
    private struct Contents: Codable {
        let version: Int
        let theme: CustomTheme
    }

    static let readableContentTypes: [UTType] = [.json]
    static let maximumSize = 65_536
    let theme: CustomTheme

    init(theme: CustomTheme) {
        self.theme = theme
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        theme = try Self.decode(data)
    }

    static func decode(_ data: Data) throws -> CustomTheme {
        guard data.count <= maximumSize else { throw ThemeEditorError.oversizedFile }
        let contents = try JSONDecoder().decode(Contents.self, from: data)
        guard contents.version == 1 else { throw ThemeEditorError.unsupportedVersion }
        guard contents.theme.hasValidName else { throw ThemeEditorError.invalidName }
        return contents.theme
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try FileWrapper(regularFileWithContents: encoder.encode(Contents(version: 1, theme: theme)))
    }
}

private enum ThemeImagePalette {
    /// Samples a small sRGB thumbnail and ranks colors by the frequency of nearby pixels.
    nonisolated static func colors(from data: Data) -> [ThemeColor] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 64,
                  kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return [] }

        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        return pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4, space: colorSpace,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return [] }
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
            var histogram: [UInt32: (count: Int, sample: UInt32)] = [:]
            for index in stride(from: 0, to: buffer.count, by: 4) where buffer[index + 3] == 255 {
                let rgb = (UInt32(buffer[index]) << 16) | (UInt32(buffer[index + 1]) << 8) | UInt32(buffer[index + 2])
                let bucket = rgb & 0xE0E0E0
                histogram[bucket, default: (0, rgb)].count += 1
            }
            return histogram.sorted {
                $0.value.count == $1.value.count ? $0.key < $1.key : $0.value.count > $1.value.count
            }.prefix(6).map { ThemeColor(rgb: $0.value.sample) }
        }
    }
}
#endif
