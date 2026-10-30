import Foundation

public extension Bundle {
    func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: self, comment: "")
    }

    func localized(_ key: String, _ arguments: any CVarArg...) -> String {
        /// `arguments` is an array here, so the variadic `String(format:_:)` would
        /// substitute the array itself for the first placeholder ("(\n    Zelda\n)").
        /// `arguments:` spreads it, which is what every caller expects.
        String(format: NSLocalizedString(key, bundle: self, comment: ""), arguments: arguments)
    }
}
