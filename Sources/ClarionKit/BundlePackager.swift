import Foundation

public struct BundlePackager {
    public enum Command: String {
        case build
        case bundle
        case sign
        case install
        case all
        case clean
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
        switch command {
        case .build:
            try buildReleaseBinary()
        case .bundle:
            try assembleBundle()
        case .sign:
            try signBundle()
        case .install:
            try installBundle()
        case .all:
            try assembleBundle()
            try signBundle()
        case .clean:
            try clean()
        }
    }

    public func assembleBundle() throws {
        try buildReleaseBinary()

        let bundleURL = packageRoot.appendingPathComponent("Clarion.app", isDirectory: true)
        let macOSURL = bundleURL.appendingPathComponent("Contents/MacOS", isDirectory: true)
        let resourcesURL = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let binaryURL = try releaseBinaryURL()

        try fileManager.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

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

    public func installBundle() throws {
        try assembleBundle()
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
        try processRunner.run(
            "/usr/bin/swift",
            arguments: ["build", "--disable-sandbox", "-c", "release", "--product", "clarion"],
            currentDirectoryURL: packageRoot
        )
    }

    private func releaseBinaryURL() throws -> URL {
        let output = try processRunner.run(
            "/usr/bin/swift",
            arguments: ["build", "--disable-sandbox", "-c", "release", "--show-bin-path"],
            currentDirectoryURL: packageRoot
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        return URL(fileURLWithPath: output, isDirectory: true)
            .appendingPathComponent("clarion", isDirectory: false)
    }
}
