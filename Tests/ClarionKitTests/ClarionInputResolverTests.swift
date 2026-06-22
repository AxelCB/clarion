import ClarionKit
import Foundation
import Testing

private struct StubStandardInputReader: StandardInputReading {
    let isInteractive: Bool
    let data: Data?

    func readAll() -> Data? {
        data
    }
}

@Test
func resolverSkipsTTYInput() {
    let payload = ClarionInputResolver(
        arguments: ["/tmp/clarion", "--title", "Title", "--message", "Message"],
        stdinReader: StubStandardInputReader(
            isInteractive: true,
            data: #"{"title":"Ignored","message":"Ignored"}"#.data(using: .utf8)
        )
    ).resolve()

    #expect(payload?.title == "Title")
    #expect(payload?.message == "Message")
}

@Test
func resolverMergesStdinWithFlagOverridesFieldByField() {
    let payload = ClarionInputResolver(
        arguments: [
            "/tmp/clarion",
            "--title", "Flag Title",
            "--group", "flag-group",
        ],
        stdinReader: StubStandardInputReader(
            isInteractive: false,
            data: #"""
            {
              "title": "stdin title",
              "message": "stdin message",
              "subtitle": "stdin subtitle",
              "sound": "Glass",
              "group": "stdin-group",
              "attachment": "/tmp/stdin.png"
            }
            """#.data(using: .utf8)
        )
    ).resolve()

    #expect(payload == PreparedNotificationPayload(
        title: "Flag Title",
        message: "stdin message",
        subtitle: "stdin subtitle",
        sound: "Glass",
        group: "flag-group",
        attachment: "/tmp/stdin.png"
    ))
}

@Test
func resolverIgnoresMalformedStdin() {
    let payload = ClarionInputResolver(
        arguments: ["/tmp/clarion", "--title", "Title", "--message", "Message"],
        stdinReader: StubStandardInputReader(
            isInteractive: false,
            data: Data("{invalid".utf8)
        )
    ).resolve()

    #expect(payload?.title == "Title")
    #expect(payload?.message == "Message")
}

@Test
func resolverReturnsNilWhenRequiredFieldsAreMissing() {
    let missingTitle = ClarionInputResolver(
        arguments: ["/tmp/clarion", "--message", "Message"],
        stdinReader: StubStandardInputReader(isInteractive: true, data: nil)
    ).resolve()
    let missingMessage = ClarionInputResolver(
        arguments: ["/tmp/clarion", "--title", "Title"],
        stdinReader: StubStandardInputReader(isInteractive: true, data: nil)
    ).resolve()
    let missingBoth = ClarionInputResolver(
        arguments: ["/tmp/clarion"],
        stdinReader: StubStandardInputReader(isInteractive: true, data: nil)
    ).resolve()

    #expect(missingTitle == nil)
    #expect(missingMessage == nil)
    #expect(missingBoth == nil)
}
