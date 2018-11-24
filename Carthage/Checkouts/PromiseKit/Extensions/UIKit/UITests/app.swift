import PromiseKit
import PMKUIKit
import UIKit

@UIApplicationMain
class App: UITableViewController, UIApplicationDelegate {
    var window: UIWindow? = UIWindow(frame: UIScreen.main.bounds)

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]? = nil) -> Bool {
        window!.rootViewController = self
        window!.backgroundColor = UIColor.purple
        window!.makeKeyAndVisible()
        UIView.setAnimationsEnabled(false)
        return true
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = Row(indexPath)?.description
        return cell
    }

    let testSuceededButton = UIButton()

    override func viewDidLoad() {
        testSuceededButton.setTitle("unused", for: .normal)
        testSuceededButton.sizeToFit()
        testSuceededButton.backgroundColor = UIColor.blue
        testSuceededButton.isEnabled = false

        view.addSubview(testSuceededButton)
    }

    override func viewDidLayoutSubviews() {
        testSuceededButton.center = view.center
    }

    private func success() {
        self.testSuceededButton.isEnabled = true
    }

#if !os(tvOS)
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Row(indexPath)! {
        case .ImagePickerCancel:
            let p = promise(UIImagePickerController())
            p.catch(policy: .allErrors) { error in
                guard (error as! CancellableError).isCancelled else { abort() }
                self.success()
            }
            p.catch { error in
                abort()
            }
        case .ImagePickerEditImage:
            let picker = UIImagePickerController()
            picker.allowsEditing = true
            _ = promise(picker).done { _ in
                self.success()
            }
        case .ImagePickerPickImage:
            _ = promise(UIImagePickerController()).done { image in
                self.success()
            }
        }
    }
#endif
}

enum Row: Int {
    case ImagePickerCancel
    case ImagePickerEditImage
    case ImagePickerPickImage

    init?(_ indexPath: IndexPath) {
        guard let row = Row(rawValue: indexPath.row) else {
            return nil
        }
        self = row
    }

    var indexPath: IndexPath {
        return IndexPath(row: rawValue, section: 0)
    }

    var description: String {
        return (rawValue + 1).description
    }

    static var count: Int {
        var x = 0
        while Row(rawValue: x) != nil {
            x += 1
        }
        return x
    }
}
