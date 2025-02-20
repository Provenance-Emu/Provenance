//
//  WebServer.swift
//  PVRetroArch_Test
//
//  Created by Joseph Mattiello on 2/19/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import Foundation
import PVWebServer

@objc public class RetroWebServer: NSObject {
    @objc nonisolated(unsafe) public static let shared: RetroWebServer = .init()
    
    @objc public var server: PVWebServer!
    
    @objc public override init() {
        super.init()
        
        self.server = PVWebServer()
    }
    
    @objc public func start() {
        self.server.startServers()
    }
    
    @objc public func stop() {
        self.server.stopServers()
    }
}
