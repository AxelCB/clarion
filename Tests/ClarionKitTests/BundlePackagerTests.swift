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
        arguments: [
            "/tmp/clarion-package",
            "bundle",
            "--icon-variant", "light",
            "--bundle-id", "com.example.variant",
            "--app-name", "VariantBuild",
        ]
    )

    #expect(options == ClarionPackageOptions(
        command: .bundle,
        iconSelection: .variant(.light),
        bundleId: "com.example.variant",
        appName: "VariantBuild"
    ))
}

@Test
func packageOptionsParserSupportsIconOverride() {
    let options = ClarionPackageOptionsParser().parse(
        arguments: [
            "/tmp/clarion-package",
            "all",
            "--icon-source", "custom.png",
            "--rounded-mask", "216",
            "--bundle-id", "com.example.custom",
            "--app-name", "CustomBuild",
        ]
    )

    #expect(options == ClarionPackageOptions(
        command: .all,
        iconSelection: .generated(sourcePath: "custom.png", roundedMaskRadius: 216),
        bundleId: "com.example.custom",
        appName: "CustomBuild"
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

@Test
func assembleBundleCanRenameBundleAndPatchInfoPlist() throws {
    let packageRoot = try temporaryPackageRoot()
    defer { try? FileManager.default.removeItem(at: packageRoot) }

    try seedBundleStructure(at: packageRoot)
    try Data("current".utf8).write(
        to: packageRoot.appendingPathComponent("Clarion.app/Contents/Resources/AppIcon.icns")
    )
    let binaryDirectory = packageRoot.appendingPathComponent("bin", isDirectory: true)
    try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
    try Data("binary".utf8).write(to: binaryDirectory.appendingPathComponent("clarion"))

    let runner = RecordingProcessRunner()
    runner.binaryOutputPath = binaryDirectory.path
    let options = ClarionPackageOptions(
        command: .bundle,
        iconSelection: .current,
        bundleId: "com.example.vscode",
        appName: "ClarionVSCode"
    )

    try BundlePackager(packageRoot: packageRoot, processRunner: runner).assembleBundle(options: options)

    let outputBundleURL = packageRoot.appendingPathComponent("ClarionVSCode.app", isDirectory: true)
    let plistData = try Data(contentsOf: outputBundleURL.appendingPathComponent("Contents/Info.plist"))
    let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as! [String: Any]

    #expect(FileManager.default.fileExists(atPath: outputBundleURL.path))
    #expect(plist["CFBundleIdentifier"] as? String == "com.example.vscode")
    #expect(plist["CFBundleName"] as? String == "ClarionVSCode")
    #expect(plist["CFBundleDisplayName"] as? String == "ClarionVSCode")
    #expect(plist["CFBundleExecutable"] as? String == "clarion")
    #expect(FileManager.default.fileExists(atPath: packageRoot.appendingPathComponent("Clarion.app", isDirectory: true).path))
}

@Test
func signBundleUsesResolvedBundleName() throws {
    let packageRoot = try temporaryPackageRoot()
    defer { try? FileManager.default.removeItem(at: packageRoot) }

    let runner = RecordingProcessRunner()
    let options = ClarionPackageOptions(command: .sign, appName: "ClarionVSCode")

    try BundlePackager(packageRoot: packageRoot, processRunner: runner).signBundle(options: options)

    #expect(runner.invocations.contains(where: {
        $0.launchPath == "/usr/bin/codesign" && $0.arguments == ["--force", "--deep", "--sign", "-", "ClarionVSCode.app"]
    }))
}

@Test
func installBundleUsesResolvedBundleName() throws {
    let packageRoot = try temporaryPackageRoot()
    let applicationsDirectoryURL = packageRoot.appendingPathComponent("Applications", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: packageRoot) }

    try seedBundleStructure(at: packageRoot)
    try Data("current".utf8).write(
        to: packageRoot.appendingPathComponent("Clarion.app/Contents/Resources/AppIcon.icns")
    )
    let binaryDirectory = packageRoot.appendingPathComponent("bin", isDirectory: true)
    try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
    try Data("binary".utf8).write(to: binaryDirectory.appendingPathComponent("clarion"))

    let runner = RecordingProcessRunner()
    runner.binaryOutputPath = binaryDirectory.path
    let options = ClarionPackageOptions(command: .install, appName: "ClarionVSCode")

    try BundlePackager(
        packageRoot: packageRoot,
        applicationsDirectoryURL: applicationsDirectoryURL,
        processRunner: runner
    ).installBundle(options: options)

    #expect(FileManager.default.fileExists(atPath: applicationsDirectoryURL.appendingPathComponent("ClarionVSCode.app").path))
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
    let infoPlistURL = packageRoot.appendingPathComponent("Clarion.app/Contents/Info.plist")
    let plist: [String: Any] = [
        "CFBundleIdentifier": "com.axelcollardbovy.clarion",
        "CFBundleName": "Clarion",
        "CFBundleDisplayName": "Clarion",
        "CFBundleExecutable": "clarion",
    ]
    let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try plistData.write(to: infoPlistURL)
}
