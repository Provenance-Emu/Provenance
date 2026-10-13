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
//  Presets render in a worker subprocess. A GPU hang makes macOS ignore every
//  later command buffer from that process, so after any GPU error (or a crash)
//  the worker exits and a fresh one resumes with the next preset.
//
//  Usage: pvshader-validate <library-dir>
//         pvshader-validate --worker <library-dir> <start-index>   (internal)
//

import Foundation
import Metal
import PVSlangRuntime

/// Worker exit status meaning "GPU context is poisoned; restart after the last reported preset".
let gpuErrorExitStatus: Int32 = 3

/// One line of worker output: the preset at `index` and why it failed, or nil when it rendered.
struct Result: Codable {
    let index: Int
    let id: String
    let failure: String?
}

func fail(_ message: String, status: Int32) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(status)
}

func presetIDs(in library: URL) -> [String] {
    var presets: [String] = []
    if let enumerator = FileManager.default.enumerator(at: library, includingPropertiesForKeys: nil) {
        for case let url as URL in enumerator where url.lastPathComponent == "shader.json" {
            presets.append(url.deletingLastPathComponent().path.replacingOccurrences(of: library.path + "/", with: ""))
        }
    }
    return presets.sorted()
}

/// First line of an error, so compiler diagnostics stay readable in the JSON.
func summary(_ error: Error) -> String {
    let text = (error as NSError).localizedDescription
    return String(text.split(separator: "\n").first ?? Substring(text))
}

/// Renders presets from `start` on, writing one `Result` JSON line per preset to stdout.
func runWorker(library: URL, start: Int) -> Never {
    guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
        fail("error: no Metal device", status: 1)
    }
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
        fail("error: could not allocate textures", status: 1)
    }

    let presets = presetIDs(in: library)
    let encoder = JSONEncoder()
    func report(_ result: Result) {
        // Unbuffered, so the parent sees every finished preset even if the next one crashes.
        FileHandle.standardOutput.write((try? encoder.encode(result)) ?? Data())
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    for index in start ..< presets.count {
        let id = presets[index]
        FileHandle.standardError.write(Data("[\(index + 1)/\(presets.count)] \(id)\n".utf8))
        var failure: String?
        var gpuError = false
        do {
            let chain = try FilterChain(device: device)
            try chain.setCompiledShader(DirectoryCompiledShaderContainer(directory: library.appendingPathComponent(id)))
            if chain.hasShader {
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
                        failure = "GPU error: \(summary(error))"
                        gpuError = true
                        break
                    }
                }
            } else {
                failure = "did not load"
            }
        } catch {
            failure = "load failed: \(summary(error))"
        }
        report(Result(index: index, id: id, failure: failure))
        if gpuError {
            exit(gpuErrorExitStatus)
        }
    }
    exit(0)
}

/// Runs workers until every preset has a result, restarting after GPU errors and crashes.
func runParent(library: URL) -> Never {
    guard let executable = Bundle.main.executableURL else {
        fail("error: cannot locate own executable", status: 1)
    }
    let presets = presetIDs(in: library)
    var failures: [String: String] = [:]
    var next = 0
    let decoder = JSONDecoder()

    while next < presets.count {
        let worker = Process()
        worker.executableURL = executable
        worker.arguments = ["--worker", library.path, String(next)]
        let output = Pipe()
        worker.standardOutput = output
        do {
            try worker.run()
        } catch {
            fail("error: could not start worker: \(error)", status: 1)
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        worker.waitUntilExit()

        var lastIndex = next - 1
        for line in data.split(separator: UInt8(ascii: "\n")) {
            guard let result = try? decoder.decode(Result.self, from: Data(line)) else { continue }
            if let failure = result.failure {
                failures[result.id] = failure
            }
            lastIndex = result.index
        }

        switch (worker.terminationReason, worker.terminationStatus) {
        case (.exit, 0):
            next = presets.count
        case (.exit, gpuErrorExitStatus):
            next = lastIndex + 1
        default:
            // The worker died while rendering the preset after the last one it reported.
            let culprit = lastIndex + 1
            guard culprit < presets.count else {
                fail("error: worker exited with status \(worker.terminationStatus) after the last preset", status: 1)
            }
            failures[presets[culprit]] = "crashed (status \(worker.terminationStatus))"
            next = culprit + 1
        }
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    FileHandle.standardOutput.write((try? encoder.encode(failures)) ?? Data("{}".utf8))
    FileHandle.standardOutput.write(Data("\n".utf8))
    FileHandle.standardError.write(Data("\(failures.count) of \(presets.count) presets failed\n".utf8))
    exit(0)
}

let arguments = CommandLine.arguments
if arguments.count == 4, arguments[1] == "--worker", let start = Int(arguments[3]) {
    runWorker(library: URL(fileURLWithPath: arguments[2], isDirectory: true), start: start)
} else if arguments.count == 2 {
    runParent(library: URL(fileURLWithPath: arguments[1], isDirectory: true))
} else {
    fail("usage: pvshader-validate <library-dir>", status: 2)
}
