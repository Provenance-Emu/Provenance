protocol ConfigEditorProtocol: ObservableObject {
    var configKeys: [String] { get }
    var configValues: [String: String] { get set }
    var configDescriptions: [String: String] { get }
    var hasChanges: Bool { get }

    func loadConfig() async
    func saveChanges() async
    func reloadConfig() async
}
