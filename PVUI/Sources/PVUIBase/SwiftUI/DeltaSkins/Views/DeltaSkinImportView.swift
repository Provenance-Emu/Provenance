import SwiftUI
import UniformTypeIdentifiers

/// View for importing Delta skins
public struct DeltaSkinImportView: View {
    @StateObject private var skinManager = DeltaSkinManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingFilePicker = false
    @State private var isImporting = false
    @State private var importError: String?
    @State private var importSuccess = false
    @State private var validationResult: DeltaSkinValidationResult?

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header image
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                    .padding()

                Text("Import Controller Skin")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Import a .deltaskin/.manicskin file to use custom controller layouts for your games.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                // Import button
                Button(action: {
                    isShowingFilePicker = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Select .deltaskin/.manicskin File")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(isImporting)

                if isImporting {
                    ProgressView("Importing skin...")
                        .padding()
                }

                if let error = importError {
                    VStack {
                        Text("Import Failed")
                            .font(.headline)
                            .foregroundColor(.red)

                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                if importSuccess {
                    VStack {
                        Text("Import Successful")
                            .font(.headline)
                            .foregroundColor(.green)

                        Text("The skin has been imported and is now available for use.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Import Skin")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #if !os(tvOS)
            .fileImporter(
                isPresented: $isShowingFilePicker,
                allowedContentTypes: [UTType.deltaSkin, UTType.deltaAppSkin],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            #endif
            .sheet(item: $validationResult) { result in
                NavigationStack {
                    DeltaSkinValidationResultView(result: result)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Dismiss") {
                                    validationResult = nil
                                }
                            }
                        }
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        importError = nil
        importSuccess = false
        validationResult = nil

        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                importError = "No file was selected"
                return
            }

            isImporting = true

            Task {
                // Run ZIP-based validation off the main thread so large skins don't block UI
                let validation = await Task.detached(priority: .userInitiated) {
                    DeltaSkinValidator.validate(url: url)
                }.value

                if !validation.isValid {
                    isImporting = false
                    validationResult = validation
                    return
                }

                do {
                    try await skinManager.importSkin(from: url)
                    isImporting = false
                    importSuccess = true
                    importError = nil
                    // Show warnings (non-blocking) if any
                    if !validation.warnings.isEmpty {
                        validationResult = validation
                    }
                    await skinManager.reloadSkins()
                } catch {
                    isImporting = false
                    importError = error.localizedDescription
                }
            }

        case .failure(let error):
            importError = "Failed to access file: \(error.localizedDescription)"
        }
    }
}
