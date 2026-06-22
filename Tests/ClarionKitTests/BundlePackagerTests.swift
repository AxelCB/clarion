import ClarionKit
import Foundation
import Testing

@Test
func bundlePackagerCommandDefaultsCanBeParsed() {
    #expect(BundlePackager.Command(rawValue: "build") == .build)
    #expect(BundlePackager.Command(rawValue: "bundle") == .bundle)
    #expect(BundlePackager.Command(rawValue: "sign") == .sign)
    #expect(BundlePackager.Command(rawValue: "install") == .install)
    #expect(BundlePackager.Command(rawValue: "all") == .all)
    #expect(BundlePackager.Command(rawValue: "clean") == .clean)
}

@Test
func packageOptionsParserSupportsVariantSelection() {
    let options = ClarionPackageOptionsParser().parse(
        arguments: ["/tmp/clarion-package", "bundle", "--icon-variant", "light"]
    )

    #expect(options == ClarionPackageOptions(command: .bundle, iconSelection: .variant(.light)))
}

@Test
func packageOptionsParserSupportsIconOverride() {
    let options = ClarionPackageOptionsParser().parse(
        arguments: [
            "/tmp/clarion-package",
            "all",
            "--icon-source", "custom.png",
            "--rounded-mask", "216",
        ]
    )

    #expect(options == ClarionPackageOptions(
        command: .all,
        iconSelection: .generated(sourcePath: "custom.png", roundedMaskRadius: 216)
    ))
}

@Test
func packageOptionsParserRejectsConflictingOrIncompleteOptions() {
    let conflicting = ClarionPackageOptionsParser().parse(
        arguments: [
            "/tmp/clarion-package",
            "--icon-variant", "dark",
            "--icon-source", "custom.png",
        ]
    )
    let incompleteVariant = ClarionPackageOptionsParser().parse(
        arguments: ["/tmp/clarion-package", "--icon-variant"]
    )
    let orphanMask = ClarionPackageOptionsParser().parse(
        arguments: ["/tmp/clarion-package", "--rounded-mask", "100"]
    )

    #expect(conflicting == nil)
    #expect(incompleteVariant == nil)
    #expect(orphanMask == nil)
}

private final class RecordingProcessRunner: ProcessRunning {
    var invocations: [(launchPath: String, arguments: [String])] = []
    var binaryOutputPath: String?

    @discardableResult
    func run(_ launchPath: String, arguments: [String], currentDirectoryURL: URL?) throws -> String {
        invocations.append((launchPath, arguments))

        if arguments.contains("--show-bin-path"), let binaryOutputPath {
            return URL(fileURLWithPath: binaryOutputPath, isDirectory: true).path
        }

        if arguments.first == "Scripts/generate_app_icon.swift" {
            let outputPrefix = URL(fileURLWithPath: arguments[2], isDirectory: false)
            let icnsURL = outputPrefix.deletingPathExtension().appendingPathExtension("icns")
            try Data("generated".utf8).write(to: icnsURL)
        }

        return ""
    }
}

@Test
func assembleBundleCanSwitchToBundledVariantIcon() throws {
    let packageRoot = try temporaryPackageRoot()
    defer { try? FileManager.default.removeItem(at: packageRoot) }

    try seedBundleStructure(at: packageRoot)
    try Data("variant".utf8).write(
        to: packageRoot.appendingPathComponent("Clarion.app/Contents/Resources/AppIcon-light.icns")
    )
    try Data("current".utf8).write(
        to: packageRoot.appendingPathComponent("Clarion.app/Contents/Resources/AppIcon.icns")
    )
    let binaryDirectory = packageRoot.appendingPathComponent("bin", isDirectory: true)
    try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
    try Data("binary".utf8).write(to: binaryDirectory.appendingPathComponent("clarion"))

    let runner = RecordingProcessRunner()
    runner.binaryOutputPath = binaryDirectory.path

    try BundlePackager(packageRoot: packageRoot, processRunner: runner).assembleBundle(iconSelection: .variant(.light))

    let activeIcon = try Data(contentsOf: packageRoot.appendingPathComponent("Clarion.app/Contents/Resources/AppIcon.icns"))
    #expect(String(decoding: activeIcon, as: UTF8.self) == "variant")
}

@Test
func assembleBundleCanGenerateOverrideIcon() throws {
    let packageRoot = try temporaryPackageRoot()
    defer { try? FileManager.default.removeItem(at: packageRoot) }

    try seedBundleStructure(at: packageRoot)
    try Data("current".utf8).write(
        to: packageRoot.appendingPathComponent("Clarion.app/Contents/Resources/AppIcon.icns")
    )
    try Data("png".utf8).write(to: packageRoot.appendingPathComponent("custom.png"))
    let binaryDirectory = packageRoot.appendingPathComponent("bin", isDirectory: true)
    try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
    try Data("binary".utf8).write(to: binaryDirectory.appendingPathComponent("clarion"))

    let runner = RecordingProcessRunner()
    runner.binaryOutputPath = binaryDirectory.path

    try BundlePackager(packageRoot: packageRoot, processRunner: runner).assembleBundle(
        iconSelection: .generated(sourcePath: "custom.png", roundedMaskRadius: 180)
    )

    let activeIcon = try Data(contentsOf: packageRoot.appendingPathComponent("Clarion.app/Contents/Resources/AppIcon.icns"))
    #expect(String(decoding: activeIcon, as: UTF8.self) == "generated")
    #expect(runner.invocations.contains(where: {
        $0.launchPath == "/usr/bin/swift" &&
        $0.arguments.starts(with: ["Scripts/generate_app_icon.swift", packageRoot.appendingPathComponent("custom.png").path])
    }))
}

private func temporaryPackageRoot() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func seedBundleStructure(at packageRoot: URL) throws {
    try FileManager.default.createDirectory(
        at: packageRoot.appendingPathComponent("Clarion.app/Contents/Resources", isDirectory: true),
        withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: packageRoot.appendingPathComponent("Clarion.app/Contents/MacOS", isDirectory: true),
        withIntermediateDirectories: true
    )
}
