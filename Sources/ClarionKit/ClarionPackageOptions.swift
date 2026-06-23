// Copyright (c) 2026 Axel Collard Bovy. SPDX-License-Identifier: MIT

import Foundation

public struct ClarionPackageOptions: Equatable, Sendable {
    public let command: BundlePackager.Command
    public let iconSelection: BundlePackager.IconSelection
    public let bundleId: String?
    public let appName: String?

    public init(
        command: BundlePackager.Command,
        iconSelection: BundlePackager.IconSelection = .current,
        bundleId: String? = nil,
        appName: String? = nil
    ) {
        self.command = command
        self.iconSelection = iconSelection
        self.bundleId = bundleId
        self.appName = appName
    }
}

public struct ClarionPackageOptionsParser {
    public init() {}

    public func parse(arguments: [String]) -> ClarionPackageOptions? {
        var remaining = Array(arguments.dropFirst())
        let command = remaining.first.flatMap(BundlePackager.Command.init(rawValue:)) ?? .all
        if BundlePackager.Command(rawValue: remaining.first ?? "") != nil {
            remaining.removeFirst()
        }

        var iconVariant: BundlePackager.IconVariant?
        var iconSourcePath: String?
        var roundedMaskRadius: Double?
        var bundleId: String?
        var appName: String?

        var index = 0
        while index < remaining.count {
            switch remaining[index] {
            case "--icon-variant":
                guard index + 1 < remaining.count,
                      let variant = BundlePackager.IconVariant(rawValue: remaining[index + 1])
                else {
                    return nil
                }
                iconVariant = variant
                index += 2
            case "--icon-source":
                guard index + 1 < remaining.count else {
                    return nil
                }
                iconSourcePath = remaining[index + 1]
                index += 2
            case "--rounded-mask":
                guard index + 1 < remaining.count,
                      let radius = Double(remaining[index + 1])
                else {
                    return nil
                }
                roundedMaskRadius = radius
                index += 2
            case "--bundle-id":
                guard index + 1 < remaining.count else {
                    return nil
                }
                bundleId = remaining[index + 1]
                index += 2
            case "--app-name":
                guard index + 1 < remaining.count else {
                    return nil
                }
                appName = remaining[index + 1]
                index += 2
            default:
                return nil
            }
        }

        if iconVariant != nil, iconSourcePath != nil {
            return nil
        }

        if let iconVariant {
            return ClarionPackageOptions(
                command: command,
                iconSelection: .variant(iconVariant),
                bundleId: bundleId,
                appName: appName
            )
        }

        if let iconSourcePath {
            return ClarionPackageOptions(
                command: command,
                iconSelection: .generated(sourcePath: iconSourcePath, roundedMaskRadius: roundedMaskRadius),
                bundleId: bundleId,
                appName: appName
            )
        }

        if roundedMaskRadius != nil {
            return nil
        }

        return ClarionPackageOptions(
            command: command,
            iconSelection: .current,
            bundleId: bundleId,
            appName: appName
        )
    }
}
