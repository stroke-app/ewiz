import Foundation

/// Easing curves for the app's animations.
///
/// Every animation here advances in discrete frames — a menu-bar tick, a morph step —
/// and interpolating linearly between them is what makes an animation read as
/// mechanical: constant velocity is a thing software does, not a thing objects do. Run
/// the normalised progress through one of these first and the same number of frames
/// reads as movement instead.
///
/// The built-in curves are deliberately not used: `easeInOut` is too weak to notice at
/// 200ms, and `easeIn` is wrong for anything appearing — it withholds motion at exactly
/// the moment attention is highest, which reads as lag however short the duration is.
public enum Easing {

    /// Strong ease-out — `cubic-bezier(0.23, 1, 0.32, 1)`. The default for anything
    /// arriving, changing state, or otherwise responding to something that just happened:
    /// almost all of the distance is covered immediately, then it settles.
    public static func outStrong(_ t: Double) -> Double {
        bezier(t, 0.23, 1, 0.32, 1)
    }

    /// Strong ease-in-out — `cubic-bezier(0.77, 0, 0.175, 1)`. For something travelling
    /// across the screen, where both ends should be gentle.
    public static func inOutStrong(_ t: Double) -> Double {
        bezier(t, 0.77, 0, 0.175, 1)
    }

    /// Quintic ease-out. Sharper than `outStrong` at the start and far flatter at the end.
    ///
    /// For dissipation rather than arrival: a pressure wave, a ripple, anything spending
    /// energy against a medium. Those cover most of their distance in the first fifth of
    /// their life and then crawl, which no bezier tuned for *arriving somewhere* gets right
    /// — an arrival curve decelerates into a target, and a dissipating front has no target
    /// to decelerate into. It just runs out.
    public static func outQuint(_ t: Double) -> Double {
        let c = clamp(t)
        return 1 - pow(1 - c, 5)
    }

    /// Ease-out that overshoots and settles back: a spring without the solver.
    ///
    /// For something small arriving, where the overshoot is what makes it read as an
    /// object with weight rather than a fade. 1.7 peaks about 10% past the target.
    public static func outBack(_ t: Double, overshoot: Double = 1.70158) -> Double {
        let c = clamp(t) - 1
        return 1 + (overshoot + 1) * c * c * c + overshoot * c * c
    }

    /// Plain ease-out, for when `outStrong` is too abrupt for a long, gentle sweep.
    public static func outCubic(_ t: Double) -> Double {
        let c = clamp(t)
        return 1 - pow(1 - c, 3)
    }

    /// Progress of a cubic Bézier timing function with the usual fixed endpoints
    /// (0,0) and (1,1). Solves x(s) = t by Newton's method — a handful of iterations
    /// is exact enough for animation, and it's the same maths a browser runs for
    /// `cubic-bezier()`.
    public static func bezier(_ t: Double, _ p1x: Double, _ p1y: Double,
                             _ p2x: Double, _ p2y: Double) -> Double {
        let x = clamp(t)
        guard x > 0, x < 1 else { return x }

        func curve(_ s: Double, _ a: Double, _ b: Double) -> Double {
            // Expanded cubic with P0 = 0, P3 = 1.
            let c = 3 * a
            let bb = 3 * (b - a) - c
            let aa = 1 - c - bb
            return ((aa * s + bb) * s + c) * s
        }
        func slope(_ s: Double, _ a: Double, _ b: Double) -> Double {
            let c = 3 * a
            let bb = 3 * (b - a) - c
            let aa = 1 - c - bb
            return (3 * aa * s + 2 * bb) * s + c
        }

        var s = x
        for _ in 0..<8 {
            let error = curve(s, p1x, p2x) - x
            if abs(error) < 1e-5 { break }
            let d = slope(s, p1x, p2x)
            if abs(d) < 1e-6 { break }
            s -= error / d
        }
        return curve(s, p1y, p2y)
    }

    private static func clamp(_ t: Double) -> Double { max(0, min(1, t)) }
}
