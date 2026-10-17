// Offline artwork tool. No renderer runs in the Top Shelf extension.
// xcrun swiftc -O -target arm64-apple-macos26.0 tools/TopShelf/render-quiet-aurora.swift -o /tmp/render-quiet-aurora
// /tmp/render-quiet-aurora /absolute/path/to/Driftly [--stills-only]
import AVFoundation
import CoreGraphics
import ImageIO
import Metal
import UniformTypeIdentifiers
import VideoToolbox

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let device = MTLCreateSystemDefaultDevice()!
let queue = device.makeCommandQueue()!
let shader = """
#include <metal_stdlib>
using namespace metal;
struct Parameters { uint width; uint height; float phase; float aspect; };
float gaussian(float value, float width) { return exp(-0.5 * value * value / (width * width)); }
float3 auroraColor(float2 uv, constant Parameters &p) {
    // Preserve the proportions of the flowing sheets in each independent crop.
    float x = (uv.x - 0.5) * p.aspect / 1.7777778 + 0.5;
    float t = p.phase * 6.28318530718;
    float drift = 0.032 * sin(t);
    float bend = 0.018 * (cos(t) - 1.0);
    float u = x + drift;
    float a = 0.32 + 0.115 * sin(u * 5.4 - 0.6) + bend * sin(u * 4.0);
    float b = 0.34 + 0.150 * sin(u * 4.7 + 1.7) - bend * cos(u * 3.0);
    float c = 0.27 + 0.110 * sin(u * 4.3 + 3.6) + bend;
    // Gaussian cross sections are the offline equivalent of Aurora Veil's
    // blurred translucent bands; curved centers echo Glass Tides' sheets.
    float cyan = gaussian(uv.y - a, 0.055) * gaussian(u - 0.26, 0.36);
    float violet = gaussian(uv.y - b, 0.070) * gaussian(u - 0.72, 0.39);
    float blue = gaussian(uv.y - c, 0.080) * gaussian(u - 0.48, 0.48);
    float haze = gaussian(uv.y - 0.30, 0.27);
    float3 color = mix(float3(0.023, 0.035, 0.095), float3(0.047, 0.042, 0.137), 1.0 - uv.y);
    color += haze * float3(0.006, 0.012, 0.036);
    color += cyan * float3(0.035, 0.330, 0.390);
    color += violet * float3(0.205, 0.075, 0.360);
    color += blue * float3(0.025, 0.095, 0.230);
    color += cyan * violet * float3(0.180, 0.012, 0.065);
    // Keep the Dock / system action region quiet. No opacity or light pulsing.
    float quiet = 1.0 - 0.60 * smoothstep(0.52, 0.94, uv.y);
    color *= quiet * (1.0 - 0.12 * pow(abs(uv.x - 0.5) * 2.0, 2.0));
    return color;
}
float dither(uint2 id) {
    // Fixed sub-pixel dither, not animated grain or visible particles.
    uint h = id.x * 374761393u + id.y * 668265263u + 1447u;
    h = (h ^ (h >> 13)) * 1274126177u;
    return float(h & 65535u) / 65535.0 - 0.5;
}
kernel void aurora(device uchar4 *pixels [[buffer(0)]], constant Parameters &p [[buffer(1)]], uint2 id [[thread_position_in_grid]]) {
    if (id.x >= p.width || id.y >= p.height) return;
    float3 color = auroraColor((float2(id) + 0.5) / float2(p.width, p.height), p);
    float noise = dither(id) * 1.5;
    uchar3 rgb = uchar3(clamp(color * 255.0 + noise, 0.0, 255.0));
    pixels[id.y * p.width + id.x] = uchar4(rgb.b, rgb.g, rgb.r, 255);
}
kernel void auroraVideo(device ushort *luma [[buffer(0)]], device ushort2 *chroma [[buffer(1)]], constant Parameters &p [[buffer(2)]], uint2 id [[thread_position_in_grid]]) {
    if (id.x >= p.width || id.y >= p.height) return;
    float2 size = float2(p.width, p.height);
    float3 rgb = auroraColor((float2(id) + 0.5) / size, p);
    float y = dot(rgb, float3(0.2126, 0.7152, 0.0722));
    // SDR Rec.709, video-range 10-bit P010. Retain precision all the way
    // through encoding so dark television gradients do not form 8-bit steps.
    luma[id.y * p.width + id.x] = ushort(round(clamp(64.0 + 876.0 * y + 2.0 * dither(id), 64.0, 940.0))) << 6;
    if ((id.x & 1) == 0 && (id.y & 1) == 0) {
        float3 avg = (rgb + auroraColor((float2(id) + float2(1.5, 0.5)) / size, p)
                         + auroraColor((float2(id) + float2(0.5, 1.5)) / size, p)
                         + auroraColor((float2(id) + 1.5) / size, p)) * 0.25;
        float lum = dot(avg, float3(0.2126, 0.7152, 0.0722));
        float2 cbcr = float2((avg.b - lum) / 1.8556, (avg.r - lum) / 1.5748);
        chroma[(id.y / 2) * (p.width / 2) + id.x / 2] = ushort2(round(clamp(512.0 + 896.0 * cbcr, 64.0, 960.0))) << 6;
    }
}
"""
let library = try device.makeLibrary(source: shader, options: nil)
let pipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "aurora")!)

let videoPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "auroraVideo")!)

struct Parameters {
    var width: UInt32
    var height: UInt32
    var phase: Float
    var aspect: Float
}

func render(width: Int, height: Int, phase: Float) -> MTLBuffer {
    let buffer = device.makeBuffer(length: width * height * 4, options: .storageModeShared)!
    var parameters = Parameters(width: UInt32(width), height: UInt32(height), phase: phase, aspect: Float(width) / Float(height))
    let command = queue.makeCommandBuffer()!
    let encoder = command.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(pipeline)
    encoder.setBuffer(buffer, offset: 0, index: 0)
    encoder.setBytes(&parameters, length: MemoryLayout<Parameters>.stride, index: 1)
    encoder.dispatchThreads(MTLSize(width: width, height: height, depth: 1), threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
    encoder.endEncoding()
    command.commit()
    command.waitUntilCompleted()
    precondition(command.status == .completed, "Metal render failed")
    return buffer
}

func renderVideo(phase: Float) -> (MTLBuffer, MTLBuffer) {
    let luma = device.makeBuffer(length: 1920 * 1080 * 2, options: .storageModeShared)!
    let chroma = device.makeBuffer(length: 1920 * 540 * 2, options: .storageModeShared)!
    var parameters = Parameters(width: 1920, height: 1080, phase: phase, aspect: 1920.0 / 1080.0)
    let command = queue.makeCommandBuffer()!
    let encoder = command.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(videoPipeline)
    encoder.setBuffer(luma, offset: 0, index: 0)
    encoder.setBuffer(chroma, offset: 0, index: 1)
    encoder.setBytes(&parameters, length: MemoryLayout<Parameters>.stride, index: 2)
    encoder.dispatchThreads(MTLSize(width: 1920, height: 1080, depth: 1), threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
    encoder.endEncoding()
    command.commit()
    command.waitUntilCompleted()
    precondition(command.status == .completed, "Metal video render failed")
    return (luma, chroma)
}

func writePNG(_ relativePath: String, width: Int, height: Int, phase: Float = 0) throws {
    let url = root.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let buffer = render(width: width, height: height, phase: phase)
    let data = Data(bytes: buffer.contents(), count: buffer.length)
    let provider = CGDataProvider(data: data as CFData)!
    let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue).union(.byteOrder32Little),
                        provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination))
    print("Rendered \(relativePath) (\(width)×\(height))")
}

let brand = "DriftlyTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets"
for scale in 1...2 {
    let suffix = scale == 1 ? "" : "@2x"
    try writePNG("\(brand)/Top Shelf Image.imageset/Top Shelf Image\(suffix).png", width: 1920 * scale, height: 720 * scale)
    try writePNG("\(brand)/Top Shelf Image Wide.imageset/Top Shelf Image Wide\(suffix).png", width: 2320 * scale, height: 720 * scale)
    try writePNG("DriftlyTopShelf/QuietAurora\(suffix).png", width: 1920 * scale, height: 1080 * scale)
}
for (index, phase) in [Float(0), 0.25, 0.5, 0.75, 1].enumerated() {
    try writePNG("Build/QuietAuroraReview/phase-\(index).png", width: 1920, height: 1080, phase: phase)
}

if !CommandLine.arguments.contains("--stills-only") {
    let url = root.appendingPathComponent("Build/QuietAuroraReview/QuietAurora-preview.mp4")
    if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    writer.shouldOptimizeForNetworkUse = true
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: 1920, AVVideoHeightKey: 1080,
        AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                                   AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                                   AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2],
        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 20_000_000,
                                         AVVideoExpectedSourceFrameRateKey: 30,
                                         AVVideoMaxKeyFrameIntervalKey: 30,
                                         AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel]
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: CVPixelBufferCreationAttributes(
        pixelFormatType: .init(rawValue: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange), size: .init(width: 1920, height: 1080)
    ))
    try writer.start()
    writer.startSession(atSourceTime: .zero)
    // 24 seconds, excluding a duplicate terminal frame: position and velocity
    // match at phase 0/1. The system owns preview playback and repeat behavior.
    for frame in 0..<720 {
        let (luma, chroma) = renderVideo(phase: Float(frame) / 720)
        var pixels = try receiver.pixelBufferPool!.makeMutablePixelBuffer()
        pixels.accessUnsafeMutableRawPlaneBytes { planes in
            for (index, buffer) in [luma, chroma].enumerated() {
                let plane = planes[index]
                let height = index == 0 ? 1080 : 540
                for row in 0..<height {
                    memcpy(plane.bytes.baseAddress!.advanced(by: row * plane.properties.bytesPerRow),
                           buffer.contents().advanced(by: row * 3840), 3840)
                }
            }
        }
        try await receiver.append(CVReadOnlyPixelBuffer(pixels), with: CMTime(value: Int64(frame), timescale: 30))
        if frame % 120 == 0 { print("Video \(frame)/720") }
    }
    receiver.finish()
    await writer.finishWriting()
    precondition(writer.status == .completed, "\(String(describing: writer.error))")
    try Data(contentsOf: url).write(to: root.appendingPathComponent("DriftlyTopShelf/QuietAurora-preview.mp4"), options: .atomic)
    print("Rendered silent 24-second preview: \(url.path)")
}
