// Claude Design 에서 2배로 내보낸 PNG 를 App Store 업로드 크기로 줄이고 알파 채널을 없앤다.
//   swift tools/appstore-screenshots/finalize.swift <in.png> <out.png> <width> <height>
// 비율이 다르면 가운데 기준으로 잘라 맞춘다(6.5형 1284×2778 은 6.9형보다 위아래가 약 6px씩 잘린다).
// 투명한 픽셀이 있으면 개수를 알려 준다(검정 위에 합성된다 — 시안 배경이 검정/주황이라 가장자리 확인용).
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let a = CommandLine.arguments
guard a.count == 5, let w = Int(a[3]), let h = Int(a[4]),
      let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    FileHandle.standardError.write("usage: finalize.swift <in> <out> <w> <h>\n".data(using: .utf8)!); exit(1)
}
// 투명 픽셀 세기
var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
rgba.withUnsafeMutableBytes { b in
    CGContext(data: b.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        .draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
}
var transparent = 0
for i in stride(from: 3, to: rgba.count, by: 4) where rgba[i] < 255 { transparent += 1 }
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
ctx.interpolationQuality = .high
// 비율이 다르면(예: 6.9형 → 6.5형) 찌그러뜨리지 않고 덮도록 키운 뒤 가운데를 남긴다.
let scale = max(Double(w) / Double(image.width), Double(h) / Double(image.height))
let dw = Double(image.width) * scale, dh = Double(image.height) * scale
ctx.draw(image, in: CGRect(x: (Double(w) - dw) / 2, y: (Double(h) - dh) / 2, width: dw, height: dh))
let dst = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dst, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(dst) else { exit(1) }
print("\(a[2]) \(w)x\(h) transparent-pixels-in-source=\(transparent)")
