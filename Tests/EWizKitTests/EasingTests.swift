import Testing
import Foundation
@testable import EWizKit

@Suite("Easing")
struct EasingTests {

    private let curves: [(String, (Double) -> Double)] = [
        ("outStrong", Easing.outStrong),
        ("inOutStrong", Easing.inOutStrong),
        ("outCubic", Easing.outCubic),
        ("outQuint", Easing.outQuint),
    ]

    @Test func everyCurveStartsAtZeroAndEndsAtOne() {
        for (name, f) in curves {
            #expect(abs(f(0) - 0) < 1e-6, "\(name) doesn't start at 0")
            #expect(abs(f(1) - 1) < 1e-6, "\(name) doesn't end at 1")
        }
    }

    @Test func everyCurveIsMonotonic() {
        // A timing function that ever goes backwards makes an animation stutter, and it's
        // the kind of thing a hand-tuned bezier can do without anyone noticing on a
        // 200ms transition.
        for (name, f) in curves {
            var previous = f(0)
            for step in 1...200 {
                let value = f(Double(step) / 200)
                #expect(value >= previous - 1e-9, "\(name) reverses at \(step)/200")
                previous = value
            }
        }
    }

    @Test func everyCurveClampsOutsideItsDomain() {
        for (name, f) in curves {
            #expect(f(-1) == 0, "\(name) doesn't clamp below 0")
            #expect(f(2) == 1, "\(name) doesn't clamp above 1")
        }
    }

    // MARK: - outQuint, the dissipation curve

    @Test func outQuintSpendsMostOfItsTravelImmediately() {
        // The property the ring animation depends on: a pressure wave covers most of its
        // distance early and crawls at the edge. A fifth of the way through it should
        // already be most of the way there.
        #expect(Easing.outQuint(0.2) > 0.65)
        #expect(Easing.outQuint(0.5) > 0.95)
    }

    @Test func outQuintIsFlatterAtTheEndThanTheArrivalCurves() {
        // This is what makes it right for something running out of energy rather than
        // arriving somewhere. Near the end it has to be barely moving — more so than the
        // curves tuned for landing on a target.
        let tail = 0.9
        let quintRemaining = 1 - Easing.outQuint(tail)
        let cubicRemaining = 1 - Easing.outCubic(tail)
        #expect(quintRemaining < cubicRemaining)
    }

    @Test func outQuintOvertakesTheArrivalCurveEarly() {
        #expect(Easing.outQuint(0.15) > Easing.outCubic(0.15))
    }

    // MARK: - The bezier solver

    @Test func theSolverMatchesAKnownBezier() {
        // ease-in-out, cubic-bezier(0.42, 0, 0.58, 1), is symmetric about the midpoint.
        let mid = Easing.bezier(0.5, 0.42, 0, 0.58, 1)
        #expect(abs(mid - 0.5) < 1e-3)
    }

    @Test func linearBezierIsTheIdentity() {
        for step in 0...10 {
            let t = Double(step) / 10
            #expect(abs(Easing.bezier(t, 0.25, 0.25, 0.75, 0.75) - t) < 1e-3)
        }
    }
}
