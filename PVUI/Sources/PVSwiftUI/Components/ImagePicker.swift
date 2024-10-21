//
//  ImagePicker.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/22/24.
//

import SwiftUI

#if !os(tvOS)
struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var selectedImage: UIImage?
    @Binding var didSet: Bool
    var sourceType = UIImagePickerController.SourceType.photoLibrary

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.navigationBar.tintColor = .systemBlue
        imagePicker.allowsEditing = false
        imagePicker.sourceType = sourceType
        imagePicker.delegate = context.coordinator
        return imagePicker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController,
                                context: UIViewControllerRepresentableContext<ImagePicker>) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let control: ImagePicker

        init(_ control: ImagePicker) {
            self.control = control
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
                control.selectedImage = image
                control.didSet = true
            }
            control.presentationMode.wrappedValue.dismiss()
        }
    }
}
#endif
/*
// Sample usage

struct SignatureImageView: View {
    @Binding var isSet: Bool
    @Binding var selection: UIImage

    @State private var showPopover = false

    var body: some View {
        Button(action: {
            showPopover.toggle()
        }) {
            if isSet {
                Image(uiImage: selection)
                    .resizable()
                    .frame(maxHeight: maxHeight)
            } else {
                ZStack {
                    Color.white
                    Text("Choose signature image")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }.frame(height: maxHeight)
                .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray))
            }
        }.popover(isPresented: $showPopover) {
            ImagePicker(selectedImage: $selection, didSet: $isSet)
        }
    }
}
*/
