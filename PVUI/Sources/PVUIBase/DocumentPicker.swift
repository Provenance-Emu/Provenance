//
//  DocumentPicker.swift
//  Provenance
//
//  Created by Joseph Mattiello on 3/26/25.
//

import SwiftUI
import UniformTypeIdentifiers
import PVLogging

#if !os(tvOS)
/// Document picker for importing game files
/// This is a UIViewControllerRepresentable wrapper around UIDocumentPickerViewController
public struct DocumentPicker: UIViewControllerRepresentable {
    /// The callback to be executed when files are imported
    public let onImport: ([URL]) -> Void
    
    /// Reference to the document picker manager to handle state
    @EnvironmentObject private var documentPickerManager: DocumentPickerManager
    
    public init(onImport: @escaping ([URL]) -> Void) {
        self.onImport = onImport
        VLOG("DocumentPicker: Initialized with onImport callback")
    }
    
    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        ILOG("DocumentPicker: Creating UIDocumentPickerViewController")
        
        // Define the file types we want to import (ROM files)
        // Be explicit to avoid some providers filtering out custom UTIs.
        let romExtensions = [
            "iso", "rvz", "wia", // Disc images and Dolphin formats
            "gcm", "gcz",          // GameCube images
            "wbfs", "wad",         // Wii images and channels
            "dol", "elf",          // Executables
            "tgc",                  // Triforce/GameCube container
            "ciso",                 // Compressed ISO
            "bin", "cue",          // Cue/bin pairs
            "chd"                    // MAME/CHD disc images
        ]
        let romTypes = romExtensions.compactMap { UTType(filenameExtension: $0, conformingTo: .data) }
        let supportedTypes: [UTType] = romTypes + [.archive]
        DLOG("DocumentPicker: supported UTTypes -> \(supportedTypes.map { $0.identifier })")
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        
        // Ensure the picker doesn't get dismissed prematurely
        picker.modalPresentationStyle = .fullScreen
        
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
            super.init()
        }
        
        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            ILOG("DocumentPicker: Selected \(urls.count) documents")
            
            // Immediately capture the selected URLs to prevent loss
            let selectedURLs = urls
            
            // Immediately store the callback to prevent it from being lost if the view service terminates
            let importCallback = parent.onImport
            let documentPickerManager = parent.documentPickerManager
            
            // Execute the callbacks immediately on the main thread
            // This ensures they're called even if the view service terminates
            DispatchQueue.main.async {
                ILOG("DocumentPicker: Immediately executing callback with \(selectedURLs.count) URLs")
                
                // Call the direct callback first
                importCallback(selectedURLs)
                
                // Then notify the document picker manager
                documentPickerManager.documentPickerCompleted(urls: selectedURLs)
            }
            
            // Also set up a backup execution with a delay in case the immediate execution is interrupted
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                ILOG("DocumentPicker: Backup execution of callback with \(selectedURLs.count) URLs")
                
                // Call the callback again (it's idempotent, so calling twice is safe)
                importCallback(selectedURLs)
            }
        }
        
        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            ILOG("DocumentPicker: Cancelled by user")
            
            // Notify the document picker manager that selection was cancelled
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Call the document picker manager's completion handler with empty array
                self.parent.documentPickerManager.documentPickerCompleted(urls: [])
                
                // Also call the direct callback for backward compatibility
                self.parent.onImport([])
            }
        }
    }
}
#endif
