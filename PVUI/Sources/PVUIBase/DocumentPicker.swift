//
//  DocumentPicker.swift
//  UITesting
//
//  Created by Cascade on 3/26/25.
//

import SwiftUI
import UniformTypeIdentifiers

// Document picker for importing game files
public struct DocumentPicker: UIViewControllerRepresentable {
    public let onImport: ([URL]) -> Void
    
    public init(onImport: @escaping ([URL]) -> Void) {
        self.onImport = onImport
    }
    
    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Define the file types we want to import (ROM files)
        let supportedTypes: [UTType] = [
            .item,      // Generic item
            .content,   // Generic content
            .data,      // Generic data
            .archive,   // Archives (zip, 7z, etc.)
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onImport(urls)
        }
    }
}
