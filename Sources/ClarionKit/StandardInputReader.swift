import Darwin
import Foundation

public protocol StandardInputReading {
    var isInteractive: Bool { get }
    func readAll() -> Data?
}

public struct SystemStandardInputReader: StandardInputReading {
    public init() {}

    public var isInteractive: Bool {
        isatty(STDIN_FILENO) != 0
    }

    public func readAll() -> Data? {
        FileHandle.standardInput.readDataToEndOfFile()
    }
}
