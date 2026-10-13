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

struct ShaderPassBufferSemantics {
    private(set) var data: UnsafeRawPointer
}

struct ShaderPassTextureSemantics {
    let texture: UnsafeRawPointer
    let stride: Int

    init(texture: UnsafeRawPointer, stride: Int) {
        self.texture = texture
        self.stride = stride
    }

    init(texture: UnsafeRawPointer) {
        self.init(texture: texture, stride: 0)
    }
}

struct ShaderPassTextureUniformSemantic {
    let size: UnsafeRawPointer
    let stride: Int

    init(size: UnsafeRawPointer, stride: Int) {
        self.size = size
        self.stride = stride
    }

    init(size: UnsafeRawPointer) {
        self.init(size: size, stride: 0)
    }
}

class ShaderPassSemantics {
    private(set) var textures: [Compiled.ShaderTextureSemantic: ShaderPassTextureSemantics] = [:]
    private(set) var textureUniforms: [Compiled.ShaderBufferSemantic: ShaderPassTextureUniformSemantic] = [:]
    private(set) var uniforms: [Compiled.ShaderBufferSemantic: ShaderPassBufferSemantics] = [:]
    private(set) var parameters: [Int: ShaderPassBufferSemantics] = [:]

    func addTexture(_ texture: UnsafeRawPointer, size: UnsafeRawPointer, semantic: Compiled.ShaderTextureSemantic) {
        textures[semantic] = .init(texture: texture)
        textureUniforms[semantic.uniformSemantic] = .init(size: size)
    }

    func addTexture(
        _ texture: UnsafeRawPointer,
        stride ts: Int,
        size: UnsafeRawPointer,
        stride ss: Int,
        semantic: Compiled.ShaderTextureSemantic
    ) {
        textures[semantic] = .init(texture: texture, stride: ts)
        textureUniforms[semantic.uniformSemantic] = .init(size: size, stride: ss)
    }

    func addUniformData(_ data: UnsafeRawPointer, semantic: Compiled.ShaderBufferSemantic) {
        uniforms[semantic] = .init(data: data)
    }

    func addUniformData(_ data: UnsafeRawPointer, forParameterAt index: Int) {
        parameters[index] = .init(data: data)
    }

    func parameter(at index: Int) -> ShaderPassBufferSemantics? {
        parameters[index]
    }
}

extension Compiled.ShaderTextureSemantic {
    /// Maps self to it's equivalent uniform semantic
    var uniformSemantic: Compiled.ShaderBufferSemantic {
        switch self {
        case .original:
            .originalSize
        case .source:
            .sourceSize
        case .originalHistory:
            .originalHistorySize
        case .passOutput:
            .passOutputSize
        case .passFeedback:
            .passFeedbackSize
        case .user:
            .userSize
        }
    }
}

enum ShaderPassScale: Equatable, Codable {
    case source(scale: CGFloat)
    case absolute(size: Int)
    case viewport(scale: CGFloat)

    init?(_ scale: Compiled.ShaderPassScale?) {
        guard let scale else {
            return nil
        }

        switch scale {
        case let .source(scale: scale):
            self = .source(scale: scale)
        case let .absolute(size: size):
            self = .absolute(size: size)
        case let .viewport(scale: scale):
            self = .viewport(scale: scale)
        }
    }
}

enum ShaderPassFilter: Int, CaseIterable {
    case unspecified, linear, nearest

    private static let fromCompiled: [Compiled.ShaderPassFilter: Self] = [
        .unspecified: .unspecified,
        .linear: .linear,
        .nearest: .nearest,
    ]

    init(_ sem: Compiled.ShaderPassFilter) {
        self = Self.fromCompiled[sem]!
    }
}

enum ShaderPassWrap: Int, CaseIterable {
    case border, edge, `repeat`, mirroredRepeat

    static let `default`: Self = .border

    private static let fromCompiled: [Compiled.ShaderPassWrap: Self] = [
        .border: .border,
        .edge: .edge,
        .repeat: .repeat,
        .mirroredRepeat: .mirroredRepeat,
    ]

    init(_ sem: Compiled.ShaderPassWrap) {
        self = Self.fromCompiled[sem]!
    }
}
