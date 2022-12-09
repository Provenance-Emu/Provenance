// Copyright (c) 2022, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

public class OEGameStartupInfo {
    
    public let romURL: URL
    public let romMD5: String
    public let romHeader: String
    public let romSerial: String
    public let systemIdentifier: String
    public let coreIdentifier: String
    public let systemRegion: String
    public let displayModeInfo: [String: Any]?
    public let shaderURL: URL
    public let shaderParameters: [String: Double]
    
    public init(romURL: URL, romMD5: String, romHeader: String, romSerial: String,
                systemIdentifier: String,
                coreIdentifier: String,
                systemRegion: String,
                displayModeInfo: [String: Any]?,
                shaderURL: URL, shaderParameters: [String: Double]) {
        self.romURL = romURL
        self.romMD5 = romMD5
        self.romHeader = romHeader
        self.romSerial = romSerial
        self.systemIdentifier = systemIdentifier
        self.coreIdentifier = coreIdentifier
        self.systemRegion = systemRegion
        self.displayModeInfo = displayModeInfo
        self.shaderURL = shaderURL
        self.shaderParameters = shaderParameters
    }
}
