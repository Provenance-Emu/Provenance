import Foundation
import HomeKit
#if !PMKCocoaPods
import PromiseKit
#endif

#if !os(tvOS) && !os(watchOS)

extension HMHome {
    
    @available(iOS 8.0, *)
    public func updateName(_ name: String) -> Promise<Void> {
        return Promise { seal in
            self.updateName(name, completionHandler: seal.resolve)
        }
    }
    
    /// Add and setup a new HMAccessory.  Displays it's own UI
    @available(iOS 11.3, *)
    public func addAndSetupAccessories(with payload: HMAccessorySetupPayload) -> Promise<[HMAccessory]> {
        return Promise { seal in
            self.addAndSetupAccessories(with: payload, completionHandler: seal.resolve)
        }
    }

    /// Add and setup a new HMAccessory.  Displays it's own UI
    @available(iOS 10.0, *)
    public func addAndSetupAccessories() -> Promise<[HMAccessory]> {
        // We need to compare what we have before the action to after to know what is new
        let beforeAccessories = self.accessories
        let home = self
        
        return Promise { seal in
            self.addAndSetupAccessories { error in
                if let error = error { seal.reject(error) }
                else {
                    let newAccessories = home.accessories.filter { beforeAccessories.contains($0) == false }
                    seal.fulfill(newAccessories)
                }
            }
        }
    }

    @available(iOS 8.0, *)
    public func addAccessory(_ accessory: HMAccessory) -> Promise<Void> {
        return Promise { seal in
            self.addAccessory(accessory, completionHandler: seal.resolve)
        }
    }
    
    @available(iOS 8.0, *)
    public func assignAccessory(_ accessory: HMAccessory, to room: HMRoom) -> Promise<Void> {
        return Promise { seal in
            self.assignAccessory(accessory, to: room, completionHandler: seal.resolve)
        }
    }
    
    @available(iOS 8.0, *)
    public func removeAccessory(_ accessory: HMAccessory) -> Promise<Void> {
        return Promise { seal in
            self.removeAccessory(accessory, completionHandler: seal.resolve)
        }
    }
    
    /**
        Rooms
    */
    @available(iOS 8.0, *)
    public func addRoom(withName name: String) -> Promise<HMRoom> {
        return Promise { seal in
            self.addRoom(withName: name, completionHandler: seal.resolve)
        }
    }
    
    @available(iOS 8.0, *)
    public func removeRoom(_ room: HMRoom) -> Promise<Void> {
        return Promise { seal in
            self.removeRoom(room, completionHandler: seal.resolve)
        }
    }
}
#endif
