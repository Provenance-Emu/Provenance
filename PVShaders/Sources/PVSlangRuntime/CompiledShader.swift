//
//  CompiledShader.swift
//  OpenEmuShaders
//
//  Created by Stuart Carnie on 5/14/20.
//  Copyright © 2022 OpenEmu. All rights reserved.
//

import Foundation
import Metal

public enum Compiled: Sendable {
    /// Shader is the root object of a compiled shader.
    public struct Shader: Codable, Sendable {
        public let passes: [ShaderPass]
        public let parameters: [Parameter]
        public let luts: [LUT]
        public let historyCount: Int
        public let languageVersion: LanguageVersion
    }

    public struct LUT: Codable, Sendable {
        public let url: URL
        public let name: String
        public let filter: ShaderPassFilter
        public let wrapMode: ShaderPassWrap
        public let isMipmap: Bool
    }

    public struct Parameter: Codable, Sendable {
        public let index: Int
        public let name: String
        public let desc: String
        public let initial: Decimal
        public let minimum: Decimal
        public let maximum: Decimal
        public let step: Decimal

        // swiftformat:disable consecutiveSpaces redundantSelf
        init(index: Int, source p: ShaderParameter) {
            self.index   = index
            self.name    = p.name
            self.desc    = p.desc
            self.initial = p.initial
            self.minimum = p.minimum
            self.maximum = p.maximum
            self.step    = p.step
        }
        // swiftformat:enable all
    }

    public struct ShaderPass: Codable, Sendable {
        public let index: Int
        public let vertexSource: String
        public let fragmentSource: String
        public let frameCountMod: UInt
        public let scaleX: ShaderPassScale?
        public let scaleY: ShaderPassScale?
        public let filter: ShaderPassFilter
        public let wrapMode: ShaderPassWrap
        public let format: PixelFormat
        public internal(set) var isFeedback: Bool
        public let buffers: [BufferDescriptor]
        public let textures: [TextureDescriptor]
        public let alias: String?
    }

    /// An object that describes how to organize and map data
    /// to a shader pass buffer.
    public struct BufferDescriptor: Codable, Sendable {
        public let bindingVert: Int?
        public let bindingFrag: Int?
        public let size: Int
        public let uniforms: [BufferUniformDescriptor]
    }

    /// An object that describes how to store uniform data in memory
    /// and map it to the arguments of a shader pass.
    public struct BufferUniformDescriptor: Codable, Sendable {
        /// public let name: String
        public let semantic: ShaderBufferSemantic
        /// An optional index if the uniform is an array
        public let index: Int?
        public let name: String
        public let size: Int
        public let offset: Int
    }

    public struct TextureDescriptor: Codable, Sendable {
        public let name: String
        public let semantic: ShaderTextureSemantic
        public let binding: Int
        public let wrap: ShaderPassWrap
        public let filter: ShaderPassFilter
        public let index: Int
    }

    // MARK: - Enumerations

    enum LanguageVersionError: Error, Sendable {
        case unsupportedVersion
    }

    public enum LanguageVersion: String, CaseIterable, Codable, Sendable {
        // swiftlint:disable:next identifier_name
        case version2_4, version2_3, version2_2, version2_1

        init(_ mtl: MTLLanguageVersion) throws {
            switch mtl {
            #if swift(>=5.9)
                case .version3_1:
                    self = .version2_4
            #endif
            case .version3_0:
                self = .version2_4
            case .version2_4:
                self = .version2_4
            case .version2_3:
                self = .version2_3
            case .version2_2:
                self = .version2_2
            case .version2_1:
                self = .version2_1
            default:
                if ((3 << 16) ..< (4 << 16)).contains(mtl.rawValue) {
                    self = .version2_4
                } else {
                    throw LanguageVersionError.unsupportedVersion
                }
            }
        }
    }

    public enum ShaderPassScale: Equatable, Codable, Sendable {
        case source(scale: CGFloat)
        case absolute(size: Int)
        case viewport(scale: CGFloat)
    }

    public enum ShaderPassFilter: String, CaseIterable, Codable, Sendable {
        case unspecified, linear, nearest
    }

    public enum ShaderPassWrap: String, CaseIterable, Codable, Sendable {
        case border, edge, `repeat`, mirroredRepeat
    }

    public enum ShaderTextureSemantic: String, CaseIterable, Codable, CustomStringConvertible, Sendable {
        /// Identifies the input texture to the filter chain.
        ///
        /// Shaders refer to the input texture via the `Original` symbol.
        case original

        /// Identifies the output texture from the previous pass.
        ///
        /// Shaders can refer to the previous source texture via
        /// the `Source` symbol.
        ///
        /// - Note: If the filter chain is executing the first pass, this is the same as
        /// `Original`.
        case source

        /// Identifies the historical input textures.
        ///
        /// Shaders can refer to the history textures via the
        /// `OriginalHistoryN` symbols, where `N`
        /// specifies the number of `Original` frames back to read.
        ///
        /// - Note: To read 2 frames prior, use `OriginalHistory2`.
        case originalHistory

        /// Identifies the pass output textures.
        ///
        /// Shaders can refer to the output of prior passes via the
        /// `PassOutputN` symbols, where `N` specifies the
        /// pass number.
        ///
        /// - NOTE: In pass 5, sampling the output of pass 2
        /// would use `PassOutput2`.
        case passOutput

        /// Identifies the pass feedback textures.
        ///
        /// Shaders can refer to the output of the previous
        /// frame of pass `N` via the `PassFeedbackN`
        /// symbols, where `N` specifies the pass number.
        ///
        /// - NOTE: To sample the output of pass 2 from the prior frame,
        /// use `PassFeedback2`.
        case passFeedback

        /// Identifies the lookup or user textures.
        ///
        /// Shaders refer to user lookup or user textures by name as defined
        /// in the `.slangp` file.
        case user

        public var description: String {
            switch self {
            case .original:
                "Original"
            case .source:
                "Source"
            case .originalHistory:
                "OriginalHistory"
            case .passOutput:
                "PassOutput"
            case .passFeedback:
                "PassFeedback"
            case .user:
                "User"
            }
        }
    }

    public enum ShaderBufferSemantic: String, CaseIterable, Codable, CustomStringConvertible, Sendable {
        /// Identifies the 4x4 float model-view-projection matrix buffer.
        ///
        /// Shaders refer to the matrix constant via the `MVP` symbol.
        ///
        case mvp

        /// Identifies the vec4 float containing the viewport size of the current pass.
        ///
        /// Shaders refer to the viewport size constant via the `OutputSize` symbol.
        ///
        /// - NOTE: The `x` and `y` fields refer to the size of the output in pixels.
        /// The `z` and `w` fields refer to the inverse; `1/x` and `1/y`.
        case outputSize

        /// Identifies the vec4 float containing the final viewport output size.
        ///
        /// Shaders refer to the final output size constant via the `FinalViewportSize` symbol.
        ///
        /// - NOTE: The `x` and `y` fields refer to the size of the output in pixels.
        /// The `z` and `w` fields refer to the inverse; `1/x` and `1/y`.
        case finalViewportSize

        /// Identifies the uint containing the frame count.
        ///
        /// Shaders refer to the frame count constant via the `FrameCount` symbol.
        ///
        /// - NOTE: This value increments by one each frame.
        case frameCount

        /// Identifies the int containing the frame direction; 1 is forward, -1 is backwards.
        ///
        /// Shaders refer to the frame direction constant via the `FrameDirection` symbol.
        case frameDirection

        /// Identifies a float parameter buffer.
        ///
        /// Shaders refer to float parameters by name.
        case floatParameter

        /// Identifies the input texture size to the filter chain.
        ///
        /// Shaders refer to the input texture size via the `OriginalSize` symbol.
        case originalSize

        /// Identifies the output texture size from the previous pass.
        ///
        /// Shaders can refer to the previous source texture size via
        /// the `SourceSize` symbol.
        ///
        /// - Note: If the filter chain is executing the first pass, this is the same as
        /// `OriginalSize`.
        case sourceSize

        /// Identifies the historical input texture sizes.
        ///
        /// Shaders can refer to the history texture sizes via the
        /// `OriginalSizeN` symbols, where `N`
        /// specifies the number of frames back to read.
        ///
        /// - Note: To read 2 frames prior, use `OriginalHistorySize2`.
        case originalHistorySize

        /// Identifies the pass output texture sizes.
        ///
        /// Shaders can refer to the output texture sizes of prior passes via the
        /// `PassOutputSizeN` symbols, where `N` specifies the
        /// pass number.
        ///
        /// - NOTE: In pass 5, sampling the output of pass 2
        /// would use `PassOutputSize2`.
        case passOutputSize

        /// Identifies the pass feedback texture sizes.
        ///
        /// Shaders can refer to the output of the previous
        /// frame of pass `N` via the `PassFeedbackSizeN`
        /// symbols, where `N` specifies the pass number.
        ///
        /// - NOTE: To sample the output of pass 2 from the prior frame,
        /// use `PassFeedbackSize2`.
        case passFeedbackSize

        /// Identifies the lookup or user texture sizes.
        ///
        /// Shaders refer to user lookup or user textures by name as defined
        /// in the `.slangp` file.
        case userSize

        public var description: String {
            switch self {
            case .mvp:
                "MVP"
            case .outputSize:
                "OutputSize"
            case .finalViewportSize:
                "FinalViewportSize"
            case .frameCount:
                "FrameCount"
            case .frameDirection:
                "FrameDirection"
            case .floatParameter:
                "FloatParameter"
            case .originalSize:
                "OriginalSize"
            case .sourceSize:
                "SourceSize"
            case .originalHistorySize:
                "OriginalHistorySize"
            case .passOutputSize:
                "PassOutputSize"
            case .passFeedbackSize:
                "PassFeedbackSize"
            case .userSize:
                "UserSize"
            }
        }
    }

    enum PixelFormatError: Error {
        case invalidFormat(val: MTLPixelFormat)
    }

    public enum PixelFormat: String, Codable, Sendable {
        case r8Unorm
        case r8Uint
        case r8Sint
        case rg8Unorm
        case rg8Uint
        case rg8Sint
        case rgba8Unorm
        case rgba8Uint
        case rgba8Sint
        case rgba8Unorm_srgb // swiftlint:disable:this identifier_name
        case rgb10a2Unorm
        case rgb10a2Uint
        case r16Uint
        case r16Sint
        case r16Float
        case rg16Uint
        case rg16Sint
        case rg16Float
        case rgba16Uint
        case rgba16Sint
        case rgba16Float
        case r32Uint
        case r32Sint
        case r32Float
        case rg32Uint
        case rg32Sint
        case rg32Float
        case rgba32Uint
        case rgba32Sint
        case rgba32Float
        case bgra8Unorm_srgb // swiftlint:disable:this identifier_name
        case bgra8Unorm

        // swiftlint:disable cyclomatic_complexity
        /// Converts a GL Slang format string to PixelFormat
        init?(glslangFormat str: String) {
            switch str {
            case "R8_UNORM":
                self = .r8Unorm
            case "R8_UINT":
                self = .r8Uint
            case "R8_SINT":
                self = .r8Sint
            case "R8G8_UNORM":
                self = .rg8Unorm
            case "R8G8_UINT":
                self = .rg8Uint
            case "R8G8_SINT":
                self = .rg8Sint
            case "R8G8B8A8_UNORM":
                self = .rgba8Unorm
            case "R8G8B8A8_UINT":
                self = .rgba8Uint
            case "R8G8B8A8_SINT":
                self = .rgba8Sint
            case "R8G8B8A8_SRGB":
                self = .rgba8Unorm_srgb
            case "A2B10G10R10_UNORM_PACK32":
                self = .rgb10a2Unorm
            case "A2B10G10R10_UINT_PACK32":
                self = .rgb10a2Uint
            case "R16_UINT":
                self = .r16Uint
            case "R16_SINT":
                self = .r16Sint
            case "R16_SFLOAT":
                self = .r16Float
            case "R16G16_UINT":
                self = .rg16Uint
            case "R16G16_SINT":
                self = .rg16Sint
            case "R16G16_SFLOAT":
                self = .rg16Float
            case "R16G16B16A16_UINT":
                self = .rgba16Uint
            case "R16G16B16A16_SINT":
                self = .rgba16Sint
            case "R16G16B16A16_SFLOAT":
                self = .rgba16Float
            case "R32_UINT":
                self = .r32Uint
            case "R32_SINT":
                self = .r32Sint
            case "R32_SFLOAT":
                self = .r32Float
            case "R32G32_UINT":
                self = .rg32Uint
            case "R32G32_SINT":
                self = .rg32Sint
            case "R32G32_SFLOAT":
                self = .rg32Float
            case "R32G32B32A32_UINT":
                self = .rgba32Uint
            case "R32G32B32A32_SINT":
                self = .rgba32Sint
            case "R32G32B32A32_SFLOAT":
                self = .rgba32Float
            default:
                return nil
            }
        }
    }
}
