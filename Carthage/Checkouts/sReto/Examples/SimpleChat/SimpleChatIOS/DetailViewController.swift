//
//  DetailViewController.swift
//  SimpleChatIOS
//
//  Created by Julian Asamer on 27/01/15.
//  Copyright (c) 2014 LS1 TUM. All rights reserved.
//

import UIKit
import QuickLook

private var kvoContext = 0

class ChatView : UIView {
    @IBOutlet var bottomConstraint: NSLayoutConstraint!
    @IBOutlet var chatText: UITextView!
    @IBOutlet var controlsView: UIView!
    @IBOutlet var typedTextField: UITextField!
    @IBOutlet weak var progressView: UIProgressView!
}

class DetailViewController: UIViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, ChatRoomDelegate, QLPreviewControllerDelegate, QLPreviewControllerDataSource {
    var chatView: ChatView {
        return self.view as! ChatView
    }
    let previewController = QLPreviewController()
    var previewedItemURL: URL?

    var chatRoom: ChatRoom? {
        willSet {
            if let chatRoom = chatRoom {
                chatRoom.removeObserver(self, forKeyPath: "chatText")
                chatRoom.removeObserver(self, forKeyPath: "remoteDisplayName")
                chatRoom.removeObserver(self, forKeyPath: "fileProgress")
            }
        }
        didSet {
            self.configureView()
        }
    }

    func configureView() {
        if let chatRoom: ChatRoom = self.chatRoom {
            chatRoom.delegate = self
            self.updateView()

            chatRoom.addObserver(self, forKeyPath: "chatText", options: NSKeyValueObservingOptions.new, context: &kvoContext)
            chatRoom.addObserver(self, forKeyPath: "remoteDisplayName", options: .new, context: &kvoContext)
            chatRoom.addObserver(self, forKeyPath: "fileProgress", options: .new, context: &kvoContext)
        }
    }

    func updateView() {
        self.chatView.chatText.text = chatRoom?.chatText
        if let displayName = chatRoom?.remoteDisplayName {
            self.navigationItem.title = "Chat with \(displayName)"
        } else {
            self.navigationItem.title = "Loading display name..."
        }
        self.chatView.chatText.scrollRangeToVisible(NSRange(location: self.chatView.chatText.text.count - 1, length: 0))
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (context == &kvoContext) {
            if keyPath == "fileProgress" {
                self.chatView.progressView.progress = Float(self.chatRoom?.fileProgress ?? 0) / 100.0
            } else {
                self.updateView()
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardDidHide, object: nil)

        self.chatView.chatText.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(DetailViewController.hideKeyboard)))

        previewController.delegate = self
        previewController.dataSource = self

        self.configureView()
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        let userInfo = notification.userInfo!
        let duration: Double = (userInfo[UIKeyboardAnimationDurationUserInfoKey]! as AnyObject).doubleValue
        let curve = (userInfo[UIKeyboardAnimationCurveUserInfoKey]! as AnyObject).uintValue
        let keyboardFrameEnd = self.view.convert((userInfo[UIKeyboardFrameEndUserInfoKey]! as AnyObject).cgRectValue, to: nil)

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [UIViewAnimationOptions.beginFromCurrentState, UIViewAnimationOptions(rawValue: curve!)],
            animations: { () -> Void in
                self.chatView.bottomConstraint.constant = keyboardFrameEnd.size.height
                self.view.layoutIfNeeded()
                self.chatView.chatText.scrollRangeToVisible(NSRange(location: self.chatView.chatText.text.lengthOfBytes(using: String.Encoding.utf8) - 1, length: 0))
            },
            completion: { _ in ()}
        )
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        let userInfo = notification.userInfo!
        let duration: Double = (userInfo[UIKeyboardAnimationDurationUserInfoKey]! as AnyObject).doubleValue
        let curve = (userInfo[UIKeyboardAnimationCurveUserInfoKey]! as AnyObject).uintValue

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [UIViewAnimationOptions.beginFromCurrentState, UIViewAnimationOptions(rawValue: curve!)],
            animations: {
                self.chatView.bottomConstraint.constant = 0
                self.view.layoutIfNeeded()
            },
            completion: { (b) -> Void in () }
        )
    }

    @objc func hideKeyboard() {
        self.chatView.typedTextField.resignFirstResponder()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.chatRoom?.sendMessage(textField.text!)
        textField.text = ""
        return false
    }

    @IBAction func sendFile(_ sender: AnyObject) {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = UIImagePickerControllerSourceType.photoLibrary
        imagePicker.delegate = self
        self.present(imagePicker, animated: true, completion: {})
    }

    func chatRoom(_: ChatRoom, completedReceivingFileAtPath path: String) {
        self.previewedItemURL = URL(fileURLWithPath: path)
        self.previewController.reloadData()
        self.present(self.previewController, animated: true, completion: {})
    }
    func chatRoom(_: ChatRoom, pathForSavingFileWithName fileName: String) throws -> String? {
        return try String(contentsOf:URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName))
    }

    func getTempPath() throws -> String {
        return try String(contentsOf:URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
    }

    @nonobjc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) throws {
        if let image = (info[UIImagePickerControllerEditedImage] ?? info[UIImagePickerControllerOriginalImage]) as? UIImage {

            let directory = try getTempPath()
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
            let path = try String(contentsOf:URL(fileURLWithPath: directory).appendingPathComponent("image.jpg"))
            try? UIImageJPEGRepresentation(image, 1)!.write(to: URL(fileURLWithPath: path), options: [.atomic])
            self.chatRoom?.sendFile(path)
        } else if let path = (info[UIImagePickerControllerMediaURL] as? URL)?.path {
            self.chatRoom?.sendFile(path)
        }

        picker.dismiss(animated: true, completion: {})
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return previewedItemURL == nil ? 0 : 1
    }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return previewedItemURL! as QLPreviewItem
    }
    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        self.previewedItemURL = nil
    }
}
