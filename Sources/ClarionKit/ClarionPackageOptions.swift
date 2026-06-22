import Foundation

public struct ClarionPackageOptions: Equatable, Sendable {
    public let command: BundlePackager.Command
    public let iconSelection: BundlePackager.IconSelection

    public init(
        command: BundlePackager.Command,
        iconSelection: BundlePackager.IconSelection = .current
    ) {
        self.command = command
        self.iconSelection = iconSelection
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
            default:
                return nil
            }
        }

        if iconVariant != nil, iconSourcePath != nil {
            return nil
        }

        if let iconVariant {
            return ClarionPackageOptions(command: command, iconSelection: .variant(iconVariant))
        }

        if let iconSourcePath {
            return ClarionPackageOptions(
                command: command,
                iconSelection: .generated(sourcePath: iconSourcePath, roundedMaskRadius: roundedMaskRadius)
            )
        }

        if roundedMaskRadius != nil {
            return nil
        }

        return ClarionPackageOptions(command: command, iconSelection: .current)
    }
}
