import UIKit
import ObjectiveC

extension PVEmulatorViewController {

    // Called when the class is loaded
    @objc public static func swizzleMethods() {
        let originalSelector = #selector(PVEmulatorViewController.viewDidLoad)
        let swizzledSelector = #selector(PVEmulatorViewController.swizzled_viewDidLoad)

        guard let originalMethod = class_getInstanceMethod(PVEmulatorViewController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(PVEmulatorViewController.self, swizzledSelector) else {
            return
        }

        // Add the swizzled method to the class
        let didAddMethod = class_addMethod(
            PVEmulatorViewController.self,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )

        if didAddMethod {
            // If we successfully added the method, replace the original implementation
            class_replaceMethod(
                PVEmulatorViewController.self,
                swizzledSelector,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            // If we couldn't add the method, swap the implementations
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }

    // Our replacement for viewDidLoad
    @objc func swizzled_viewDidLoad() {
        // Call the original implementation
        self.swizzled_viewDidLoad()

        // Add our custom code - call the async method in a Task
        Task {
            do {
                try await setupDeltaSkinView()
            } catch {
                print("Error setting up Delta Skin: \(error)")
            }
        }

        print("Swizzled viewDidLoad called, setting up Delta Skin if enabled")
    }
}

// Initialize the swizzling when the module loads
@objc class PVEmulatorViewControllerInitializer: NSObject {
    @objc static let shared = PVEmulatorViewControllerInitializer()

    private override init() {
        super.init()
        PVEmulatorViewController.swizzleMethods()
    }
}
