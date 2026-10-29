// 라이트 아이콘(오렌지 배경 + 검정 "30")에서 숫자만 투명 배경 레이어로 뽑는다 — iOS 26 Icon Composer(`AppIcon.icon`)의 숫자 레이어.
// 오렌지(R=1)는 투명, 검정(R=0)은 불투명. 빨강 채널로 알파를 정해 안티에일리어싱 가장자리를 살린다.
// 숫자는 **흰색**으로 낸다. 색(라이트 검정·다크 오렌지)은 icon.json 의 레이어 fill 로 입힌다 —
// 투명·색조 모드는 레이어 밝기로 그려서, 검정 이미지면 숫자가 거의 안 보였다(T-91 ictool 렌더).
//
//   swift tools/icons/extract_glyph.swift assets/icons/icon-light-src.png NextSet/NextSet/AppIcon.icon/Assets/Glyph30.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 3,
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    FileHandle.standardError.write("usage: extract_glyph.swift <light-icon.png> <out.png>\n".data(using: .utf8)!)
    exit(1)
}

let width = image.width, height = image.height
var pixels = [UInt8](repeating: 0, count: width * height * 4)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let info = CGImageAlphaInfo.premultipliedLast.rawValue
pixels.withUnsafeMutableBytes { buffer in
    let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: width * 4, space: space, bitmapInfo: info)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
}
for index in stride(from: 0, to: pixels.count, by: 4) {
    let alpha = 255 - pixels[index]  // 빨강이 0(검정)이면 불투명
    pixels[index] = alpha  // premultiplied 흰색: 색 성분 = 알파
    pixels[index + 1] = alpha
    pixels[index + 2] = alpha
    pixels[index + 3] = alpha
}
let output = pixels.withUnsafeMutableBytes { buffer in
    CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
              bytesPerRow: width * 4, space: space, bitmapInfo: info)!.makeImage()!
}
let url = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else { exit(1) }
print("wrote \(args[2]) \(width)x\(height)")
