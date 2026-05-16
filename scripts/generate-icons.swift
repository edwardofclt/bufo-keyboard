#!/usr/bin/env swift
// Generates:
//   1. Opaque (white-flattened) AppIcon at
//      BufoKeyboard/Assets.xcassets/AppIcon.appiconset/AppIcon.png
//   2. iMessage app icon set at
//      BufoMessagesExtension/Assets.xcassets/iMessage App Icon.stickersiconset/
//      with all sizes required by App Store Connect for iMessage apps.
//
// Usage: swift scripts/generate-icons.swift <source.png>
//
// The iMessage icons are 4:3 aspect — the source is center-cropped to 4:3
// before being resized.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: generate-icons.swift <source.png>\n".utf8))
    exit(2)
}
let srcPath = args[1]

let scriptDir = URL(fileURLWithPath: (#filePath as NSString).deletingLastPathComponent)
let repoRoot = scriptDir.deletingLastPathComponent()
let appIconDir = repoRoot.appendingPathComponent("BufoKeyboard/Assets.xcassets/AppIcon.appiconset")
let messagesAssetsDir = repoRoot.appendingPathComponent("BufoMessagesExtension/Assets.xcassets")
let messagesIconsetDir = messagesAssetsDir.appendingPathComponent("iMessage App Icon.stickersiconset")

func loadCG(_ path: String) -> CGImage {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        fatalError("cannot read \(path)")
    }
    return img
}

func writePNG(_ image: CGImage, to url: URL) {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("cannot create dest \(url.path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) { fatalError("finalize failed \(url.path)") }
}

func flatten(_ image: CGImage, fill: CGColor) -> CGImage {
    let w = image.width, h = image.height
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                              space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        fatalError("ctx fail")
    }
    ctx.setFillColor(fill)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()!
}

func centerCrop43(_ image: CGImage) -> CGImage {
    let w = image.width, h = image.height
    let targetAspect: CGFloat = 4.0 / 3.0
    let imgAspect = CGFloat(w) / CGFloat(h)
    var cropW = w, cropH = h, x = 0, y = 0
    if imgAspect > targetAspect {
        cropW = Int(CGFloat(h) * targetAspect)
        x = (w - cropW) / 2
    } else {
        cropH = Int(CGFloat(w) / targetAspect)
        y = (h - cropH) / 2
    }
    return image.cropping(to: CGRect(x: x, y: y, width: cropW, height: cropH))!
}

func resizeOpaque(_ image: CGImage, to size: CGSize) -> CGImage {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                              bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        fatalError("ctx fail")
    }
    ctx.interpolationQuality = .high
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(origin: .zero, size: size))
    ctx.draw(image, in: CGRect(origin: .zero, size: size))
    return ctx.makeImage()!
}

let src = loadCG(srcPath)
print("source: \(src.width)x\(src.height)")

// 1) Main AppIcon — flatten to opaque white at 1024x1024
let flat = flatten(src, fill: CGColor(red: 1, green: 1, blue: 1, alpha: 1))
let appIcon1024 = resizeOpaque(flat, to: CGSize(width: 1024, height: 1024))
writePNG(appIcon1024, to: appIconDir.appendingPathComponent("AppIcon.png"))
print("wrote AppIcon 1024x1024 opaque")

// 2) iMessage icons — center-cropped to 4:3, opaque, all required sizes
let cropped = centerCrop43(flat)

struct MIcon {
    let file: String
    let size: String
    let scale: String
    let idiom: String
    let platform: String?
    let w: Int
    let h: Int
}

// 60x45 (iphone), 67x50 / 74x55 (ipad): explicit idioms are required so
// App Store Connect recognizes them as iMessage app icons (ITMS-90649).
let messagesIcons: [MIcon] = [
    .init(file: "icon-27x20@2x.png",   size: "27x20",    scale: "2x", idiom: "universal",    platform: "ios", w: 54,   h: 40),
    .init(file: "icon-27x20@3x.png",   size: "27x20",    scale: "3x", idiom: "universal",    platform: "ios", w: 81,   h: 60),
    .init(file: "icon-32x24@2x.png",   size: "32x24",    scale: "2x", idiom: "universal",    platform: "ios", w: 64,   h: 48),
    .init(file: "icon-32x24@3x.png",   size: "32x24",    scale: "3x", idiom: "universal",    platform: "ios", w: 96,   h: 72),
    .init(file: "icon-60x45@2x.png",   size: "60x45",    scale: "2x", idiom: "iphone",       platform: nil,   w: 120,  h: 90),
    .init(file: "icon-60x45@3x.png",   size: "60x45",    scale: "3x", idiom: "iphone",       platform: nil,   w: 180,  h: 135),
    .init(file: "icon-67x50@2x.png",   size: "67x50",    scale: "2x", idiom: "ipad",         platform: nil,   w: 134,  h: 100),
    .init(file: "icon-74x55@2x.png",   size: "74x55",    scale: "2x", idiom: "ipad",         platform: nil,   w: 148,  h: 110),
    .init(file: "icon-1024x768.png",   size: "1024x768", scale: "1x", idiom: "ios-marketing",platform: "ios", w: 1024, h: 768),
]

for icon in messagesIcons {
    let resized = resizeOpaque(cropped, to: CGSize(width: icon.w, height: icon.h))
    writePNG(resized, to: messagesIconsetDir.appendingPathComponent(icon.file))
}

// Contents.json for the stickersiconset is *not* written here. It's regenerated
// from a Python manifest by the BufoMessagesExtension target's pre-build phase
// (scripts/write-imessage-iconset-json.py). Keeping the writer in one place
// prevents the ITMS-90649 regression where Xcode's asset catalog editor silently
// rewrites the file with "universal" idioms.

print("wrote \(messagesIcons.count) messages icon PNGs to \(messagesIconsetDir.path)")
