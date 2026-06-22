import ClarionKit
import Foundation

@main
struct ClarionPackageMain {
    static func main() {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let arguments = Array(CommandLine.arguments.dropFirst())
        let command = arguments.first.flatMap(BundlePackager.Command.init(rawValue:)) ?? .all

        do {
            try BundlePackager(packageRoot: packageRoot).run(command)
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            Foundation.exit(1)
        }
    }
}
