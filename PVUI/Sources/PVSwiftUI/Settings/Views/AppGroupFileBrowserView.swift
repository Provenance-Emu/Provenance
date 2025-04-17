//
//  AppGroupFileBrowserView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 4/15/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVLibrary
import PVSupport
import PVLogging

/// A view that allows browsing the App Group container files
public struct AppGroupFileBrowserView: View {
    
    // MARK: - Properties
    
    /// Current directory being displayed
    @State private var currentDirectory: URL
    
    /// Items in the current directory
    @State private var directoryItems: [DirectoryItem] = []
    
    /// Selected item for detail view
    @State private var selectedItem: DirectoryItem?
    
    /// Show file contents
    @State private var showingFileContents = false
    
    /// File contents
    @State private var fileContents: String = ""
    
    /// Error message
    @State private var errorMessage: String?
    
    /// Loading state
    @State private var isLoading = false
    
    // MARK: - Initialization
    
    public init() {
        // Start at the app group container
        let appGroupID = PVAppGroupId
        
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            self._currentDirectory = State(initialValue: containerURL)
        } else {
            // Fallback to documents directory if app group container is not available
            self._currentDirectory = State(initialValue: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!)
            ELOG("Could not access app group container: \(appGroupID)")
        }
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            // Background
            Color.retroDarkBlue.edgesIgnoringSafeArea(.all)
            
            VStack {
                // Header with current path
                HStack {
                    Text("App Group Browser")
                        .font(.headline)
                        .foregroundColor(.retroBlue)
                    
                    Spacer()
                    
                    // Go up button - larger for tvOS
                    Button(action: navigateUp) {
                        HStack {
                            Image(systemName: "arrow.up.circle")
                            Text("Go Up")
                        }
                        .padding()
                        .background(Color.retroPurple.opacity(0.3))
                        .cornerRadius(8)
                        .foregroundColor(.retroPink)
                    }
                    .disabled(isRootDirectory)
                    #if os(tvOS)
                    .buttonStyle(CardButtonStyle())
                    .padding(.horizontal)
                    #endif
                }
                .padding(.horizontal)
                
                // Current path
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(currentDirectory.path)
                        .font(.caption)
                        .foregroundColor(.retroBlue)
                        .lineLimit(1)
                        #if os(tvOS)
                        .padding(8)
                        #endif
                }
                .padding(.horizontal)
                
                // Directory contents
                #if os(tvOS)
                // tvOS-specific list with larger items and focus support
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(directoryItems) { item in
                            Button(action: { handleItemTap(item) }) {
                                DirectoryItemRow(item: item)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(CardButtonStyle())
                        }
                    }
                    .padding()
                }
                .background(Color.black.opacity(0.3))
                #else
                // iOS list
                List {
                    ForEach(directoryItems) { item in
                        DirectoryItemRow(item: item)
                            .onTapGesture {
                                handleItemTap(item)
                            }
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color.black.opacity(0.5))
                #endif
                
                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()
            
            // Loading indicator
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                    .scaleEffect(1.5)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
                    .padding(20)
            }
        }
        .onAppear(perform: loadDirectoryContents)
        .navigationTitle("App Group Files")
        .sheet(isPresented: $showingFileContents) {
            FileContentsView(fileName: selectedItem?.name ?? "", contents: fileContents)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Loads the contents of the current directory
    private func loadDirectoryContents() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                let contents = try fileManager.contentsOfDirectory(at: currentDirectory, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .creationDateKey], options: [.skipsHiddenFiles])
                
                var items: [DirectoryItem] = []
                
                for url in contents {
                    let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .creationDateKey])
                    let isDirectory = resourceValues.isDirectory ?? false
                    let size = resourceValues.fileSize ?? 0
                    let creationDate = resourceValues.creationDate ?? Date()
                    
                    let item = DirectoryItem(
                        id: url.lastPathComponent,
                        name: url.lastPathComponent,
                        url: url,
                        isDirectory: isDirectory,
                        size: size,
                        creationDate: creationDate
                    )
                    
                    items.append(item)
                }
                
                // Sort: directories first, then alphabetically
                items.sort { (item1, item2) in
                    if item1.isDirectory && !item2.isDirectory {
                        return true
                    } else if !item1.isDirectory && item2.isDirectory {
                        return false
                    } else {
                        return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
                    }
                }
                
                DispatchQueue.main.async {
                    self.directoryItems = items
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error loading directory: \(error.localizedDescription)"
                    self.isLoading = false
                    ELOG("Error loading directory: \(error)")
                }
            }
        }
    }
    
    /// Handles tapping on an item
    private func handleItemTap(_ item: DirectoryItem) {
        if item.isDirectory {
            // Navigate into directory
            currentDirectory = item.url
            loadDirectoryContents()
        } else {
            // View file contents
            selectedItem = item
            loadFileContents(item)
        }
    }
    
    /// Loads the contents of a file
    private func loadFileContents(_ item: DirectoryItem) {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Check if it's a text file or binary
                let fileExtension = item.url.pathExtension.lowercased()
                let textExtensions = ["txt", "json", "xml", "plist", "log", "md", "swift", "h", "m", "c", "cpp", "html", "css", "js", "py", "sh", "bat", "csv"]
                
                if textExtensions.contains(fileExtension) || item.size < 1_000_000 { // Only try to read files < 1MB
                    let data = try Data(contentsOf: item.url)
                    
                    // Try to interpret as text
                    if let string = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.fileContents = string
                            self.showingFileContents = true
                            self.isLoading = false
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.fileContents = "Binary file (size: \(ByteCountFormatter.string(fromByteCount: Int64(item.size), countStyle: .file)))"
                            self.showingFileContents = true
                            self.isLoading = false
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.fileContents = "File too large to display (size: \(ByteCountFormatter.string(fromByteCount: Int64(item.size), countStyle: .file)))"
                        self.showingFileContents = true
                        self.isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.fileContents = "Error loading file: \(error.localizedDescription)"
                    self.showingFileContents = true
                    self.isLoading = false
                    ELOG("Error loading file: \(error)")
                }
            }
        }
    }
    
    /// Navigates up one directory
    private func navigateUp() {
        guard !isRootDirectory else { return }
        
        currentDirectory = currentDirectory.deletingLastPathComponent()
        loadDirectoryContents()
    }
    
    /// Checks if the current directory is the root directory
    private var isRootDirectory: Bool {
        // Check if we're at the app group container root
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId) {
            return currentDirectory.path == containerURL.path
        }
        return false
    }
}

// MARK: - Directory Item Model

/// Represents an item in the directory
struct DirectoryItem: Identifiable {
    let id: String
    let name: String
    let url: URL
    let isDirectory: Bool
    let size: Int
    let creationDate: Date
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }
}

// MARK: - Directory Item Row View

/// A row view for a directory item
struct DirectoryItemRow: View {
    let item: DirectoryItem
    
    var body: some View {
        HStack {
            // Icon
            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundColor(item.isDirectory ? .retroBlue : .retroPink)
                #if os(tvOS)
                .font(.title)
                .frame(width: 50)
                #else
                .font(.title3)
                #endif
            
            // Name and details
            VStack(alignment: .leading) {
                Text(item.name)
                    #if os(tvOS)
                    .font(.title3)
                    #else
                    .font(.body)
                    #endif
                    .foregroundColor(.white)
                
                HStack {
                    Text(item.formattedSize)
                    Text("•")
                    Text(item.formattedDate)
                }
                #if os(tvOS)
                .font(.body)
                #else
                .font(.caption)
                #endif
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Arrow for directories
            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    #if os(tvOS)
                    .font(.title2)
                    .frame(width: 30)
                    #endif
            }
        }
        .padding(.vertical, 4)
    }
}

#if os(tvOS)
// Custom button style for tvOS
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.1 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.retroPink.opacity(configuration.isPressed ? 0.8 : 0.3), lineWidth: 3)
                    )
            )
    }
}
#endif

// MARK: - File Contents View

/// A view for displaying file contents
struct FileContentsView: View {
    let fileName: String
    let contents: String
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.retroDarkBlue.edgesIgnoringSafeArea(.all)
            
            VStack {
                // Header
                HStack {
                    Text(fileName)
                        .font(.headline)
                        .foregroundColor(.retroBlue)
                    
                    Spacer()
                    
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Close")
                        }
                        .padding()
                        .background(Color.retroPurple.opacity(0.3))
                        .cornerRadius(8)
                        .foregroundColor(.retroPink)
                    }
                    #if os(tvOS)
                    .buttonStyle(CardButtonStyle())
                    .padding(.horizontal)
                    #endif
                }
                .padding()
                
                // File contents
                ScrollView {
                    Text(contents)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        #if os(tvOS)
                        .lineSpacing(8) // More spacing for tvOS readability
                        #endif
                }
                .background(Color.black.opacity(0.5))
                .cornerRadius(10)
            }
            .padding()
        }
    }
}

#if DEBUG
struct AppGroupFileBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        AppGroupFileBrowserView()
    }
}
#endif
