import Testing
import Foundation
@testable import EWizKit

/// Fixed UTC calendar so weekday/minute maths doesn't depend on the machine's zone.
private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

/// 2026-08-03 is a Monday, so `day: 3 + n` walks Monday…Sunday.
private func date(day: Int, hour: Int, minute: Int = 0) -> Date {
    cal.date(from: DateComponents(year: 2026, month: 8, day: day,
                                 hour: hour, minute: minute))!
}

@Suite struct AwakeScheduleTests {
    @Test func holdsInsideItsWindowOnly() {
        // Weekdays, 09:00 for 9 h → 09:00–18:00.
        let window = AwakeSchedule(days: .weekdays, startMinute: 9 * 60,
                                   durationMinutes: 9 * 60)
        #expect(window.isActive(at: date(day: 3, hour: 9), calendar: cal))
        #expect(window.isActive(at: date(day: 3, hour: 17, minute: 59), calendar: cal))
        #expect(!window.isActive(at: date(day: 3, hour: 8, minute: 59), calendar: cal))
        #expect(!window.isActive(at: date(day: 3, hour: 18), calendar: cal))   // end is exclusive
        #expect(!window.isActive(at: date(day: 8, hour: 12), calendar: cal))   // Saturday
    }

    @Test func disabledWindowNeverHolds() {
        let window = AwakeSchedule(enabled: false, days: .everyday,
                                   startMinute: 0, durationMinutes: 1440)
        #expect(!window.isActive(at: date(day: 3, hour: 12), calendar: cal))
    }

    @Test func windowWrappingMidnightBelongsToItsStartDay() {
        // Friday 22:00 for 6 h → into Saturday 04:00.
        let window = AwakeSchedule(days: .fri, startMinute: 22 * 60,
                                   durationMinutes: 6 * 60)
        #expect(window.isActive(at: date(day: 7, hour: 23), calendar: cal))          // Fri night
        #expect(window.isActive(at: date(day: 8, hour: 3, minute: 59), calendar: cal)) // Sat tail
        #expect(!window.isActive(at: date(day: 8, hour: 4), calendar: cal))
        #expect(!window.isActive(at: date(day: 7, hour: 3), calendar: cal))          // Fri morning
    }

    @Test func noEnabledWindowsMeansTheToggleAloneDecides() {
        let now = date(day: 3, hour: 3)
        #expect(EWizConfig.keepAwakeWindowOpen([], at: now, calendar: cal))
        let off = AwakeSchedule(enabled: false, days: .everyday,
                                startMinute: 9 * 60, durationMinutes: 60)
        #expect(EWizConfig.keepAwakeWindowOpen([off], at: now, calendar: cal))
    }

    @Test func armedNeedsToggleWindowAndUnexpiredTimer() {
        let window = AwakeSchedule(days: .weekdays, startMinute: 9 * 60,
                                   durationMinutes: 9 * 60)
        let inside = date(day: 3, hour: 12)
        let outside = date(day: 3, hour: 20)

        #expect(EWizConfig.keepAwakeArmed(enabled: true, until: nil, schedules: [window],
                                              at: inside, calendar: cal))
        #expect(!EWizConfig.keepAwakeArmed(enabled: true, until: nil, schedules: [window],
                                               at: outside, calendar: cal))
        #expect(!EWizConfig.keepAwakeArmed(enabled: false, until: nil, schedules: [window],
                                               at: inside, calendar: cal))
        // An elapsed timer wins over an open window.
        #expect(!EWizConfig.keepAwakeArmed(enabled: true, until: date(day: 3, hour: 11),
                                               schedules: [window], at: inside, calendar: cal))
        #expect(EWizConfig.keepAwakeArmed(enabled: true, until: date(day: 3, hour: 13),
                                              schedules: [window], at: inside, calendar: cal))
    }

    @Test func configRoundTripsWindowsAndTimer() throws {
        let deadline = date(day: 3, hour: 18)
        var cfg = EWizConfig()
        cfg.keepAwake = true
        cfg.keepAwakeSchedules = [AwakeSchedule(label: "Work hours")]
        cfg.keepAwakeUntil = deadline

        let decoded = try JSONDecoder().decode(
            EWizConfig.self, from: try JSONEncoder().encode(cfg))
        #expect(decoded.keepAwakeSchedules.map(\.label) == ["Work hours"])
        #expect(decoded.keepAwakeUntil == deadline)
    }

    @Test func configsWrittenBeforeSchedulingStillDecode() throws {
        let legacy = #"{"chargeLimit":80,"keepAwake":true}"#.data(using: .utf8)!
        let cfg = try JSONDecoder().decode(EWizConfig.self, from: legacy)
        #expect(cfg.keepAwakeSchedules.isEmpty)
        #expect(cfg.keepAwakeUntil == nil)
        // No windows and no timer: the toggle alone still holds.
        #expect(cfg.keepAwakeArmed(at: date(day: 3, hour: 4), calendar: cal))
    }
}
