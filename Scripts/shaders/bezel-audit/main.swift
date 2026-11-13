import Foundation
import CoreGraphics
import ImageIO
import Metal
import PVSlangRuntime

let library = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
func texture(_ w: Int, _ h: Int, _ usage: MTLTextureUsage) -> MTLTexture {
    let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
    d.usage = usage
    d.storageMode = .shared
    return device.makeTexture(descriptor: d)!
}
let id = CommandLine.arguments[3]
let sourceWidth = CommandLine.arguments.count > 5 ? Int(CommandLine.arguments[4]) ?? 320 : 320
let sourceHeight = CommandLine.arguments.count > 5 ? Int(CommandLine.arguments[5]) ?? 240 : 240
guard sourceWidth > 8, sourceHeight > 8, sourceWidth <= 2048, sourceHeight <= 2048 else { exit(2) }
let source = texture(sourceWidth, sourceHeight, .shaderRead)
let pixels: [UInt32] = (0..<(sourceWidth * sourceHeight)).map { index in
    let colors: [UInt32] = [0xfff7f7f7, 0xffe0ca35, 0xff47bbd3, 0xff42ba52, 0xffc758b0, 0xffcd4841, 0xff3447b2]
    let x = index % sourceWidth
    let y = index / sourceWidth
    if x < 4 || x >= sourceWidth - 4 || y < 4 || y >= sourceHeight - 4 { return 0xffffffff }
    if y >= sourceHeight * 3 / 4 { return (x / 8 + y / 8).isMultiple(of: 2) ? 0xff777777 : 0xff222222 }
    return colors[x * colors.count / sourceWidth]
}
pixels.withUnsafeBytes {
    source.replace(region: MTLRegionMake2D(0, 0, sourceWidth, sourceHeight), mipmapLevel: 0,
                   withBytes: $0.baseAddress!, bytesPerRow: sourceWidth * 4)
}
let chain = try FilterChain(device: device)
try chain.setCompiledShader(DirectoryCompiledShaderContainer(directory: library.appendingPathComponent(id)))
let sizes = [(640, 360), (480, 360), (1920, 1080)]
for (w, h) in sizes {
    let target = texture(w, h, [.renderTarget, .shaderRead])
    chain.drawableSize = CGSize(width: w, height: h)
    chain.setSourceRect(CGRect(x: 0, y: 0, width: sourceWidth, height: sourceHeight), aspect: CGSize(width: w, height: h))
    var timings: [Double] = []
    for frame in 0..<16 {
        let cb = queue.makeCommandBuffer()!
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        chain.render(sourceTexture: source, commandBuffer: cb, renderPassDescriptor: pass)
        cb.commit()
        cb.waitUntilCompleted()
        if let error = cb.error { throw error }
        if frame >= 13 { timings.append((cb.gpuEndTime - cb.gpuStartTime) * 1000) }
    }
    var bytes = [UInt8](repeating: 0, count: w * h * 4)
    target.getBytes(&bytes, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
    let context = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    let name = id.replacingOccurrences(of: "/", with: "__") + "-\(w).png"
    let dest = CGImageDestinationCreateWithURL(output.appendingPathComponent(name) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(dest) else { exit(2) }
    print("\(id)\t\(w)\t\(timings.sorted()[1])")
}
