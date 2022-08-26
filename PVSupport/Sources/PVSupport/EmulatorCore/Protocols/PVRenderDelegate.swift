//
//  PVRenderDelegate.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/25/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

@objc
public protocol PVRenderDelegate: AnyObject {
    func startRenderingOnAlternateThread()
    func didRenderFrameOnAlternateThread()
}
