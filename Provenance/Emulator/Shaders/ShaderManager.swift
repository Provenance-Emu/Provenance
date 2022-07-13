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

public class ShaderManager: ShaderProvider {
    public enum Mode: String, Codable {
        case metal
        case gles
        
        var directory: String {
            switch self {
            case .metal: return "Metal"
            case .gles: return "GLES"
            }
        }
    }
    
    public var mode: Mode = .metal
    
    public
    var shaders: [Shader] {
        return [Shader]()
    }
    
    // MARK: - Directories
    lazy var shadersPath: URL = {
        let typeDir: String = mode.directory
        return Bundle(for: type(of: self)).resourceURL!.appendingPathComponent("/Shaders/\(typeDir)")
    }()
    
    lazy var blittersPath: URL = {
        return shadersPath.appendingPathComponent("/Blitters")
    }()

    lazy var filtersPath: URL = {
        return shadersPath.appendingPathComponent("/Filters")
    }()

    lazy var vertexPath: URL = {
        return shadersPath.appendingPathComponent("/Vertex")
    }()
}
