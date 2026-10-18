import Foundation
import PVHelp

/// Provenance's wiki: where its pages live, the offline navigation copy, and the
/// page paths the app links to. The shared PVHelp package is app-neutral.
public enum ProvenanceWiki {
    public static let configuration = WikiConfiguration(
        baseURL: URL(string: "https://raw.githubusercontent.com/Provenance-EMU/wiki/master/")!,
        webBaseURL: URL(string: "https://wiki.provenance-emu.com/")!,
        bundledContent: .init(bundle: .module, subdirectory: "WikiContent")
    )

    public static func rawURL(for path: String) -> URL {
        configuration.rawURL(for: path)
    }

    public static func webURL(for path: String) -> URL {
        configuration.webURL(for: path)
    }

    /// Well-known wiki page paths. Use `rawURL(for:)` or `webURL(for:)` to turn them into URLs.
    public enum Paths {
        public static let saveStateVersionMismatch = "save-states/version-mismatch.md"
        public static let saveStates = "save-states/README.md"
        public static let skinsGuide = "info/skins-guide.md"
        public static let controllersGuide = "info/controllers-and-controls/README.md"
        public static let cheatsGuide = "info/cheats.md"
        public static let faq = "faqs.md"
        /// Canonical "what BIOS files do I need and where do they go" guide.
        /// Referenced by every surface that reports missing BIOS files.
        public static let biosRequirements = "installation-and-usage/bios-requirements.md"
    }
}
