// Copyright (c) 2026 Axel Collard Bovy. SPDX-License-Identifier: MIT

import Foundation

public struct BundlePackager {
    public struct BundleConfiguration: Equatable, Sendable {
        public let appName: String
        public let bundleName: String
        public let bundleId: String?

        public init(appName: String, bundleName: String, bundleId: String?) {
            self.appName = appName
            self.bundleName = bundleName
            self.bundleId = bundleId
        }
    }

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
    private let applicationsDirectoryURL: URL
    private let processRunner: ProcessRunning
    private let fileManager: FileManager

    public init(
        packageRoot: URL,
        applicationsDirectoryURL: URL = URL(fileURLWithPath: "/Applications", isDirectory: true),
        processRunner: ProcessRunning = ShellProcessRunner(),
        fileManager: FileManager = .default
    ) {
        self.packageRoot = packageRoot
        self.applicationsDirectoryURL = applicationsDirectoryURL
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
            try assembleBundle(options: options)
        case .sign:
            try signBundle(options: options)
        case .install:
            try installBundle(options: options)
        case .all:
            try assembleBundle(options: options)
            try signBundle(options: options)
        case .clean:
            try clean()
        }
    }

    public func assembleBundle(
        iconSelection: IconSelection = .current,
        bundleId: String? = nil,
        appName: String? = nil
    ) throws {
        try assembleBundle(
            options: ClarionPackageOptions(
                command: .bundle,
                iconSelection: iconSelection,
                bundleId: bundleId,
                appName: appName
            )
        )
    }

    public func assembleBundle(iconSelection: IconSelection = .current) throws {
        try assembleBundle(options: ClarionPackageOptions(command: .bundle, iconSelection: iconSelection))
    }

    public func assembleBundle(options: ClarionPackageOptions) throws {
        try buildReleaseBinary()

        let configuration = bundleConfiguration(bundleId: options.bundleId, appName: options.appName)
        let bundleURL = try prepareBundleScaffold(configuration: configuration)
        let macOSURL = bundleURL.appendingPathComponent("Contents/MacOS", isDirectory: true)
        let resourcesURL = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let binaryURL = try releaseBinaryURL()

        try fileManager.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        try installAppIcon(into: resourcesURL, iconSelection: options.iconSelection)
        try patchInfoPlistIfNeeded(bundleURL: bundleURL, configuration: configuration)

        let bundledBinaryURL = macOSURL.appendingPathComponent("clarion", isDirectory: false)
        if fileManager.fileExists(atPath: bundledBinaryURL.path) {
            try fileManager.removeItem(at: bundledBinaryURL)
        }
        try fileManager.copyItem(at: binaryURL, to: bundledBinaryURL)
    }

    public func signBundle(options: ClarionPackageOptions = ClarionPackageOptions(command: .sign)) throws {
        let configuration = bundleConfiguration(bundleId: options.bundleId, appName: options.appName)
        try processRunner.run(
            "/usr/bin/codesign",
            arguments: ["--force", "--deep", "--sign", "-", configuration.bundleName],
            currentDirectoryURL: packageRoot
        )
    }

    public func signBundle() throws {
        try signBundle(options: ClarionPackageOptions(command: .sign))
    }

    public func installBundle(iconSelection: IconSelection = .current) throws {
        try installBundle(options: ClarionPackageOptions(command: .install, iconSelection: iconSelection))
    }

    public func installBundle(options: ClarionPackageOptions) throws {
        let configuration = bundleConfiguration(bundleId: options.bundleId, appName: options.appName)
        try assembleBundle(options: options)
        try signBundle(options: options)

        let sourceURL = packageRoot.appendingPathComponent(configuration.bundleName, isDirectory: true)
        let destinationURL = applicationsDirectoryURL.appendingPathComponent(configuration.bundleName, isDirectory: true)

        try fileManager.createDirectory(at: applicationsDirectoryURL, withIntermediateDirectories: true)

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

    private func bundleConfiguration(bundleId: String?, appName: String?) -> BundleConfiguration {
        let normalizedAppName = normalizeAppName(appName) ?? "Clarion"
        return BundleConfiguration(
            appName: normalizedAppName,
            bundleName: "\(normalizedAppName).app",
            bundleId: bundleId
        )
    }

    private func normalizeAppName(_ appName: String?) -> String? {
        guard let appName, appName.isEmpty == false else {
            return nil
        }

        if appName.hasSuffix(".app") {
            return String(appName.dropLast(4))
        }

        return appName
    }

    private func prepareBundleScaffold(configuration: BundleConfiguration) throws -> URL {
        let templateBundleURL = packageRoot.appendingPathComponent("Clarion.app", isDirectory: true)
        let outputBundleURL = packageRoot.appendingPathComponent(configuration.bundleName, isDirectory: true)

        if outputBundleURL.path != templateBundleURL.path {
            if fileManager.fileExists(atPath: outputBundleURL.path) {
                try fileManager.removeItem(at: outputBundleURL)
            }
            try fileManager.copyItem(at: templateBundleURL, to: outputBundleURL)
        }

        return outputBundleURL
    }

    private func patchInfoPlistIfNeeded(bundleURL: URL, configuration: BundleConfiguration) throws {
        guard configuration.bundleId != nil || configuration.appName != "Clarion" else {
            return
        }

        let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist", isDirectory: false)
        let plistData = try Data(contentsOf: infoPlistURL)
        let plistObject = try PropertyListSerialization.propertyList(from: plistData, format: nil)

        guard let plist = plistObject as? [String: Any] else {
            throw BundlePackagerError.invalidInfoPlist(infoPlistURL.path)
        }

        var updatedPlist = plist
        if let bundleId = configuration.bundleId {
            updatedPlist["CFBundleIdentifier"] = bundleId
        }
        if configuration.appName != "Clarion" {
            updatedPlist["CFBundleName"] = configuration.appName
            updatedPlist["CFBundleDisplayName"] = configuration.appName
        }

        let updatedData = try PropertyListSerialization.data(fromPropertyList: updatedPlist, format: .xml, options: 0)
        try updatedData.write(to: infoPlistURL)
    }

    private func resolvePath(_ path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path, isDirectory: false)
        }

        return packageRoot.appendingPathComponent(path, isDirectory: false)
    }
}

public enum BundlePackagerError: Error {
    case invalidInfoPlist(String)
}
