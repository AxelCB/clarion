// Copyright (c) 2026 Axel Collard Bovy. SPDX-License-Identifier: MIT

#if DEBUG
import Foundation

enum DebugPayloadCapture {
    static func write(_ payload: PreparedNotificationPayload, to url: URL) throws {
        let data = try JSONEncoder().encode(payload)
        try data.write(to: url)
    }
}
#endif
