//
//  ShaderManager.swift
//  Provenance
//
//  Created by Joseph Mattiello on 7/13/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation


public enum ShaderType: UInt, Codable {
    case blitter
    case filter
    case vertex
}

public struct Shader: Codable {
    let type: ShaderType
}


public protocol ShaderProvider {
    var shaders: [Shader] { get }
}

public class MetalShaderManager: ShaderProvider {

    
    public
    lazy var shaders: [Shader] = {
        return [Shader]()
    }()
    
    public
    lazy var vertexShaders: [Shader] = {
        return shaders(forType: .vertex)
    }()
    
    public
    lazy var filterShaders: [Shader] = {
        return shaders(forType: .filter)
    }()
    
    public
    lazy var blitterShaders: [Shader] = {
        return shaders(forType: .blitter)
    }()
    
    public
    var shaders(forType type: ShaderType): [Shader] {
        return shaders.filter{ $0.type == type }
    }
}
