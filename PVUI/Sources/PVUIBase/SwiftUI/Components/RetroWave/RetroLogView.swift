//
//  RetroLogView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes
import PVLogging
#if !os(tvOS)
import UniformTypeIdentifiers
#endif

/// A retrowave-styled log viewer component
public struct RetroLogView: View {
    // MARK: - Properties

    /// View model for handling log data and logic
    @StateObject private var viewModel = RetroLogViewModel()

    /// Scroll view reader for auto-scrolling
    @Namespace private var scrollSpace

    /// Controls whether the view is presented in fullscreen mode
    @Binding private var isFullscreen: Bool

    /// Controls presentation of the export options sheet
    @State private var showingExportSheet = false

    #if !os(tvOS)
    /// Controls presentation of the log file importer
    @State private var showingImporter = false

    /// Message shown when importing a log file fails
    @State private var importErrorMessage: String?
    #endif

    #if os(tvOS)
    /// Focus states for header buttons
    @FocusState private var focusedButton: HeaderButton?

    private enum HeaderButton: Hashable {
        case logLevel
        case autoScroll
        case sortOrder
        case showDetails
        case clear
        case export
        case fullscreen
    }
    #endif

    // MARK: - Initialization

    public init(isFullscreen: Binding<Bool> = .constant(false)) {
        self._isFullscreen = isFullscreen
    }

    public init(viewModel: RetroLogViewModel, isFullscreen: Binding<Bool> = .constant(false)) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self._isFullscreen = isFullscreen
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            headerView

            // Banner shown while viewing a log imported from a file
            if let session = viewModel.importedSession {
                importedSessionBanner(name: session.name)
            }

            // Log list
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if viewModel.importedSession != nil {
                            ForEach(viewModel.displayedImportedLines) { line in
                                importedLineRow(line)
                                    .id(line.id)
                            }
                        } else {
                            ForEach(viewModel.displayedLogs) { log in
                                logEntryRow(log)
                                    .id(log.id)
                            }
                        }

                        // Invisible view at the bottom for auto-scrolling
                        Color.clear
                            .frame(height: 1)
                            .id(scrollSpace)
                    }
                    .padding(.horizontal, 8)
                }
                #if os(tvOS)
                .focusSection()
                #endif
                .onChange(of: viewModel.displayedLogs.count) { _, _ in handleAutoScroll(scrollView: scrollView) }
                .onChange(of: viewModel.autoScroll) { _, _ in handleAutoScroll(scrollView: scrollView) }
                .onChange(of: viewModel.sortOrder) { _, _ in handleAutoScroll(scrollView: scrollView) }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroBlue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .frame(maxWidth: isFullscreen ? .infinity : nil, maxHeight: isFullscreen ? .infinity : nil)
        #if os(tvOS)
        .onAppear {
            // Set initial focus to first button if none is focused
            if focusedButton == nil {
                focusedButton = .autoScroll
            }
        }
        #endif
        .sheet(isPresented: $showingExportSheet) {
            LogExportSheet(viewModel: viewModel)
        }
        #if !os(tvOS)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: Self.importableContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    try viewModel.importLog(from: url)
                } catch {
                    importErrorMessage = error.localizedDescription
                }
            case .failure(let error):
                importErrorMessage = error.localizedDescription
            }
        }
        .alert(
            "Import Failed",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "")
        }
        #endif
    }

    // MARK: - Subviews

    /// Header view with controls
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("LOGS")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(RetroTheme.retroPink)
                    .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 2, x: 0, y: 0)

                Spacer()

                #if os(tvOS)
                // Log level picker
                Menu {
                    Picker("Log Level", selection: $viewModel.minLogLevel) {
                        Text("Verbose").tag(LogLevel.verbose)
                        Text("Debug").tag(LogLevel.debug)
                        Text("Info").tag(LogLevel.info)
                        Text("Warning").tag(LogLevel.warning)
                        Text("Error").tag(LogLevel.error)
                    }
                } label: {
                    headerButtonContent(
                        icon: "line.3.horizontal.decrease",
                        label: "Level: \(viewModel.minLogLevel.name)",
                        accentColor: RetroTheme.retroBlue,
                        isFocused: focusedButton == .logLevel
                    )
                }
                .buttonStyle(TVMediaCardButtonStyle())
                .tvOSDisableFocusEffect()
                .focused($focusedButton, equals: .logLevel)

                // Auto-scroll toggle
                headerButton(
                    button: .autoScroll,
                    icon: viewModel.autoScroll ? "arrow.down.to.line.compact" : "arrow.up.to.line.compact",
                    accentColor: viewModel.autoScroll ? RetroTheme.retroBlue : RetroTheme.retroPink.opacity(0.7)
                ) {
                    viewModel.autoScroll.toggle()
                }

                // Sort order toggle button
                headerButton(
                    button: .sortOrder,
                    icon: viewModel.sortOrder == .newestFirst ? "arrow.down" : "arrow.up",
                    accentColor: RetroTheme.retroBlue
                ) {
                    viewModel.toggleSortOrder()
                }

                // Detail toggle
                headerButton(
                    button: .showDetails,
                    icon: viewModel.showFullDetails ? "list.bullet.indent" : "list.bullet",
                    accentColor: viewModel.showFullDetails ? RetroTheme.retroBlue : RetroTheme.retroPink.opacity(0.7)
                ) {
                    viewModel.showFullDetails.toggle()
                }

                // Clear logs button
                headerButton(
                    button: .clear,
                    icon: "trash",
                    accentColor: RetroTheme.retroPink.opacity(0.7)
                ) {
                    viewModel.clearLogs()
                }

                // Export / share button
                headerButton(
                    button: .export,
                    icon: "square.and.arrow.up",
                    accentColor: RetroTheme.retroBlue
                ) {
                    showingExportSheet = true
                }

                Spacer()

                // Fullscreen toggle button
                headerButton(
                    button: .fullscreen,
                    icon: isFullscreen ? "xmark" : "arrow.up.left.and.arrow.down.right",
                    accentColor: isFullscreen ? RetroTheme.retroPink : RetroTheme.retroBlue
                ) {
                    isFullscreen.toggle()
                }
                #else
                // Log level picker
                Menu {
                    Picker("Log Level", selection: $viewModel.minLogLevel) {
                        Text("Verbose").tag(LogLevel.verbose)
                        Text("Debug").tag(LogLevel.debug)
                        Text("Info").tag(LogLevel.info)
                        Text("Warning").tag(LogLevel.warning)
                        Text("Error").tag(LogLevel.error)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Level: \(viewModel.minLogLevel.name)")
                            .font(.system(size: 12))
                            .foregroundColor(RetroTheme.retroBlue)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(RetroTheme.retroBlue)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(RetroTheme.retroBlue, lineWidth: 1)
                    )
                }

                // Auto-scroll toggle
                Button(action: {
                    viewModel.autoScroll.toggle()
                }) {
                    Image(systemName: viewModel.autoScroll ? "arrow.down.to.line.compact" : "arrow.up.to.line.compact")
                        .font(.system(size: 12))
                        .foregroundColor(viewModel.autoScroll ? RetroTheme.retroBlue : RetroTheme.retroPink.opacity(0.7))
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(viewModel.autoScroll ? RetroTheme.retroBlue : RetroTheme.retroPink.opacity(0.7), lineWidth: 1)
                        )
                }

                // Sort order toggle button
                Button(action: {
                    viewModel.toggleSortOrder()
                }) {
                    Image(systemName: viewModel.sortOrder == .newestFirst ? "arrow.down" : "arrow.up")
                        .font(.system(size: 12))
                        .foregroundColor(RetroTheme.retroBlue)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(RetroTheme.retroBlue, lineWidth: 1)
                        )
                }

                // Detail toggle
                Button(action: {
                    viewModel.showFullDetails.toggle()
                }) {
                    Image(systemName: viewModel.showFullDetails ? "list.bullet.indent" : "list.bullet")
                        .font(.system(size: 12))
                        .foregroundColor(viewModel.showFullDetails ? RetroTheme.retroBlue : RetroTheme.retroPink.opacity(0.7))
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(viewModel.showFullDetails ? RetroTheme.retroBlue : RetroTheme.retroPink.opacity(0.7), lineWidth: 1)
                        )
                }

                // Copy Filtered logs button
                Button(action: {
                    viewModel.copyFilteredLogsToClipboard()
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor((viewModel.searchText.isEmpty || viewModel.copyableLinesAreEmpty) ? RetroTheme.retroPink.opacity(0.3) : RetroTheme.retroBlue)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder((viewModel.searchText.isEmpty || viewModel.copyableLinesAreEmpty) ? RetroTheme.retroPink.opacity(0.3) : RetroTheme.retroBlue, lineWidth: 1)
                        )
                }
                .disabled(viewModel.searchText.isEmpty || viewModel.copyableLinesAreEmpty)

                // Export / share button — exports the live session, so it is
                // disabled while an imported file is on screen to avoid
                // silently sharing different logs than the ones displayed.
                Button(action: {
                    showingExportSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                        .foregroundColor(RetroTheme.retroBlue)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(RetroTheme.retroBlue, lineWidth: 1)
                        )
                }
                .disabled(viewModel.importedSession != nil)

                // Import log button
                Button(action: {
                    showingImporter = true
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 12))
                        .foregroundColor(RetroTheme.retroBlue)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(RetroTheme.retroBlue, lineWidth: 1)
                        )
                }
                .accessibilityLabel("Import Log File")
                .accessibilityHint("Open a saved log file to view it in place of the live logs")

                // Clear logs button
                Button(action: {
                    viewModel.clearLogs()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(RetroTheme.retroPink.opacity(0.7))
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(RetroTheme.retroPink.opacity(0.7), lineWidth: 1)
                        )
                }
                .disabled(viewModel.importedSession != nil)

                Spacer()

                // Fullscreen toggle button
                if isFullscreen {
                    // Close fullscreen button
                    Button {
                        isFullscreen = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                            .foregroundColor(RetroTheme.retroPink)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(RetroTheme.retroPink, lineWidth: 1)
                            )
                    }
                } else {
                    // Expand to fullscreen button
                    Button {
                        isFullscreen = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12))
                            .foregroundColor(RetroTheme.retroBlue)
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(RetroTheme.retroBlue, lineWidth: 1)
                            )
                    }
                }
                #endif
            }

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(RetroTheme.retroBlue.opacity(0.7))

                TextField("Search logs...", text: $viewModel.searchText)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .autocorrectionDisabled(true)
                    #if !os(tvOS)
                    .textInputAutocapitalization(.never)
                    #endif

                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(RetroTheme.retroPink.opacity(0.7))
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(RetroTheme.retroBlue.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.5))
    }

    #if os(tvOS)
    /// Helper function to create header buttons with custom focus effects
    @ViewBuilder
    private func headerButton(
        button: HeaderButton,
        icon: String,
        label: String? = nil,
        accentColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        let isFocused = focusedButton == button

        Button(action: action) {
            headerButtonContent(icon: icon, label: label, accentColor: accentColor, isFocused: isFocused)
        }
        .buttonStyle(TVMediaCardButtonStyle())
        .tvOSDisableFocusEffect()
        .focused($focusedButton, equals: button)
    }

    /// Shared content for header buttons
    @ViewBuilder
    private func headerButtonContent(
        icon: String,
        label: String? = nil,
        accentColor: Color,
        isFocused: Bool
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))

            if let label = label {
                Text(label)
                    .font(.system(size: 12))
            }
        }
        .foregroundStyle(isFocused ? .white : accentColor)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isFocused ? accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(
                    isFocused ?
                        LinearGradient(
                            colors: [RetroTheme.retroPink.opacity(0.8), RetroTheme.retroBlue.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(colors: [accentColor.opacity(0.7), accentColor.opacity(0.5)], startPoint: .leading, endPoint: .trailing),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
    }
    #endif

    /// Single log entry row
    private func logEntryRow(_ log: LogEntry) -> some View {
        #if os(tvOS)
        LogEntryRowContent(log: log, viewModel: viewModel)
            .buttonStyle(.plain)
        #else
        LogEntryRowContent(log: log, viewModel: viewModel)
        #endif
    }

    // Helper function to manage auto-scrolling behavior
    private func handleAutoScroll(scrollView: ScrollViewProxy) {
        // An imported session is static and uses integer line IDs, so live-log
        // UUID targets aren't in the list. Leave the reader's scroll alone.
        guard viewModel.importedSession == nil else { return }
        if viewModel.autoScroll {
            if viewModel.sortOrder == .newestFirst {
                // Scroll to the top-most item (newest)
                if let firstLogId = viewModel.displayedLogs.first?.id {
                    withAnimation {
                        scrollView.scrollTo(firstLogId, anchor: .top)
                    }
                }
            } else { // .oldestFirst
                // Scroll to the bottom-most item (newest) which is at scrollSpace
                withAnimation {
                    scrollView.scrollTo(scrollSpace, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Log Entry Subview
    private struct LogEntryRowContent: View {
        let log: LogEntry
        let viewModel: RetroLogViewModel

        @State private var isCopying = false
        #if os(tvOS)
        @FocusState private var isFocused: Bool
        @State private var isExpanded: Bool = false
        #endif

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                // Header with timestamp and level
                HStack {
                    Text(log.formattedTimestamp)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(viewModel.logLevelColor(log.level).opacity(0.8))

                    Spacer()

                    Text(log.level.name.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(viewModel.logLevelColor(log.level))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(
                                    viewModel.logLevelColor(log.level).opacity(0.7),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: viewModel.logLevelColor(log.level).opacity(0.5), radius: 2, x: 0, y: 0)
                }

                // Message with glow effect based on log level
                Text(log.message)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: viewModel.logLevelColor(log.level).opacity(0.3), radius: 1, x: 0, y: 0)
                    #if os(tvOS)
                    .lineLimit(isExpanded || viewModel.showFullDetails ? nil : 3)
                    #else
                    .lineLimit(viewModel.showFullDetails ? nil : 3)
                    #endif

                // File and line if showing full details
                #if os(tvOS)
                if isExpanded || viewModel.showFullDetails {
                    let file = log.file
                    let line = log.line
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 8))
                            .foregroundColor(RetroTheme.retroBlue.opacity(0.7))

                        Text("\(file):\(line)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(RetroTheme.retroBlue.opacity(0.7))
                    }
                }
                #else
                if viewModel.showFullDetails {
                    let file = log.file
                    let line = log.line
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 8))
                            .foregroundColor(RetroTheme.retroBlue.opacity(0.7))

                        Text("\(file):\(line)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(RetroTheme.retroBlue.opacity(0.7))
                    }
                }
                #endif
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        isCopying ? RetroTheme.retroPink : viewModel.logLevelColor(log.level).opacity(0.3),
                                        isCopying ? RetroTheme.retroBlue : RetroTheme.retroDarkBlue.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isCopying ? 2 : 1
                            )
                    )
            )
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            #if os(tvOS)
            .contentShape(Rectangle())
            .focusable()
            .focused($isFocused)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isFocused ? Color.white.opacity(0.05) : Color.clear)
                    .animation(.easeInOut(duration: 0.15), value: isFocused)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isFocused ?
                            LinearGradient(
                                colors: [RetroTheme.retroPink.opacity(0.6), RetroTheme.retroBlue.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(colors: [.clear, .clear], startPoint: .leading, endPoint: .trailing),
                        lineWidth: isFocused ? 2 : 0
                    )
                    .animation(.easeInOut(duration: 0.15), value: isFocused)
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }
            .onPlayPauseCommand {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }
            #else
            .onLongPressGesture(minimumDuration: 0.5) {
                // Create a full log string with all details
                var logText = ""

                // Include timestamp and level
                logText += "[\(log.formattedTimestamp)] [\(log.level.name.uppercased())] "

                // Include category if available
                if !log.category.isEmpty {
                    logText += "(\(log.category)) "
                }

                // Include file and line if full details are shown
                if viewModel.showFullDetails {
                    let fileName = (log.file as NSString).lastPathComponent
                    logText += "[\(fileName):\(log.line)] "
                }

                // Add the main message
                logText += log.message

                UIPasteboard.general.string = logText

                // Visual feedback
                isCopying = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isCopying = false
                }
            }
            #endif // !os(tvOS)
        }
    }
}

// MARK: - Imported Session UI

extension RetroLogView {
    #if !os(tvOS)
    /// Content types the log importer accepts: plain text, `.log`, and exported `.zip` bundles.
    static var importableContentTypes: [UTType] {
        var types: [UTType] = [.plainText, .zip]
        if let logType = UTType(filenameExtension: "log") {
            types.append(logType)
        }
        return types
    }
    #endif

    /// Banner indicating the view is showing an imported session rather than live logs.
    func importedSessionBanner(name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(RetroTheme.retroPink)

            VStack(alignment: .leading, spacing: 1) {
                Text("VIEWING IMPORTED SESSION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(RetroTheme.retroPink)
                Text(name)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                viewModel.closeImportedSession()
            } label: {
                Text("LIVE LOGS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(RetroTheme.retroBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(RetroTheme.retroBlue, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(RetroTheme.retroPink.opacity(0.12))
    }

    /// Row for a single line of an imported log file.
    func importedLineRow(_ line: RetroLogViewModel.ImportedLogLine) -> some View {
        Text(line.text.isEmpty ? " " : line.text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(line.level.map { viewModel.logLevelColor($0) } ?? .white.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
            #if !os(tvOS)
            .textSelection(.enabled)
            #endif
            .padding(.vertical, 1)
    }
}

// MARK: - Preview

#if DEBUG
struct RetroLogView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            RetroTheme.retroDarkBlue.edgesIgnoringSafeArea(.all)

            RetroLogView()
                .frame(width: 500, height: 400)
                .padding()
        }
    }
}
#endif
