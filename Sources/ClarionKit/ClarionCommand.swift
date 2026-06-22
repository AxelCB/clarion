import Foundation

public enum ClarionCommand {
    public static func run(
        arguments: [String] = CommandLine.arguments,
        stdinReader: StandardInputReading = SystemStandardInputReader()
    ) -> Int32 {
        _ = ClarionInputResolver(arguments: arguments, stdinReader: stdinReader).resolve()
        return 0
    }
}
