import Foundation

public struct BundlePackager {
    public enum Command: String, Sendable {
        case build
        case bundle
        case sign
        case install
        case all
        case clean
    }

    public enum IconVariant: String, Equatable, Sendable {
        case dark
        case light
        case tinted
    }

    public enum IconSelection: Equatable, Sendable {
        case current
        case variant(IconVariant)
        case generated(sourcePath: String, roundedMaskRadius: Double?)
    }

    private let packageRoot: URL
    private let processRunner: ProcessRunning
    private let fileManager: FileManager

    public init(
        packageRoot: URL,
        processRunner: ProcessRunning = ShellProcessRunner(),
        fileManager: FileManager = .default
    ) {
        self.packageRoot = packageRoot
        self.processRunner = processRunner
        self.fileManager = fileManager
    }

    public func run(_ command: Command) throws {
        try run(ClarionPackageOptions(command: command))
    }

    public func run(_ options: ClarionPackageOptions) throws {
        switch options.command {
        case .build:
            try buildReleaseBinary()
        case .bundle:
            try assembleBundle(iconSelection: options.iconSelection)
        case .sign:
            try signBundle()
        case .install:
            try installBundle(iconSelection: options.iconSelection)
        case .all:
            try assembleBundle(iconSelection: options.iconSelection)
            try signBundle()
        case .clean:
            try clean()
        }
    }

    public func assembleBundle(iconSelection: IconSelection = .current) throws {
        try buildReleaseBinary()

        let bundleURL = packageRoot.appendingPathComponent("Clarion.app", isDirectory: true)
        let macOSURL = bundleURL.appendingPathComponent("Contents/MacOS", isDirectory: true)
        let resourcesURL = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let binaryURL = try releaseBinaryURL()

        try fileManager.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        try installAppIcon(into: resourcesURL, iconSelection: iconSelection)

        let bundledBinaryURL = macOSURL.appendingPathComponent("clarion", isDirectory: false)
        if fileManager.fileExists(atPath: bundledBinaryURL.path) {
            try fileManager.removeItem(at: bundledBinaryURL)
        }
        try fileManager.copyItem(at: binaryURL, to: bundledBinaryURL)
    }

    public func signBundle() throws {
        try processRunner.run(
            "/usr/bin/codesign",
            arguments: ["--force", "--deep", "--sign", "-", "Clarion.app"],
            currentDirectoryURL: packageRoot
        )
    }

    public func installBundle(iconSelection: IconSelection = .current) throws {
        try assembleBundle(iconSelection: iconSelection)
        try signBundle()

        let sourceURL = packageRoot.appendingPathComponent("Clarion.app", isDirectory: true)
        let destinationURL = URL(fileURLWithPath: "/Applications/Clarion.app", isDirectory: true)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    public func clean() throws {
        let bundledBinaryURL = packageRoot
            .appendingPathComponent("Clarion.app", isDirectory: true)
            .appendingPathComponent("Contents/MacOS/clarion", isDirectory: false)

        if fileManager.fileExists(atPath: bundledBinaryURL.path) {
            try fileManager.removeItem(at: bundledBinaryURL)
        }

        try processRunner.run(
            "/usr/bin/swift",
            arguments: ["package", "clean"],
            currentDirectoryURL: packageRoot
        )
    }

    private func buildReleaseBinary() throws {
        guard overriddenBinaryURL() == nil else {
            return
        }

        try processRunner.run(
            "/usr/bin/swift",
            arguments: ["build", "--disable-sandbox", "-c", "release", "--product", "clarion"],
            currentDirectoryURL: packageRoot
        )
    }

    private func releaseBinaryURL() throws -> URL {
        if let overriddenBinaryURL = overriddenBinaryURL() {
            return overriddenBinaryURL
        }

        let output = try processRunner.run(
            "/usr/bin/swift",
            arguments: ["build", "--disable-sandbox", "-c", "release", "--show-bin-path"],
            currentDirectoryURL: packageRoot
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        return URL(fileURLWithPath: output, isDirectory: true)
            .appendingPathComponent("clarion", isDirectory: false)
    }

    private func overriddenBinaryURL() -> URL? {
        guard let path = ProcessInfo.processInfo.environment["CLARION_PACKAGE_BINARY_PATH"],
              path.isEmpty == false
        else {
            return nil
        }

        return URL(fileURLWithPath: path, isDirectory: false)
    }

    private func installAppIcon(into resourcesURL: URL, iconSelection: IconSelection) throws {
        switch iconSelection {
        case .current:
            return
        case .variant(let variant):
            let variantURL = resourcesURL.appendingPathComponent("AppIcon-\(variant.rawValue).icns", isDirectory: false)
            try replaceAppIcon(from: variantURL, into: resourcesURL)
        case .generated(let sourcePath, let roundedMaskRadius):
            let sourceURL = resolvePath(sourcePath)
            let generatedPrefixURL = fileManager.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: false)
            var arguments = [
                "Scripts/generate_app_icon.swift",
                sourceURL.path,
                generatedPrefixURL.path,
            ]
            if let roundedMaskRadius {
                arguments += ["--rounded-mask", String(roundedMaskRadius)]
            }

            try processRunner.run(
                "/usr/bin/swift",
                arguments: arguments,
                currentDirectoryURL: packageRoot
            )

            let generatedICNSURL = generatedPrefixURL.deletingPathExtension().appendingPathExtension("icns")
            try replaceAppIcon(from: generatedICNSURL, into: resourcesURL)
        }
    }

    private func replaceAppIcon(from sourceURL: URL, into resourcesURL: URL) throws {
        let destinationURL = resourcesURL.appendingPathComponent("AppIcon.icns", isDirectory: false)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private func resolvePath(_ path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path, isDirectory: false)
        }

        return packageRoot.appendingPathComponent(path, isDirectory: false)
    }
}
