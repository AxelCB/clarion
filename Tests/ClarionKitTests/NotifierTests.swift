import ClarionKit
import Foundation
import Testing

private final class StubNotificationCenterClient: NotificationCenterClient, @unchecked Sendable {
    var isAuthorized = true
    var authorizationError: Error?
    var addError: Error?
    var capturedRequest: NotificationRequestDescriptor?
    var addCallCount = 0

    func requestAuthorization(completion: @escaping @Sendable (Bool, (any Error)?) -> Void) {
        completion(isAuthorized, authorizationError)
    }

    func add(_ request: NotificationRequestDescriptor, completion: @escaping @Sendable ((any Error)?) -> Void) {
        capturedRequest = request
        addCallCount += 1
        completion(addError)
    }
}

@Test
func requestBuilderMapsDefaultSoundAndGroup() {
    let request = NotificationRequestBuilder().makeRequest(from: PreparedNotificationPayload(
        title: "Title",
        message: "Message",
        subtitle: "Subtitle",
        sound: nil,
        group: "group-id",
        attachment: nil
    ))

    #expect(request.identifier == "group-id")
    #expect(request.threadIdentifier == "group-id")
    #expect(request.sound == .default)
}

@Test
func requestBuilderUsesNamedSoundAndGeneratedIdentifierWithoutGroup() {
    let request = NotificationRequestBuilder().makeRequest(from: PreparedNotificationPayload(
        title: "Title",
        message: "Message",
        subtitle: nil,
        sound: "Tink",
        group: nil,
        attachment: nil
    ))

    #expect(request.sound == .named("Tink"))
    #expect(request.threadIdentifier == nil)
    #expect(request.identifier.isEmpty == false)
}

@Test
func requestBuilderKeepsOnlySupportedExistingAttachments() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    let validAttachmentURL = temporaryDirectory.appendingPathComponent("image.png", isDirectory: false)
    try Data("png".utf8).write(to: validAttachmentURL)

    let validRequest = NotificationRequestBuilder().makeRequest(from: PreparedNotificationPayload(
        title: "Title",
        message: "Message",
        subtitle: nil,
        sound: "default",
        group: nil,
        attachment: validAttachmentURL.path
    ))
    let missingRequest = NotificationRequestBuilder().makeRequest(from: PreparedNotificationPayload(
        title: "Title",
        message: "Message",
        subtitle: nil,
        sound: "default",
        group: nil,
        attachment: temporaryDirectory.appendingPathComponent("missing.png").path
    ))
    let unsupportedRequest = NotificationRequestBuilder().makeRequest(from: PreparedNotificationPayload(
        title: "Title",
        message: "Message",
        subtitle: nil,
        sound: "default",
        group: nil,
        attachment: temporaryDirectory.appendingPathComponent("image.gif").path
    ))

    #expect(validRequest.attachmentURL == validAttachmentURL)
    #expect(missingRequest.attachmentURL == nil)
    #expect(unsupportedRequest.attachmentURL == nil)
}

@Test
func notifierSkipsAddWhenAuthorizationIsDenied() {
    let client = StubNotificationCenterClient()
    client.isAuthorized = false

    Notifier(notificationCenter: client).post(PreparedNotificationPayload(
        title: "Title",
        message: "Message",
        subtitle: nil,
        sound: nil,
        group: nil,
        attachment: nil
    ))

    #expect(client.addCallCount == 0)
    #expect(client.capturedRequest == nil)
}

@Test
func notifierStillReturnsWhenAddFails() {
    struct StubError: Error {}

    let client = StubNotificationCenterClient()
    client.addError = StubError()

    Notifier(notificationCenter: client).post(PreparedNotificationPayload(
        title: "Title",
        message: "Message",
        subtitle: "Subtitle",
        sound: "",
        group: "group-id",
        attachment: nil
    ))

    #expect(client.addCallCount == 1)
    #expect(client.capturedRequest?.threadIdentifier == "group-id")
    #expect(client.capturedRequest?.sound == .default)
}
