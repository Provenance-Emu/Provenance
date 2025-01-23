import SwiftUI
import PVPrimitives

struct AddCheatView<Driver: CheatDriver>: View {
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

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $title)
                Text(driver.gameTitle)
                    .foregroundStyle(.secondary)
            }

            Section {
                TextField("Code", text: $code)
                    .textInputAutocapitalization(.characters)
                    .onChange(of: code) { _, _ in
                        if let firstType = detectedTypes.first {
                            selectedType = firstType
                        }
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
