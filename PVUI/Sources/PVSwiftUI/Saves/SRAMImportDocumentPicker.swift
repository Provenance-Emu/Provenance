//
//  SRAMImportDocumentPicker.swift
//  PVUI
//
//  Created by Agent on 2026-03-28.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  A document picker filtered to battery save file types (.sav, .srm, .ram, .zip).
//  Part of issue #3553 (SRAM explicit import/export).
//

#if !os(tvOS)
import SwiftUI
import UniformTypeIdentifiers
import PVLogging

/// Document picker that accepts battery save files (.sav, .srm, .ram) and zip archives.
struct SRAMImportDocumentPicker: UIViewControllerRepresentable {
    let onImport: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let sramExtensions = ["sav", "srm", "ram", "zip"]
        let types = sramExtensions.compactMap { UTType(filenameExtension: $0, conformingTo: .data) }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types.isEmpty ? [.data] : types, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImport: onImport)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onImport: ([URL]) -> Void

        init(onImport: @escaping ([URL]) -> Void) {
            self.onImport = onImport
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            ILOG("SRAMImportDocumentPicker: selected \(urls.count) file(s)")
            DispatchQueue.main.async { self.onImport(urls) }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            ILOG("SRAMImportDocumentPicker: cancelled")
            DispatchQueue.main.async { self.onImport([]) }
        }
    }
}
#endif
