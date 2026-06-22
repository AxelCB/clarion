import ClarionKit
import Testing

@Test
func cliParserSupportsEveryFlag() {
    let payload = CLIArgumentsParser(
        arguments: [
            "/tmp/clarion",
            "--title", "Title",
            "--message", "Message",
            "--subtitle", "Subtitle",
            "--sound", "Tink",
            "--group", "group-id",
            "--attachment", "/tmp/image.png",
        ]
    ).parse()

    #expect(payload == NotificationPayload(
        title: "Title",
        message: "Message",
        subtitle: "Subtitle",
        sound: "Tink",
        group: "group-id",
        attachment: "/tmp/image.png"
    ))
}

@Test
func cliParserIgnoresUnknownFlagsAndKeepsLastKnownValue() {
    let payload = CLIArgumentsParser(
        arguments: [
            "/tmp/clarion",
            "--title", "first",
            "--ignored", "value",
            "--title", "second",
            "--message", "message",
            "--message", "override",
        ]
    ).parse()

    #expect(payload.title == "second")
    #expect(payload.message == "override")
    #expect(payload.subtitle == nil)
}

@Test
func cliParserIgnoresIncompletePairs() {
    let payload = CLIArgumentsParser(
        arguments: [
            "/tmp/clarion",
            "--title",
            "--message", "message",
            "--sound",
            "--group", "group-id",
        ]
    ).parse()

    #expect(payload.title == nil)
    #expect(payload.message == "message")
    #expect(payload.sound == nil)
    #expect(payload.group == "group-id")
}
