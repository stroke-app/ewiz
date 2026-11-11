import Testing
import Foundation
@testable import EWizKit

@Suite("Lid history rollups")
struct LidHistoryTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    @Test func overnightCloseSplitsAcrossMidnightAndCreditsDrainOnce() {
        // 22:00 → 08:00 on battery, 3 points lost: 2 h on the 10th, 8 h on the 11th.
        let s = LidSession(closedAt: at(10, 22), closeCharge: 80, openedAt: at(11, 8), openCharge: 77,
                           pluggedInAtClose: false, pluggedInAtOpen: false)
        let days = SessionAnalysis.attachingLidSessions([], [s], calendar: cal)
        #expect(days.count == 2)
        let eleventh = days.first { $0.day == at(11, 0) }!
        let tenth = days.first { $0.day == at(10, 0) }!
        #expect(eleventh.lidClosedTime == 8 * 3600)
        #expect(tenth.lidClosedTime == 2 * 3600)
        #expect(eleventh.lidDropPct == 3)
        #expect(tenth.lidDropPct == 0)
    }

    @Test func aCloseOnTheChargerAddsTimeButNoDrain() {
        let s = LidSession(closedAt: at(11, 10), closeCharge: 51, openedAt: at(11, 18), openCharge: 80)
        let days = SessionAnalysis.attachingLidSessions([], [s], calendar: cal)
        let day = try! #require(days.first)
        #expect(day.lidClosedTime == 8 * 3600.0)
        #expect(day.lidDropPct == 0)
    }

    @Test func overviewSeparatesAwakeDrainFromAsleepDrain() {
        let span = ChargeSpan(kind: .discharging, startAt: at(11, 9), endAt: at(11, 11),
                              startPct: 80, endPct: 60)
        let lid = LidSession(closedAt: at(11, 22), closeCharge: 60, openedAt: at(12, 6), openCharge: 59,
                             pluggedInAtClose: false, pluggedInAtOpen: false)
        let charged = LidSession(closedAt: at(11, 12), closeCharge: 60, openedAt: at(11, 13), openCharge: 70)
        let o = HistoryOverview.make(spans: [span], lidSessions: [lid, charged])
        #expect(o.drainPerHour == 10)
        #expect(o.lidCloses == 2)
        #expect(o.lidBatteryTime == 8 * 3600)
        #expect(o.lidBatteryDropPct == 1)
        #expect(abs((o.lidDrainPerHour ?? 0) - 0.125) < 0.0001)
    }

    @Test func awakeDrainLeavesOutTimeTheLidWasShut() {
        // A 4 h battery run with the lid shut for 2 h of it: 2 h awake.
        let span = ChargeSpan(kind: .discharging, startAt: at(11, 9), endAt: at(11, 13),
                              startPct: 80, endPct: 70)
        let lid = LidSession(closedAt: at(11, 10), closeCharge: 78, openedAt: at(11, 12), openCharge: 77,
                             pluggedInAtClose: false, pluggedInAtOpen: false)
        let o = HistoryOverview.make(spans: [span], lidSessions: [lid])
        #expect(o.batteryTime == 2 * 3600)
    }
}
