import Testing
import Foundation
@testable import EWizKit

struct RestAdvisorTests {
    let now = Date(timeIntervalSince1970: 1_000_000_000)
    let day: TimeInterval = 86_400

    // MARK: isDue

    @Test func notDueBelowThreshold() {
        #expect(RestAdvisor.isDue(uptime: 6 * day, now: now, snoozeUntil: nil) == false)
    }

    @Test func dueAtThreshold() {
        #expect(RestAdvisor.isDue(uptime: 7 * day, now: now, snoozeUntil: nil))
    }

    @Test func dueWellPastThreshold() {
        #expect(RestAdvisor.isDue(uptime: 20 * day, now: now, snoozeUntil: nil))
    }

    @Test func suppressedWhileSnoozed() {
        let snooze = now.addingTimeInterval(2 * day)
        #expect(RestAdvisor.isDue(uptime: 10 * day, now: now, snoozeUntil: snooze) == false)
    }

    @Test func dueAgainAfterSnoozeExpires() {
        let snooze = now.addingTimeInterval(-day)   // snooze ended yesterday
        #expect(RestAdvisor.isDue(uptime: 10 * day, now: now, snoozeUntil: snooze))
    }

    // MARK: shouldNotify

    @Test func notifiesWhenNeverNotified() {
        #expect(RestAdvisor.shouldNotify(now: now, lastNotifiedAt: nil))
    }

    @Test func throttlesRecentNotification() {
        let last = now.addingTimeInterval(-day)   // 1 day ago, interval is 3
        #expect(RestAdvisor.shouldNotify(now: now, lastNotifiedAt: last) == false)
    }

    @Test func notifiesAfterInterval() {
        let last = now.addingTimeInterval(-4 * day)
        #expect(RestAdvisor.shouldNotify(now: now, lastNotifiedAt: last))
    }
}
