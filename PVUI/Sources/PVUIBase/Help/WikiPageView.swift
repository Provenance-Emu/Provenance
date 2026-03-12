import SwiftUI
import PVHelp
import MarkdownView

public struct WikiPageView: View {
    let path: String
    let title: String

    @StateObject private var viewModel = WikiHelpViewModel()

    public init(path: String, title: String) {
        self.path = path
        self.title = title
    }

    public var body: some View {
        Group {
            if viewModel.isLoadingPage {
                loadingView
            } else if let page = viewModel.currentPage {
                pageContent(page)
            } else {
                loadingView
            }
        }
        .navigationTitle(title)
        #if !os(tvOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                viewOnWebButton
            }
        }
        #endif
        .task {
            await viewModel.loadPage(path: path, title: title)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading page...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func pageContent(_ page: WikiPage) -> some View {
        #if os(tvOS)
        ScrollView {
            Button(action: {}) {
                MarkdownView(text: page.content, baseURL: WikiConstants.baseURL)
                    .font(.custom("Menlo", size: 14), for: .body)
                    .font(.custom("Menlo", size: 24), for: .h1)
                    .font(.custom("Menlo", size: 20), for: .h2)
                    .font(.custom("Menlo", size: 16), for: .h3)
                    .font(.custom("Menlo", size: 14), for: .codeBlock)
                    .padding()
            }
            .buttonStyle(.card)
        }
        #else
        WikiContentView(page: page)
        #endif
    }

    #if !os(tvOS)
    @State private var showSafari = false

    private var viewOnWebButton: some View {
        Group {
            #if canImport(SafariServices)
            Button {
                showSafari = true
            } label: {
                Label("View on Web", systemImage: "safari")
            }
            .sheet(isPresented: $showSafari) {
                SafariWebView(url: WikiConstants.webURL(for: path))
            }
            #else
            Link(destination: WikiConstants.webURL(for: path)) {
                Label("View on Web", systemImage: "safari")
            }
            #endif
        }
    }
    #endif
}

// MARK: - WikiContentView (iOS/macOS with link interception)

#if !os(tvOS)
/// A view that renders wiki markdown content and intercepts link taps.
/// - External links (http/https) open in an in-app Safari sheet.
/// - Internal wiki links (`.md` paths relative to the wiki base URL) push a new WikiPageView.
private struct WikiContentView: View {
    let page: WikiPage

    @State private var externalURL: URL?
    @State private var internalDestination: WikiLinkDestination?
    @State private var showExternalLink = false

    var body: some View {
        ScrollView {
            MarkdownView(text: page.content, baseURL: WikiConstants.baseURL)
                .padding()
        }
        // Intercept link taps via the openURL environment action
        .environment(\.openURL, OpenURLAction { url in
            handleLink(url) ? .handled : .systemAction
        })
        // External link sheet
        #if canImport(SafariServices)
        .sheet(isPresented: $showExternalLink) {
            if let url = externalURL {
                SafariWebView(url: url)
            }
        }
        #endif
        // Internal wiki navigation link (hidden, activated programmatically)
        .background(
            NavigationLink(
                isActive: Binding(
                    get: { internalDestination != nil },
                    set: { if !$0 { internalDestination = nil } }
                ),
                destination: {
                    if let dest = internalDestination {
                        WikiPageView(path: dest.path, title: dest.title)
                    }
                }
            ) {
                EmptyView()
            }
        )
    }

    /// Returns `true` when the link was handled internally, `false` to let the system handle it.
    @discardableResult
    private func handleLink(_ url: URL) -> Bool {
        let baseURLString = WikiConstants.baseURL.absoluteString

        // Strip fragment and query so paths like "Page.md#section" still match
        var cleanComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        cleanComponents?.fragment = nil
        cleanComponents?.query = nil
        let cleanURLString = cleanComponents?.url?.absoluteString ?? url.absoluteString

        // Detect internal wiki links — URLs that resolve against the base raw GitHub URL
        if cleanURLString.hasPrefix(baseURLString) {
            let relativePath = String(cleanURLString.dropFirst(baseURLString.count))
            if relativePath.hasSuffix(".md") {
                let titleFromPath = relativePath
                    .components(separatedBy: "/").last?
                    .replacingOccurrences(of: ".md", with: "")
                    .replacingOccurrences(of: "-", with: " ")
                    .capitalized ?? relativePath
                internalDestination = WikiLinkDestination(path: relativePath, title: titleFromPath)
                return true
            }
        }

        // External http/https links open in Safari
        if url.scheme == "http" || url.scheme == "https" {
            externalURL = url
            showExternalLink = true
            return true
        }

        // Unhandled schemes (mailto:, tel:, #anchor, etc.) fall through to system
        return false
    }
}

private struct WikiLinkDestination: Identifiable {
    let id = UUID()
    let path: String
    let title: String
}
#endif
