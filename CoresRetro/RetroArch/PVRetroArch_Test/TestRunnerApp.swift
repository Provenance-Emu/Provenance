//
//  TestRunnerApp.swift
//  PVRetroArch
//
//  Created by Joseph Mattiello on 2/19/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
private import class PVRetroArch.PVRetroArchCoreBridge
import PVCoreBridge

class AppState: ObservableObject {
    @MainActor
    static let shared: AppState = .init()
    init() {
        
    }
    
    fileprivate weak var core: PVRetroArchCoreBridge?

    @Published var isRunning: Bool = false
    @Published var sendEventWasSwizzled: Bool = false
}

@main
struct TestRunnerApp: App {
    
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                /// Swizzle sendEvent(UIEvent)
                if !AppState.shared.sendEventWasSwizzled {
                    UIApplication.swizzleSendEvent()
                    AppState.shared.sendEventWasSwizzled = true
                }
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    var core: PVRetroArchCoreBridge? {
        didSet {
            AppState.shared.core = core
        }
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("Launching TestRunner")
        
        core = PVRetroArchCoreBridge()
        core?.setRootView(true)
        core?.startEmulation()
        
        return true
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        // Handle background events if needed
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isEmulating = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if isEmulating {
                EmulationView()
            } else {
                Text("Emulation not started")
                    .foregroundColor(.white)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                startEmulation()
            case .background:
                stopEmulation()
            default:
                break
            }
        }
    }
    
    private func startEmulation() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.core?.startEmulation()
        isEmulating = true
    }
    
    private func stopEmulation() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.core?.stopEmulation()
        isEmulating = false
    }
}

struct EmulationView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return view }
        appDelegate.core?.setRootView(true)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension PVRetroArchCoreBridge {
    func sendEvent(_ event: UIEvent) {
        // Implement this method to handle events if needed
    }
}

/// Hack to get touches send to RetroArch

extension UIApplication {

    /// Swap implipmentations of sendEvent() while
    /// maintaing a reference back to the original
    @objc static func swizzleSendEvent() {
            let originalSelector = #selector(UIApplication.sendEvent(_:))
            let swizzledSelector = #selector(UIApplication.pv_sendEvent(_:))
            let orginalStoreSelector = #selector(UIApplication.originalSendEvent(_:))
            guard let originalMethod = class_getInstanceMethod(self, originalSelector),
                let swizzledMethod = class_getInstanceMethod(self, swizzledSelector),
                  let orginalStoreMethod = class_getInstanceMethod(self, orginalStoreSelector)
            else { return }
            method_exchangeImplementations(originalMethod, orginalStoreMethod)
            method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    /// Placeholder for storing original selector
    @objc func originalSendEvent(_ event: UIEvent) { }

    /// The sendEvent that will be called
    @objc func pv_sendEvent(_ event: UIEvent) {
//        print("Handling touch event: \(event.type.rawValue ?? -1)")
        if let core = AppState.shared.core {
            core.sendEvent(event)
        }

        originalSendEvent(event)
    }
}
