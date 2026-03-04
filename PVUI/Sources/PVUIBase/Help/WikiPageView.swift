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
        ScrollView {
            MarkdownView(text: page.content, baseURL: WikiConstants.baseURL)
                .padding()
        }
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
