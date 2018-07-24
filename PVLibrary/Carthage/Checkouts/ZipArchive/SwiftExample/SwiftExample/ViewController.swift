//
//  ViewController.swift
//  SwiftExample
//
//  Created by Sean Soper on 10/23/15.
//
//

import UIKit

#if UseCarthage
    import ZipArchive
#else
    import SSZipArchive
#endif

class ViewController: UIViewController {

    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var zipButton: UIButton!
    @IBOutlet weak var unzipButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!

    @IBOutlet weak var file1: UILabel!
    @IBOutlet weak var file2: UILabel!
    @IBOutlet weak var file3: UILabel!

    var zipPath: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        file1.text = ""
        file2.text = ""
        file3.text = ""
    }

    // MARK: IBAction

    @IBAction func zipPressed(_: UIButton) {
        let sampleDataPath = Bundle.main.bundleURL.appendingPathComponent("Sample Data").path
        zipPath = tempZipPath()
        let password = passwordField.text

        let success = SSZipArchive.createZipFile(atPath: zipPath!,
                                                 withContentsOfDirectory: sampleDataPath,
                                                 keepParentDirectory: false,
                                                 compressionLevel: -1,
                                                 password: password?.isEmpty == false ? password : nil,
                                                 aes: true,
                                                 progressHandler: nil)
        if success {
            print("Success zip")
            unzipButton.isEnabled = true
            zipButton.isEnabled = false
        } else {
            print("No success zip")
        }
        resetButton.isEnabled = true
    }

    @IBAction func unzipPressed(_: UIButton) {
        guard let zipPath = self.zipPath else {
            return
        }

        guard let unzipPath = tempUnzipPath() else {
            return
        }

        let password = passwordField.text
        let success: Bool = SSZipArchive.unzipFile(atPath: zipPath,
                                                   toDestination: unzipPath,
                                                   preserveAttributes: true,
                                                   overwrite: true,
                                                   nestedZipLevel: 1,
                                                   password: password?.isEmpty == false ? password : nil,
                                                   error: nil,
                                                   delegate: nil,
                                                   progressHandler: nil,
                                                   completionHandler: nil)
        if success != false {
            print("Success unzip")
        } else {
            print("No success unzip")
            return
        }

        var items: [String]
        do {
            items = try FileManager.default.contentsOfDirectory(atPath: unzipPath)
        } catch {
            return
        }

        for (index, item) in items.enumerated() {
            switch index {
            case 0:
                file1.text = item
            case 1:
                file2.text = item
            case 2:
                file3.text = item
            default:
                print("Went beyond index of assumed files")
            }
        }

        unzipButton.isEnabled = false
    }

    @IBAction func resetPressed(_: UIButton) {
        file1.text = ""
        file2.text = ""
        file3.text = ""
        zipButton.isEnabled = true
        unzipButton.isEnabled = false
        resetButton.isEnabled = false
    }

    // MARK: Private

    func tempZipPath() -> String {
        var path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        path += "/\(UUID().uuidString).zip"
        return path
    }

    func tempUnzipPath() -> String? {
        var path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        path += "/\(UUID().uuidString)"
        let url = URL(fileURLWithPath: path)

        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return nil
        }
        return url.path
    }
    
}
