import Testing
import Foundation
@testable import EWizKit

@Suite("Scheduled wake requests")
struct ScheduledWakeRequestTests {

    @Test("scheduleWake and cancelWake survive the socket round trip")
    func roundTrip() throws {
        let requests: [ControlRequest] = [
            .scheduleWake(seconds: 300),
            .cancelWake(stamp: "10/15/2026 09:41:07"),
        ]
        for request in requests {
            let data = try JSONEncoder().encode(request)
            let back = try JSONDecoder().decode(ControlRequest.self, from: data)
            switch (request, back) {
            case (.scheduleWake(let a), .scheduleWake(let b)): #expect(a == b)
            case (.cancelWake(let a), .cancelWake(let b)): #expect(a == b)
            default: Issue.record("\(request) decoded as \(back)")
            }
        }
    }

    @Test("A request an older daemon has never seen fails to decode rather than misreading")
    func unknownCaseIsRejected() {
        // What an old helper does with the new requests: no decode, so it answers
        // "unrecognized request" and the app switches the radios off at sleep instead.
        let json = #"{"bookTheMoon":{"seconds":300}}"#
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(ControlRequest.self, from: Data(json.utf8))
        }
    }
}
