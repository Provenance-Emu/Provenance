//
//  main.swift
//  pvshader-validate
//
//  Loads every preset in an unpacked slang library (see
//  Scripts/shaders/fetch_slang_shaders.py) through the runtime and renders one
//  frame on the host GPU. Prints a JSON object of `{presetID: reason}` for the
//  presets that fail, which Scripts/shaders/validate_slang_shaders.sh stores
//  as Scripts/shaders/slang-shaders-excluded.json.
//
//  Usage: pvshader-validate <library-dir>
//

import Foundation
import Metal
import PVSlangRuntime

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: pvshader-validate <library-dir>\n".utf8))
    exit(2)
}
guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
    FileHandle.standardError.write(Data("error: no Metal device\n".utf8))
    exit(1)
}

let library = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let sourceSize = 256
let targetSize = 640

func makeTexture(_ size: Int, usage: MTLTextureUsage) -> MTLTexture? {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .bgra8Unorm, width: size, height: size * 3 / 4, mipmapped: false)
    descriptor.usage = usage
    descriptor.storageMode = .private
    return device.makeTexture(descriptor: descriptor)
}

guard let source = makeTexture(sourceSize, usage: [.shaderRead]),
      let target = makeTexture(targetSize, usage: [.renderTarget, .shaderRead]) else {
    FileHandle.standardError.write(Data("error: could not allocate textures\n".utf8))
    exit(1)
}

var presets: [String] = []
if let enumerator = FileManager.default.enumerator(at: library, includingPropertiesForKeys: nil) {
    for case let url as URL in enumerator where url.lastPathComponent == "shader.json" {
        let id = url.deletingLastPathComponent().path.replacingOccurrences(of: library.path + "/", with: "")
        presets.append(id)
    }
}
presets.sort()

var failures: [String: String] = [:]

/// First line of an error, so compiler diagnostics stay readable in the JSON.
func summary(_ error: Error) -> String {
    let text = (error as NSError).localizedDescription
    return String(text.split(separator: "\n").first ?? Substring(text))
}
for (number, id) in presets.enumerated() {
    FileHandle.standardError.write(Data("[\(number + 1)/\(presets.count)] \(id)\n".utf8))
    do {
        let chain = try FilterChain(device: device)
        try chain.setCompiledShader(DirectoryCompiledShaderContainer(directory: library.appendingPathComponent(id)))
        guard chain.hasShader else {
            failures[id] = "did not load"
            continue
        }
        chain.drawableSize = CGSize(width: target.width, height: target.height)
        chain.setSourceRect(CGRect(x: 0, y: 0, width: source.width, height: source.height),
                            aspect: CGSize(width: 4, height: 3))
        // Two frames, so history and feedback paths run once with populated state.
        for _ in 0 ..< 2 {
            guard let commandBuffer = queue.makeCommandBuffer() else { break }
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = target
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            chain.render(sourceTexture: source, commandBuffer: commandBuffer, renderPassDescriptor: pass)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            if let error = commandBuffer.error {
                failures[id] = "GPU error: \(summary(error))"
                break
            }
        }
    } catch {
        failures[id] = "load failed: \(summary(error))"
    }
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
FileHandle.standardOutput.write(try encoder.encode(failures))
FileHandle.standardOutput.write(Data("\n".utf8))
FileHandle.standardError.write(Data("\(failures.count) of \(presets.count) presets failed\n".utf8))
