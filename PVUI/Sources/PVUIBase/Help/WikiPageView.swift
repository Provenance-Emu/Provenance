import SwiftUI
import PVHelp
import MarkdownView

public struct WikiPageView: View {
    let path: String
    let title: String
    /// Optional anchor fragment (e.g. `"my-section"`) to scroll to after the page loads.
    let fragment: String?

    @StateObject private var viewModel = WikiHelpViewModel()

    public init(path: String, title: String, fragment: String? = nil) {
        self.path = path
        self.title = title
        self.fragment = fragment
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
        WikiContentView(page: page, fragment: fragment)
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
/// - Anchor fragments in wiki links scroll to the matching heading section.
private struct WikiContentView: View {
    let page: WikiPage
    /// Optional anchor fragment (e.g. `"my-section"`) indicating which section to scroll to on appear.
    let fragment: String?

    @State private var externalURL: URL?
    @State private var internalDestination: WikiLinkDestination?
    @State private var showExternalLink = false

    var body: some View {
        let sections = splitMarkdownIntoSections(page.content)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sections) { section in
                        MarkdownView(text: section.content, baseURL: WikiConstants.baseURL)
                            .id(section.anchorID)
                    }
                }
                .padding()
            }
            .onAppear {
                guard let fragment else { return }
                // Delay slightly to allow SwiftUI layout to complete before scrolling
                DispatchQueue.main.asyncAfter(deadline: .now() + scrollToAnchorDelay) {
                    withAnimation {
                        proxy.scrollTo(fragment, anchor: .top)
                    }
                }
            }
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
                        WikiPageView(path: dest.path, title: dest.title, fragment: dest.fragment)
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

        // Parse URL components so we can extract the fragment before stripping it
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let urlFragment = components?.fragment
        components?.fragment = nil
        components?.query = nil
        let cleanURLString = components?.url?.absoluteString ?? url.absoluteString

        // Detect internal wiki links — URLs that resolve against the base raw GitHub URL
        if cleanURLString.hasPrefix(baseURLString) {
            let relativePath = String(cleanURLString.dropFirst(baseURLString.count))
            // Use pathExtension check (ignoring fragment/query) so "Page.md#section" still matches
            if URL(fileURLWithPath: relativePath).pathExtension == "md" {
                let titleFromPath = relativePath
                    .components(separatedBy: "/").last?
                    .replacingOccurrences(of: ".md", with: "")
                    .replacingOccurrences(of: "-", with: " ")
                    .capitalized ?? relativePath
                internalDestination = WikiLinkDestination(path: relativePath, title: titleFromPath, fragment: urlFragment)
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
    /// Optional anchor fragment to scroll to on the destination page (e.g. `"my-section"`).
    let fragment: String?
}

/// Delay (seconds) before programmatically scrolling to an anchor after a page loads.
/// A brief delay gives SwiftUI time to finish measuring and laying out the rendered sections.
private let scrollToAnchorDelay: TimeInterval = 0.4

// MARK: - Markdown Section Splitting for Anchor Navigation

/// A section of markdown content bounded by a heading, with a computed GitHub-style anchor ID.
private struct MarkdownSection: Identifiable {
    /// GitHub-style anchor ID derived from the heading text (e.g. `"my-section"`).
    let anchorID: String
    /// Markdown text for this section (includes the heading line and all following content until the next heading).
    let content: String
    var id: String { anchorID }
}

/// Splits markdown text into sections at each ATX heading (`#`, `##`, …, `######`).
/// Content before the first heading is placed in a preamble section with id `"__preamble__"`.
/// Duplicate heading anchors are disambiguated by appending `-1`, `-2`, … (GitHub convention).
private func splitMarkdownIntoSections(_ text: String) -> [MarkdownSection] {
    let lines = text.components(separatedBy: "\n")
    var sections: [MarkdownSection] = []
    var currentLines: [String] = []
    var currentAnchor = "__preamble__"
    var seenAnchors: [String: Int] = [:]

    for line in lines {
        if isATXHeading(line) {
            // Flush the current section.
            // `sections.isEmpty` ensures an empty preamble is always emitted before the first heading.
            if !currentLines.isEmpty || sections.isEmpty {
                sections.append(MarkdownSection(anchorID: currentAnchor, content: currentLines.joined(separator: "\n")))
                currentLines = []
            }
            let headingText = line
                .drop(while: { $0 == "#" })
                .drop(while: { $0 == " " })
            let baseAnchor = String(headingText).githubAnchorID
            let count = seenAnchors[baseAnchor, default: 0]
            currentAnchor = count == 0 ? baseAnchor : "\(baseAnchor)-\(count)"
            seenAnchors[baseAnchor] = count + 1
            currentLines = [line]
        } else {
            currentLines.append(line)
        }
    }

    if !currentLines.isEmpty {
        sections.append(MarkdownSection(anchorID: currentAnchor, content: currentLines.joined(separator: "\n")))
    }

    return sections.isEmpty ? [MarkdownSection(anchorID: "__preamble__", content: text)] : sections
}

/// Returns `true` if `line` is a valid ATX heading (1–6 `#` characters followed by a space or end-of-line).
private func isATXHeading(_ line: String) -> Bool {
    guard line.hasPrefix("#") else { return false }
    let hashes = line.prefix(while: { $0 == "#" })
    guard hashes.count >= 1, hashes.count <= 6 else { return false }
    let afterHashes = line.dropFirst(hashes.count)
    return afterHashes.isEmpty || afterHashes.hasPrefix(" ")
}

private extension String {
    /// Computes a GitHub-style anchor ID from a heading string.
    /// Converts to lowercase, keeps only letters, digits, spaces, and hyphens, then replaces spaces with hyphens.
    var githubAnchorID: String {
        var result = ""
        result.reserveCapacity(count)
        for scalar in lowercased().unicodeScalars {
            if scalar == " " {
                result.append("-")
            } else if CharacterSet.alphanumerics.contains(scalar) || scalar == "-" {
                result.append(Character(scalar))
            }
        }
        return result
    }
}
#endif
