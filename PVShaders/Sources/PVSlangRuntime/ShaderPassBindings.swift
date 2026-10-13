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

class ShaderPassUniformBinding: CustomDebugStringConvertible {
    let data: UnsafeRawPointer
    let size: Int
    let offset: Int
    let name: String

    init(data: UnsafeRawPointer, size: Int, offset: Int, name: String) {
        self.data = data
        self.size = size
        self.offset = offset
        self.name = name
    }

    var debugDescription: String {
        "\(name) size=\(size), offset=\(offset), data=\(data)"
    }
}

class ShaderPassBufferBinding {
    var bindingVert: Int?
    var bindingFrag: Int?
    var size: Int = 0
    var uniforms: [ShaderPassUniformBinding] = []

    @discardableResult
    func addUniformData(_ data: UnsafeRawPointer, size: Int, offset: Int, name: String) -> ShaderPassUniformBinding {
        let u = ShaderPassUniformBinding(data: data, size: size, offset: offset, name: name)
        uniforms.append(u)
        return u
    }
}

class ShaderPassTextureBinding {
    let texture: UnsafeRawPointer
    let binding: Int
    let name: String
    var wrap: ShaderPassWrap = .default
    var filter: ShaderPassFilter = .nearest

    init(texture: UnsafeRawPointer, binding: Int, name: String) {
        self.texture = texture
        self.binding = binding
        self.name = name
    }
}

class ShaderPassBindings {
    private(set) var buffers = [ShaderPassBufferBinding(),
                                ShaderPassBufferBinding()] // equivalent to Constants.maxConstantBuffers
    private(set) var textures: [ShaderPassTextureBinding] = []

    func addTexture(_ texture: UnsafeRawPointer, binding: Int, name: String) -> ShaderPassTextureBinding {
        let t = ShaderPassTextureBinding(texture: texture, binding: binding, name: name)
        textures.append(t)
        return t
    }

    func sort() {
        textures.sort { l, r in
            l.binding < r.binding
        }
        buffers[0].uniforms.sort { l, r in
            l.offset < r.offset
        }
        buffers[1].uniforms.sort { l, r in
            l.offset < r.offset
        }
    }
}
