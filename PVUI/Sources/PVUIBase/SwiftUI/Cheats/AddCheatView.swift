import SwiftUI
import PVPrimitives

public struct AddCheatView<Driver: CheatDriver>: View {
    @Environment(\.dismiss) private var dismiss
    let driver: Driver
    let onSave: (Driver.Entry) -> Void

    @State private var title = ""
    @State private var code = ""
    @State private var selectedType: CheatCodeTypes?

    private var detectedTypes: [CheatCodeTypes] {
        CheatCodeTypes.detectType(from: code).filter { driver.supportedCheatTypes.contains($0) }
    }

    private var isValidCode: Bool {
        !detectedTypes.isEmpty
    }

    private var canSave: Bool {
        !title.isEmpty && isValidCode
    }

    // iOS 17 and newer
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    var newCodeField: some View {
        SwiftUI.TextField("Code", text: $code)
            .textInputAutocapitalization(.characters)
            .onChange(of: code) { _, newValue in
                if let firstType = detectedTypes.first {
                    selectedType = firstType
                }
            }
    }

    // iOS 16 and older
    @available(iOS, deprecated: 17)
    var oldCodeField: some View {
        SwiftUI.TextField("Code", text: $code)
            .textInputAutocapitalization(.characters)
            .onChange(of: code) { newValue in
                if let firstType = detectedTypes.first {
                    selectedType = firstType
                }
            }
    }
    
    public var body: some View {

        SwiftUI.Form {
            SwiftUI.Section {
                TextField("Title", text: $title)
                Text(driver.gameTitle)
                    .foregroundStyle(.secondary)
            }

            SwiftUI.Section {
                if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
                    newCodeField
                } else {
                    oldCodeField
                }

                if !code.isEmpty {
                    if isValidCode {
                        Text("Valid \(selectedType?.stringValue ?? "") format")
                            .foregroundStyle(.green)
                    } else {
                        Text("Invalid code format")
                            .foregroundStyle(.red)
                    }
                }
            } header: {
                Text("Cheat Code")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if let type = selectedType {
                        Text("\(type.stringValue) format:")
                            .foregroundStyle(.secondary)
                        Text(type.formatDescription)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Supported formats:")
                            .foregroundStyle(.secondary)
                        ForEach(driver.supportedCheatTypes, id: \.self) { type in
                            Text("\(type.stringValue): \(type.formatDescription)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Cheat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let type = selectedType else { return }

                    onSave(Driver.Entry(
                        id: UUID().uuidString,
                        code: code,
                        type: type,
                        title: title,
                        enabled: false
                    ))
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddCheatView<MockCheatDriver>(
            driver: MockCheatDriver.shared(),
            onSave: { _ in }
        )
    }
}
