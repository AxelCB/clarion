import Foundation

public protocol ProcessRunning {
    @discardableResult
    func run(_ launchPath: String, arguments: [String], currentDirectoryURL: URL?) throws -> String
}

public struct ShellProcessRunner: ProcessRunning {
    public init() {}

    @discardableResult
    public func run(_ launchPath: String, arguments: [String], currentDirectoryURL: URL?) throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let workingDirectoryURL = currentDirectoryURL
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let swiftModuleCacheURL = workingDirectoryURL
            .appendingPathComponent(".build/swift-module-cache", isDirectory: true)
        let clangModuleCacheURL = workingDirectoryURL
            .appendingPathComponent(".build/clang-module-cache", isDirectory: true)

        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        process.standardOutput = stdout
        process.standardError = stderr
        process.environment = configuredEnvironment(
            base: ProcessInfo.processInfo.environment,
            swiftModuleCacheURL: swiftModuleCacheURL,
            clangModuleCacheURL: clangModuleCacheURL
        )

        try FileManager.default.createDirectory(at: swiftModuleCacheURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: clangModuleCacheURL, withIntermediateDirectories: true)

        try process.run()
        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        let error = String(decoding: errorData, as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw ProcessRunnerError.commandFailed(
                launchPath: launchPath,
                arguments: arguments,
                status: process.terminationStatus,
                stderr: error
            )
        }

        return output.isEmpty ? error : output
    }

    private func configuredEnvironment(
        base: [String: String],
        swiftModuleCacheURL: URL,
        clangModuleCacheURL: URL
    ) -> [String: String] {
        var environment = base
        environment["SWIFT_MODULE_CACHE_PATH"] = swiftModuleCacheURL.path
        environment["CLANG_MODULE_CACHE_PATH"] = clangModuleCacheURL.path
        return environment
    }
}

public enum ProcessRunnerError: Error {
    case commandFailed(launchPath: String, arguments: [String], status: Int32, stderr: String)
}
