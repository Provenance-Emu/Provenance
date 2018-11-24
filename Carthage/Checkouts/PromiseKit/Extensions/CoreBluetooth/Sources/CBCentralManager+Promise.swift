import CoreBluetooth
#if !PMKCocoaPods
import PromiseKit
#endif


private class CentralManager: CBCentralManager, CBCentralManagerDelegate {
  var retainCycle: CentralManager?
  let (promise, fulfill) = Guarantee<CBCentralManager>.pending()

  @objc func centralManagerDidUpdateState(_ manager: CBCentralManager) {
    if manager.state != .unknown {
      fulfill(manager)
    }
  }
}

extension CBCentralManager {
  /// A promise that fulfills when the state of CoreBluetooth changes
    public class func state(options: [String: Any]? = [CBCentralManagerOptionShowPowerAlertKey: false]) -> Guarantee<CBCentralManager> {
    let manager = CentralManager(delegate: nil, queue: nil, options: options)
    manager.delegate = manager
    manager.retainCycle = manager
    manager.promise.done { _ in
      manager.retainCycle = nil
    }
    return manager.promise
  }
}
