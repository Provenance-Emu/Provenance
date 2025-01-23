import SwiftUI
import UniformTypeIdentifiers
import PVPrimitives

struct ImportCheatView<Driver: CheatDriver>: View {
    @Environment(\.dismiss) private var dismiss
    let driver: Driver
    let onImport: ([Driver.Entry]) -> Void

    @State private var showingFilePicker = false
    @State private var importedCheats: [Driver.Entry] = []
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Text(driver.gameTitle)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    showingFilePicker = true
                } label: {
                    Label("Select .cht file", systemImage: "doc")
                }
            }

            if !importedCheats.isEmpty {
                Section("Found Cheats") {
                    ForEach(importedCheats) { cheat in
                        VStack(alignment: .leading) {
                            Text(cheat.title)
                                .font(.headline)
                            Text(cheat.code)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Import Cheats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Import") {
                    onImport(importedCheats)
                    dismiss()
                }
                .disabled(importedCheats.isEmpty)
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.chtFile],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }

                do {
                    let data = try String(contentsOf: url)
                    importedCheats = try CheatFileParser<Driver>.parse(data)
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                    importedCheats = []
                }

            case .failure(let error):
                errorMessage = error.localizedDescription
                importedCheats = []
            }
        }
    }
}

// MARK: - UTType Extension
extension UTType {
    static var chtFile: UTType {
        UTType(exportedAs: "com.provenance.cht")
    }
}

#Preview {
    NavigationStack {
        ImportCheatView<MockCheatDriver>(
            driver: MockCheatDriver.shared(),
            onImport: { _ in }
        )
    }
}
