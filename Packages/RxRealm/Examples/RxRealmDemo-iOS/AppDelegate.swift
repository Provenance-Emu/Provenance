import RealmSwift
import UIKit

let formatter: DateFormatter = {
  let f = DateFormatter()
  f.timeStyle = .long
  return f
}()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // reset the realm on each app launch
    let realm = try! Realm()
    try! realm.write {
      realm.deleteAll()
    }

    return true
  }
}
