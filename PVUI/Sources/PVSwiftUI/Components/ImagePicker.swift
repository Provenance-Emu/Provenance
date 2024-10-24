//
//  ImagePicker.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/22/24.
//

import SwiftUI
import PVThemes
import PVLogging

#if !os(tvOS)
struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    var sourceType = UIImagePickerController.SourceType.photoLibrary
    var onImageSelected: ((UIImage) -> Void)?

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        DLOG("ImagePicker: makeUIViewController called")
        let imagePicker = UIImagePickerController()
        imagePicker.navigationBar.tintColor = ThemeManager.shared.currentPalette.barButtonItemTint
        imagePicker.allowsEditing = false
        imagePicker.sourceType = sourceType
        imagePicker.delegate = context.coordinator
        DLOG("ImagePicker: UIImagePickerController created with sourceType: \(sourceType.rawValue)")
        return imagePicker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController,
                                context: UIViewControllerRepresentableContext<ImagePicker>) {
        DLOG("ImagePicker: updateUIViewController called")
    }

    func makeCoordinator() -> Coordinator {
        DLOG("ImagePicker: makeCoordinator called")
        return Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
            super.init()
            DLOG("ImagePicker: Coordinator initialized")
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            DLOG("ImagePicker: imagePickerController(_:didFinishPickingMediaWithInfo:) called")
            if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
                DLOG("ImagePicker: Image selected: \(image.size.width)x\(image.size.height)")
                parent.onImageSelected?(image)
            } else {
                DLOG("ImagePicker: Failed to get image from info dictionary")
            }
            parent.presentationMode.wrappedValue.dismiss()
            DLOG("ImagePicker: ImagePicker dismissed")
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            DLOG("ImagePicker: imagePickerControllerDidCancel(_:) called")
            parent.presentationMode.wrappedValue.dismiss()
            DLOG("ImagePicker: ImagePicker cancelled and dismissed")
        }
    }
}
#endif

#if DEBUG
extension ImagePicker {
    static func printDebugInfo() {
        DLOG("ImagePicker Debug Information:")
        DLOG("Available source types: \(UIImagePickerController.availableMediaTypes(for: .photoLibrary) ?? [])")
        DLOG("Is camera available: \(UIImagePickerController.isSourceTypeAvailable(.camera))")
        DLOG("Is photo library available: \(UIImagePickerController.isSourceTypeAvailable(.photoLibrary))")
        DLOG("Is saved photos album available: \(UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum))")
    }
}
#endif

/*
// Sample usage

struct GameContextMenu: View {
    var game: PVGame
    @State private var showImagePicker = false

    var body: some View {
        Button("Choose Cover") {
            DLOG("GameContextMenu: Choose Cover button tapped")
            showImagePicker = true
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(onImageSelected: { image in
                DLOG("GameContextMenu: Image selected from ImagePicker. Size: \(image.size)")
                saveArtwork(image: image, forGame: game)
                showImagePicker = false
            })
        }
    }

    private func saveArtwork(image: UIImage, forGame game: PVGame) {
        DLOG("GameContextMenu: Attempting to save artwork for game
*/
