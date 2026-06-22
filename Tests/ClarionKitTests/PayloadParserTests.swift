import ClarionKit
import Foundation
import Testing

@Test
func payloadParserDecodesValidJSON() {
    let payload = PayloadParser().parse(
        data: #"""
        {
          "title": "Title",
          "message": "Message",
          "subtitle": "Subtitle",
          "sound": "default",
          "group": "group-id",
          "attachment": "/tmp/image.jpg"
        }
        """#.data(using: .utf8)!
    )

    #expect(payload == NotificationPayload(
        title: "Title",
        message: "Message",
        subtitle: "Subtitle",
        sound: "default",
        group: "group-id",
        attachment: "/tmp/image.jpg"
    ))
}

@Test
func payloadParserReturnsNilForMalformedJSON() {
    let payload = PayloadParser().parse(data: Data("{".utf8))
    #expect(payload == nil)
}

@Test
func payloadParserSupportsPartialPayloads() {
    let payload = PayloadParser().parse(
        data: #"{"message":"Message"}"#.data(using: .utf8)!
    )

    #expect(payload == NotificationPayload(message: "Message"))
}

@Test
func payloadParserReturnsNilForEmptyData() {
    let payload = PayloadParser().parse(data: Data())
    #expect(payload == nil)
}
