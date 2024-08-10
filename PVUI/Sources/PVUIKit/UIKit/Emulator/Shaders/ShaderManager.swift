//
//  ShaderManager.swift
//  Provenance
//
//  Created by Joseph Mattiello on 7/13/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

@objc
public enum ShaderType: UInt, Codable {
    case blitter
    case filter
    case vertex
}

@objc
public final class Shader: NSObject, Codable {

    @objc
    let type: ShaderType

    @objc
    let name: String

    @objc
    let function: String

    @objc
    public init(type: ShaderType, name: String, function: String) {
        self.type = type
        self.name = name
        self.function = function
    }
}

public protocol ShaderProvider {
    var shaders: [Shader] { get }
}

@objc
public final class MetalShaderManager: NSObject, ShaderProvider {

    @objc(sharedInstance)
    static let shared: MetalShaderManager = MetalShaderManager()

    @objc
    public var shaders: [Shader] = {
        let shaders: [Shader] = [
            .init(type: .vertex, name: "Fullscreen", function: "fullscreen_vs"),
            .init(type: .blitter, name: "Blitter", function: "blit_ps"),
            .init(type: .filter, name: "CRT", function: "crt_filter_ps"),
            .init(type: .filter, name: "Simple CRT", function: "simpleCRT")
        ]
        return shaders
    }()

    @objc public
    lazy var vertexShaders: [Shader] = {
        return shaders(forType: .vertex)
    }()

    @objc public
    lazy var filterShaders: [Shader] = {
        return shaders(forType: .filter)
    }()

    @objc public
    lazy var blitterShaders: [Shader] = {
        return shaders(forType: .blitter)
    }()

    @objc
    public func filterShader(forName name: String) -> Shader? {
        return filterShaders.first(where: { $0.name == name })
    }

    private
    func shaders(forType type: ShaderType) -> [Shader] {
        return shaders.filter { $0.type == type }
    }
}
