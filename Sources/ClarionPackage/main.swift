// Copyright (c) 2026 Axel Collard Bovy. SPDX-License-Identifier: MIT

import ClarionKit
import Foundation

@main
struct ClarionPackageMain {
    static func main() {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        guard let options = ClarionPackageOptionsParser().parse(arguments: CommandLine.arguments) else {
            FileHandle.standardError.write(
                Data(
                    """
                    usage: clarion-package [build|bundle|sign|install|all|clean] [--icon-variant dark|light|tinted] [--icon-source path/to/icon.png] [--rounded-mask radius-px] [--bundle-id value] [--app-name value]

                    """.utf8
                )
            )
            Foundation.exit(1)
        }

        do {
            try BundlePackager(packageRoot: packageRoot).run(options)
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            Foundation.exit(1)
        }
    }
}
