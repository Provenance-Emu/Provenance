// Copyright (c) 2019, OpenEmu Team
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

public final class ShaderParameter: CustomStringConvertible, Codable {
    public var name: String
    public var desc: String
    public var initial: Decimal = 0.0
    public var minimum: Decimal = 0.0
    public var maximum: Decimal = 1.0
    public var step: Decimal = 0.01

    public init(name: String, desc: String) {
        self.name = name
        self.desc = desc
    }

    public var description: String {
        "\(desc) (\(initial))"
    }

    public var initialFloat: CGFloat {
        (initial as NSDecimalNumber).doubleValue.isFinite ? CGFloat(truncating: initial as NSDecimalNumber) : 0
    }

    public var minFloat: CGFloat {
        (minimum as NSDecimalNumber).doubleValue.isFinite ? CGFloat(truncating: minimum as NSDecimalNumber) : 0
    }

    public var maxFloat: CGFloat {
        (maximum as NSDecimalNumber).doubleValue.isFinite ? CGFloat(truncating: maximum as NSDecimalNumber) : 1
    }

    public var stepFloat: CGFloat {
        (step as NSDecimalNumber).doubleValue.isFinite ? CGFloat(truncating: step as NSDecimalNumber) : 0.01
    }
}

extension ShaderParameter: Equatable {
    public static func == (lhs: ShaderParameter, rhs: ShaderParameter) -> Bool {
        lhs.name == rhs.name &&
            lhs.desc == rhs.desc &&
            lhs.initial == rhs.initial &&
            lhs.minimum == rhs.minimum &&
            lhs.maximum == rhs.maximum &&
            lhs.step == rhs.step
    }
}
