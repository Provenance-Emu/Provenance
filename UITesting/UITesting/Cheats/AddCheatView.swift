import SwiftUI
import PVPrimitives

struct AddCheatView<Driver: CheatDriver>: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Driver.Entry) -> Void

    @State private var title = ""
    @State private var code = ""
    @State private var selectedType: CheatCodeTypes?
    @State private var gameTitle = ""

    private var detectedTypes: [CheatCodeTypes] {
        CheatCodeTypes.detectType(from: code)
    }

    private var isValidCode: Bool {
        !detectedTypes.isEmpty
    }

    private var canSave: Bool {
        !title.isEmpty && isValidCode && !gameTitle.isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $title)
                TextField("Game Title", text: $gameTitle)
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
                if let type = selectedType {
                    Text(type.formatDescription)
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
                        enabled: false,
                        gameTitle: gameTitle
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
        AddCheatView<MockCheatDriver> { _ in }
    }
}
