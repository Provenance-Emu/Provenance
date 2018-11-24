import PMKAssetsLibrary
import AssetsLibrary
import PromiseKit
import UIKit

@UIApplicationMain
class App: UITableViewController, UIApplicationDelegate {

    var window: UIWindow? = UIWindow(frame: UIScreen.main.bounds)
    let testSuceededSwitch = UISwitch()

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        window!.rootViewController = self
        window!.backgroundColor = UIColor.purple
        window!.makeKeyAndVisible()
        UIView.setAnimationsEnabled(false)
        return true
    }

    override func viewDidLoad() {
        view.addSubview(testSuceededSwitch)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.text = "1"
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        _ = promise(UIImagePickerController()).done { (data: NSData) in
            self.testSuceededSwitch.isOn = true
        }
    }
}
