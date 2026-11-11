#if OVERLAY_SNAPSHOT_HARNESS && os(iOS)
import PVSettings
import PVSystems
import SkinKit2Core
import SkinKit2Render
import SwiftUI
import UIKit
import XCTest
@testable import PVTouchOverlay

final class OverlayIdleSnapshotTests: XCTestCase {
    @MainActor
    func testIdleArt() throws {
        let output = URL(fileURLWithPath: snapshotOutput, isDirectory: true)
        let style = try XCTUnwrap(OverlayStyle(rawValue: snapshotStyle))
        let theme = style == .flat ? nil : style.rawValue
        let baselineOnly = snapshotCandidates.isEmpty
        let candidates = URL(fileURLWithPath: snapshotCandidates, isDirectory: true)
        var rows = ["system,subtype,profile,status,pixels,legacyInk,candidateInk,changed,changedAbove8,inkUnion,meanMaxDelta,maxDelta"]
        for system in SystemOverlayBindings.boundSystems.sorted(by: { $0.rawValue < $1.rawValue }) {
            let binding = try XCTUnwrap(SystemOverlayBindings.binding(for: system))
            let candidateDir = candidates.appendingPathComponent(system.rawValue)
            for subtype in binding.families.keys.sorted() {
                let directory = output.appendingPathComponent(system.rawValue).appendingPathComponent(subtype)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                var candidate: Skin2Document?
                var status = baselineOnly ? "baseline" : "missing"
                if !baselineOnly {
                    do {
                        let source = candidateDir.appendingPathComponent("skin.json")
                        if FileManager.default.fileExists(atPath: source.path) {
                            candidate = try Skin2Document.load(data: Data(contentsOf: source), theme: theme,
                                                               variant: subtype == binding.defaultSubtype ? nil : subtype)
                            status = "compared"
                        } else {
                            XCTFail("Missing candidate \(source.path)")
                        }
                    } catch {
                        status = "invalid"
                        XCTFail("\(system.rawValue)/\(subtype): \(error)")
                    }
                }
                let pad = OverlayPadKind(system: system, subtype: subtype)
                for profile in Skin2TraitSet.all {
                    try autoreleasepool {
                        let size = CGSize(width: profile.size.width, height: profile.size.height)
                        let insets = profile.safeArea
                        let canvas = OverlayCanvas(size: size, safeArea: OverlayInsets(top: insets.top, left: insets.left,
                                                                                       bottom: insets.bottom, right: insets.right))
                        let orientation: OverlayOrientation = profile.orientation == .portrait ? .portrait : .landscape
                        let template = binding.template(padKind: pad, orientation: orientation)
                        let layout = OverlayLayoutEngine.resolve(template: template, canvas: canvas, overrides: .empty, gameAspect: 4.0 / 3.0)
                        let prefix = "\(system.rawValue),\(subtype),\(profile.name),\(status)"
                        let base = directory.appendingPathComponent(profile.name)
                        let legacyURL = base.appendingPathExtension("legacy.png")
                        let legacy: CGImage
                        if snapshotBaseline.isEmpty {
                            legacy = try snapshot(IdleOverlayArt(layout: layout, palette: binding.palette, style: style), size: size)
                            try write(legacy, to: legacyURL)
                        } else {
                            let baselineURL = URL(fileURLWithPath: snapshotBaseline, isDirectory: true)
                                .appendingPathComponent(system.rawValue).appendingPathComponent(subtype)
                                .appendingPathComponent(profile.name).appendingPathExtension("legacy.png")
                            let data = try Data(contentsOf: baselineURL)
                            legacy = try XCTUnwrap(UIImage(data: data)?.cgImage, baselineURL.path)
                            try data.write(to: legacyURL)
                        }
                        XCTAssertEqual(legacy.width, Int(size.width * 2), prefix)
                        XCTAssertEqual(legacy.height, Int(size.height * 2), prefix)
                        let baseline = try rgba(legacy)
                        let legacyInk = baseline.indices.strideByFour.count { baseline[$0 + 3] != 0 }
                        _ = try XCTUnwrap(legacyInk > 0 ? true : nil, "Blank legacy capture for \(prefix)")
                        if let candidate {
                            let resolution = Skin2Resolver.resolve(candidate, in: profile.environment)
                            let options = Skin2RenderOptions(asset: { path in
                                try? Data(contentsOf: candidateDir.appendingPathComponent("assets").appendingPathComponent(path))
                            })
                            let image = try XCTUnwrap(Skin2Renderer.image(resolution, scale: 2, options: options), prefix)
                            try write(image, to: base.appendingPathExtension("candidate.png"))
                            let comparison = try compare(baseline, image: image)
                            XCTAssertGreaterThan(comparison.candidateInk, 0, "Blank candidate for \(prefix)")
                            rows.append("\(prefix),\(image.width * image.height),\(legacyInk),\(comparison.csv)")
                        } else {
                            rows.append("\(prefix),\(legacy.width * legacy.height),\(legacyInk),,,,,,")
                        }
                    }
                }
            }
        }
        try (style.rawValue + "\n").write(to: output.appendingPathComponent("style.txt"), atomically: true, encoding: .utf8)
        try (rows.joined(separator: "\n") + "\n").write(to: output.appendingPathComponent("pixels.csv"), atomically: true, encoding: .utf8)
    }

    @MainActor
    private func snapshot(_ view: some View, size: CGSize) throws -> CGImage {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .light)
            .environment(\.displayScale, 2))
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 2
        return try XCTUnwrap(renderer.cgImage)
    }

    private func write(_ image: CGImage, to url: URL) throws {
        try XCTUnwrap(UIImage(cgImage: image).pngData()).write(to: url)
    }

    // Normalize both captures to premultiplied sRGB RGBA8 before comparing.
    private func rgba(_ image: CGImage) throws -> [UInt8] {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                                  bytesPerRow: width * 4, space: colorSpace,
                                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setBlendMode(.copy)
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return bytes
    }

    private struct Comparison {
        var candidateInk = 0
        var changed = 0
        var changedAbove8 = 0
        var inkUnion = 0
        var total = 0
        var maxDelta = 0
        var csv = ""
    }

    private func compare(_ baseline: [UInt8], image: CGImage) throws -> Comparison {
        let candidate = try rgba(image)
        _ = try XCTUnwrap(baseline.count == candidate.count ? true : nil, "Candidate and legacy pixel counts differ")
        var result = Comparison()
        for offset in candidate.indices.strideByFour {
            let candidateHasInk = candidate[offset + 3] != 0
            if candidateHasInk { result.candidateInk += 1 }
            if candidateHasInk || baseline[offset + 3] != 0 { result.inkUnion += 1 }
            let delta = (offset..<(offset + 4)).reduce(0) { max($0, abs(Int(baseline[$1]) - Int(candidate[$1]))) }
            if delta > 0 { result.changed += 1 }
            if delta > 8 { result.changedAbove8 += 1 }
            result.total += delta
            result.maxDelta = max(result.maxDelta, delta)
        }
        let mean = Double(result.total) / Double(candidate.count / 4)
        result.csv = "\(result.candidateInk),\(result.changed),\(result.changedAbove8),\(result.inkUnion),\(mean),\(result.maxDelta)"
        return result
    }
}

private extension Range where Bound == Int {
    var strideByFour: StrideTo<Int> { stride(from: lowerBound, to: upperBound, by: 4) }
}

/// The static layers of OverlayHostView and OverlayGroupView. ImageRenderer puts visible
/// placeholders where their transparent UIKit touch views would otherwise be.
private struct IdleOverlayArt: View {
    let layout: OverlayLayout
    let palette: OverlayPalette
    let style: OverlayStyle

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.groups) { group in
                if !isTouchSurface(group) {
                    ZStack(alignment: .topLeading) {
                        ForEach(group.controls) { control in
                            artwork(control.control)
                                .frame(width: control.frame.width, height: control.frame.height)
                                .offset(x: control.frame.minX - group.frame.minX, y: control.frame.minY - group.frame.minY)
                        }
                    }
                    .frame(width: group.frame.width, height: group.frame.height, alignment: .topLeading)
                    .opacity(group.opacity)
                    .offset(x: group.frame.minX, y: group.frame.minY)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
    }

    private func isTouchSurface(_ group: ResolvedGroup) -> Bool {
        group.controls.contains {
            if case .touchSurface = $0.control.kind { return true }
            return false
        }
    }

    @ViewBuilder
    private func artwork(_ control: OverlayControl) -> some View {
        let spec = OverlayArtSpec(shape: control.shape, color: palette.color(for: control.paletteSlot), labelColor: palette.label,
                                  style: style, pressed: false, label: control.label)
        if case .stick = control.kind {
            OverlayStickArt(spec: spec, knob: OverlayKnobState(), axis: control.axis)
        } else {
            OverlayControlArt(spec: spec)
        }
    }
}
#endif
