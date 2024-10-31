////
////  ObjCCoreBridge.swift
////  PVEmulatorCore
////
////  Created by Joseph Mattiello on 9/18/24.
////
//
//
//@objc public protocol ObjCCoreBridge where Self: PVEmulatorCore {
//
//    // MARK: Lifecycle
//    @objc func loadFile(atPath: String) throws
////    @objc func executeFrameSkippingFrame(skip: Bool)
//    @objc func executeFrame()
//    @objc func swapBuffers()
//    @objc func stopEmulation()
//    @objc func resetEmulation()
//    
//    // MARK: Output
//    @objc dynamic optional var screenRect: CGRect { get }
//    @objc dynamic optional var videoBuffer: UnsafeMutableRawPointer? { get }
//    @objc dynamic optional var frameInterval: TimeInterval { get }
//    @objc dynamic optional var rendersToOpenGL: Bool { get }
//    
//    // MARK: Audio
//    @objc dynamic optional var audioBufferCount: UInt { get }
//    @objc dynamic optional var audioBitDepth: UInt { get }
//
//    // MARK: Input
//    @objc dynamic optional func pollControllers()
//    
//    // MARK: Save States
//    @objc dynamic optional func saveStateToFileAtPath(fileName: String) async throws
//    @objc dynamic optional func loadStateFromFileAtPath(fileName: String) async throws
//
////    @objc func saveStateToFileAtPath(fileName: String, completionHandler block: @escaping (Bool, Error?) -> Void)
////    @objc func loadStateFromFileAtPath(fileName: String, completionHandler block: @escaping (Bool, Error?) -> Void)
//}
