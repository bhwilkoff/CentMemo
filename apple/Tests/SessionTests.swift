import Foundation
import Testing

/// Only the server refusing the refresh token signs the person out.
@MainActor
struct SessionTests {
    @Test func noSignalKeepsTheSession() {
        for e: Error in [URLError(.notConnectedToInternet), URLError(.timedOut), URLError(.cancelled), CancellationError(),
                         APIClient.APIError.refused("busy", code: 429), APIClient.APIError.refused("down", code: 503),
                         APIClient.APIError.decoding("captive portal")] {
            #expect(!APIClient.endsSession(e), "\(e)")
        }
    }

    @Test func aRefusedTokenEndsIt() {
        for code in [400, 401, 403] { #expect(APIClient.endsSession(APIClient.APIError.refused("no", code: code))) }
    }
}
