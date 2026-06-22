#!/usr/bin/swift

import AppKit
import Foundation

struct IconDefinition {
    let fileName: String
    let dimension: Int
}

let definitions = [
    IconDefinition(fileName: "icon_16x16.png", dimension: 16),
    IconDefinition(fileName: "icon_16x16@2x.png", dimension: 32),
    IconDefinition(fileName: "icon_32x32.png", dimension: 32),
    IconDefinition(fileName: "icon_32x32@2x.png", dimension: 64),
    IconDefinition(fileName: "icon_128x128.png", dimension: 128),
    IconDefinition(fileName: "icon_128x128@2x.png", dimension: 256),
    IconDefinition(fileName: "icon_256x256.png", dimension: 256),
    IconDefinition(fileName: "icon_256x256@2x.png", dimension: 512),
    IconDefinition(fileName: "icon_512x512.png", dimension: 512),
    IconDefinition(fileName: "icon_512x512@2x.png", dimension: 1024),
]

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: generate_app_icon.swift <input-png> <output-prefix>\n".utf8))
    exit(1)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: false)
let outputPrefix = CommandLine.arguments[2]
let outputPrefixURL = URL(fileURLWithPath: outputPrefix, isDirectory: false)
let iconsetURL = outputPrefixURL.deletingPathExtension().appendingPathExtension("iconset")
let icnsURL = outputPrefixURL.deletingPathExtension().appendingPathExtension("icns")
let fileManager = FileManager.default
let temporaryDirectoryURL = fileManager.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)

guard let sourceImage = NSImage(contentsOf: inputURL) else {
    FileHandle.standardError.write(Data("failed to load input image: \(inputURL.path)\n".utf8))
    exit(1)
}

do {
    if fileManager.fileExists(atPath: iconsetURL.path) {
        try fileManager.removeItem(at: iconsetURL)
    }
    try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)

    var writtenTIFFDimensions = Set<Int>()
    var tiffPaths: [String] = []

    for definition in definitions {
        let size = NSSize(width: definition.dimension, height: definition.dimension)
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: definition.dimension,
                pixelsHigh: definition.dimension,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            throw NSError(domain: "ClarionIconGen", code: 1)
        }

        bitmap.size = size

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw NSError(domain: "ClarionIconGen", code: 2)
        }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        sourceImage.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ClarionIconGen", code: 3)
        }
        try pngData.write(to: iconsetURL.appendingPathComponent(definition.fileName, isDirectory: false))

        if writtenTIFFDimensions.contains(definition.dimension) == false {
            guard let tiffData = bitmap.representation(using: .tiff, properties: [:]) else {
                throw NSError(domain: "ClarionIconGen", code: 4)
            }
            let tiffURL = temporaryDirectoryURL.appendingPathComponent("\(definition.dimension).tiff", isDirectory: false)
            try tiffData.write(to: tiffURL)
            tiffPaths.append(tiffURL.path)
            writtenTIFFDimensions.insert(definition.dimension)
        }
    }

    if fileManager.fileExists(atPath: icnsURL.path) {
        try fileManager.removeItem(at: icnsURL)
    }

    let combinedTIFFURL = temporaryDirectoryURL.appendingPathComponent("AppIcon.tiff", isDirectory: false)

    let tiffUtil = Process()
    tiffUtil.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil", isDirectory: false)
    tiffUtil.arguments = ["-cat"] + tiffPaths + ["-out", combinedTIFFURL.path]

    try tiffUtil.run()
    tiffUtil.waitUntilExit()

    guard tiffUtil.terminationStatus == 0 else {
        FileHandle.standardError.write(Data("tiffutil failed with status \(tiffUtil.terminationStatus)\n".utf8))
        exit(tiffUtil.terminationStatus)
    }

    let tiff2icns = Process()
    tiff2icns.executableURL = URL(fileURLWithPath: "/usr/bin/tiff2icns", isDirectory: false)
    tiff2icns.arguments = [combinedTIFFURL.path, icnsURL.path]

    try tiff2icns.run()
    tiff2icns.waitUntilExit()

    guard tiff2icns.terminationStatus == 0 else {
        FileHandle.standardError.write(Data("tiff2icns failed with status \(tiff2icns.terminationStatus)\n".utf8))
        exit(tiff2icns.terminationStatus)
    }

    try? fileManager.removeItem(at: temporaryDirectoryURL)
} catch {
    FileHandle.standardError.write(Data("icon generation failed: \(error)\n".utf8))
    exit(1)
}
