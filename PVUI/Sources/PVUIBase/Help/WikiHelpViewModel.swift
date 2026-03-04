import SwiftUI
import PVHelp
import PVLogging

@MainActor
public final class WikiHelpViewModel: ObservableObject {
    @Published public var navigationTree: WikiNavigationTree?
    @Published public var currentPage: WikiPage?
    @Published public var isLoadingTree = false
    @Published public var isLoadingPage = false
    @Published public var errorMessage: String?

    private let provider = WikiContentProvider()

    public init() {}

    public func loadNavigationTree() async {
        guard navigationTree == nil else { return }
        isLoadingTree = true
        errorMessage = nil

        let tree = await provider.loadNavigationTree()
        navigationTree = tree
        isLoadingTree = false

        if tree.sections.isEmpty {
            errorMessage = "Unable to load wiki navigation. Check your internet connection."
        }
    }

    public func loadPage(path: String, title: String) async {
        isLoadingPage = true
        errorMessage = nil

        let page = await provider.loadPage(path: path, title: title)
        currentPage = page
        isLoadingPage = false
    }

    public func clearCache() {
        provider.clearCache()
        navigationTree = nil
        currentPage = nil
    }
}
