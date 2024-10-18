// Copyright 2021 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

import Foundation

// Basically the same concept from C#.
@objc public final class DOLCancellationToken : NSObject {
    private var cancelled: Bool
    
    public
    override init() {
        cancelled = false
    }
    
    @objc public func isCancelled() -> Bool {
        return cancelled;
    }
    
    @objc public func cancel() {
        cancelled = true;
    }
}
