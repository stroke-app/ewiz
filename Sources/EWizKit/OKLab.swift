import Foundation

/// Perceptual colour, for ramps that step evenly to the eye rather than evenly in RGB.
///
/// Two problems this solves, both of which show up the moment a charge level drives a
/// colour:
///
///   - sRGB is not perceptually uniform. Halfway between two sRGB colours is not the
///     colour that looks halfway, so a meter built on it has bright and dull stretches
///     that don't correspond to anything about the battery.
///   - Interpolating in a *hue* space (HSL, HSV, OKLCH) walks around the hue circle. A
///     ramp from amber to ice-white has to pass through every hue in between, which is
///     exactly how a battery ramp ends up going green in the middle.
///
/// OKLab fixes both. It's perceptually uniform, and because it's rectangular (a/b rather
/// than chroma/hue) the straight line between two near-neutral colours passes *through*
/// neutral instead of detouring around the wheel. Every mix here is done in Lab for that
/// reason; hue only ever appears at the point where a stop is authored.
///
/// Reference: Björn Ottosson, "A perceptual color space for image processing" (2020).
public struct OKLab: Sendable, Equatable {
    /// Perceptual lightness, 0 (black) … 1 (white).
    public var L: Double
    /// Green (−) ↔ red (+).
    public var a: Double
    /// Blue (−) ↔ yellow (+).
    public var b: Double

    public init(L: Double, a: Double, b: Double) {
        self.L = L; self.a = a; self.b = b
    }

    /// Author a colour the readable way — lightness, chroma, hue in degrees — and store
    /// it as Lab so everything downstream mixes in the rectangular space.
    public init(l: Double, chroma: Double, hue: Double) {
        let radians = hue * .pi / 180
        self.init(L: l, a: chroma * cos(radians), b: chroma * sin(radians))
    }

    public var chroma: Double { (a * a + b * b).squareRoot() }

    /// Straight line in Lab. `t` outside 0…1 is clamped: a ramp should never extrapolate
    /// past its own endpoints and invent a colour nobody chose.
    public func mix(_ other: OKLab, _ t: Double) -> OKLab {
        let p = max(0, min(1, t))
        return OKLab(L: L + (other.L - L) * p,
                     a: a + (other.a - a) * p,
                     b: b + (other.b - b) * p)
    }

    /// Same colour, scaled chroma. Used for gamut mapping and for the desaturated
    /// variants (unplugged, unlit dots) that should sit on the same ramp.
    public func withChroma(scale: Double) -> OKLab {
        OKLab(L: L, a: a * scale, b: b * scale)
    }

    public func withLightness(_ l: Double) -> OKLab {
        OKLab(L: l, a: a, b: b)
    }

    // MARK: - sRGB

    /// Gamma-encoded sRGB, each channel 0…1, gamut-mapped.
    ///
    /// Out-of-gamut colours are brought in by reducing chroma at constant lightness and
    /// hue, not by clipping channels. Clipping is what turns a slightly-too-saturated
    /// amber into a different hue: it shears one channel and leaves the others, so the
    /// ramp visibly kinks at the point it leaves the gamut. Desaturating keeps the hue
    /// and only gives up the thing that couldn't be shown anyway.
    public var sRGB: (r: Double, g: Double, b: Double) {
        // Binary search the largest chroma scale that still fits. Eight steps lands
        // within ~0.4% of the boundary, well under a perceptible step.
        var scale = 1.0
        if !Self.inGamut(linear) {
            var lo = 0.0, hi = 1.0
            for _ in 0..<8 {
                let mid = (lo + hi) / 2
                if Self.inGamut(withChroma(scale: mid).linear) { lo = mid } else { hi = mid }
            }
            scale = lo
        }
        let (r, g, b) = withChroma(scale: scale).linear
        return (Self.encode(r), Self.encode(g), Self.encode(b))
    }

    /// Whether this colour can be shown on an sRGB display without being desaturated
    /// first. Worth asserting about authored stops: `sRGB` will quietly rescue an
    /// out-of-gamut one, which means the colour you get is not the colour you wrote.
    public var isDisplayable: Bool { Self.inGamut(linear) }

    /// The same colour with chroma pulled in until sRGB can actually show it.
    ///
    /// Lightness and hue carry the meaning — how full, and whether that's good news — so
    /// chroma is the only part allowed to give. Bisection rather than a formula: the sRGB
    /// boundary in OKLab has no closed form, and 20 halvings lands inside a thousandth of
    /// a chroma unit, far under anything visible. It runs when a colour is authored, not
    /// per pixel.
    ///
    /// The alternative is letting `sRGB`'s own clamping handle it, which works but leaves
    /// the value here disagreeing with what gets drawn — and then every assertion about
    /// the palette is an assertion about a colour nobody sees.
    public func gamutClamped() -> OKLab {
        guard !isDisplayable else { return self }
        let angle = atan2(b, a)
        var low = 0.0, high = chroma
        for _ in 0..<20 {
            let mid = (low + high) / 2
            let probe = OKLab(L: L, a: cos(angle) * mid, b: sin(angle) * mid)
            if probe.isDisplayable { low = mid } else { high = mid }
        }
        return OKLab(L: L, a: cos(angle) * low, b: sin(angle) * low)
    }

    /// OKLab → linear sRGB (Ottosson's inverse matrices).
    private var linear: (Double, Double, Double) {
        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b
        let l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_
        return ( 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    }

    /// A hair of slack, so a colour that is in gamut but lands on 1.0000001 from
    /// floating-point error isn't needlessly desaturated.
    private static func inGamut(_ rgb: (Double, Double, Double)) -> Bool {
        let e = 1e-4
        return rgb.0 >= -e && rgb.0 <= 1 + e
            && rgb.1 >= -e && rgb.1 <= 1 + e
            && rgb.2 >= -e && rgb.2 <= 1 + e
    }

    private static func encode(_ v: Double) -> Double {
        let c = max(0, min(1, v))
        return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
    }
}

/// The colour a charge level is drawn in — everywhere, so the menu bar, the overlay and
/// the charge-complete flash agree.
///
/// Red, yellow, green — the reading every gauge, every fuel meter and every battery a
/// person has ever looked at already uses. It needs no legend, which is the whole argument
/// for it: a colour that has to be taught is a colour doing no work.
///
/// What matters is *where* the ramp is when, and that it stays honest between the three
/// names. Authored in OKLab and interpolated as a straight Lab line, so the path from red
/// to green runs through real oranges and yellows instead of the grey-brown a naive sRGB
/// lerp gives you at the crossover. Lightness climbs the whole way, so no level ever draws
/// as a dark band across a meter.
public enum ChargePalette {

    /// level → colour, low to full. Red holds well past the point of panic, because a
    /// battery at 14% is still a battery at 14%; yellow owns the middle; green arrives
    /// only once there's genuinely nothing to think about.
    private static let stops: [(level: Double, color: OKLab)] = [
        (0.00, OKLab(l: 0.630, chroma: 0.175, hue: 27)),   // red — the reserve
        (0.15, OKLab(l: 0.660, chroma: 0.170, hue: 32)),   // still red at a glance
        (0.32, OKLab(l: 0.760, chroma: 0.155, hue: 62)),   // amber
        (0.48, OKLab(l: 0.830, chroma: 0.145, hue: 100)),  // yellow
        (0.62, OKLab(l: 0.835, chroma: 0.150, hue: 140)),  // green
        (1.00, OKLab(l: 0.840, chroma: 0.160, hue: 146))   // green — full
    ]
    // Green lands at 62%, not at 90%. A ramp that only turns green near the top spends
    // most of a normal day in the yellow it reserves for "watch this", and a warning that
    // is on all the time is not a warning. Above 62% there is nothing to do about the
    // battery, which is exactly what green is for.
    // Chroma is capped by what sRGB actually holds at each lightness, not by taste: yellow
    // near L 0.83 runs out at roughly 0.17, and authoring past that would hand `sRGB` an
    // out-of-gamut colour to rescue — and the rescued colour is not the one written here.
    // `ChargePaletteTests.staysInGamut` holds the whole ramp to that.

    /// The colour standing for `level` (0…1) on the ramp.
    public static func charging(_ level: Double) -> OKLab {
        let x = max(0, min(1, level))
        for i in 1..<stops.count where x <= stops[i].level {
            let lower = stops[i - 1], upper = stops[i]
            let span = upper.level - lower.level
            return lower.color.mix(upper.color, span > 0 ? (x - lower.level) / span : 0)
        }
        return stops[stops.count - 1].color
    }

    /// The same ramp, made legible against an unknown background.
    ///
    /// The full-brightness ramp is authored for a dimmed full-screen overlay, and its top
    /// end is light enough to disappear against a white menu bar or a light popover.
    /// Rather than resolve the appearance and cache two variants, the ramp is pinned to a
    /// mid lightness that has contrast against both white and black, and the chroma it
    /// gives up in the process is handed back doubled so the tint still reads as a colour
    /// and not as grey — capped by the gamut wherever it asks for more than sRGB holds.
    /// Hue, the part that carries the meaning, is untouched either way.
    public static func legible(_ level: Double) -> OKLab {
        charging(level).withChroma(scale: 1.45).withLightness(0.66).gamutClamped()
    }

    /// One stable colour meaning "charging", for places showing the *fact* rather than a
    /// level: chart series, legends, status glyphs.
    ///
    /// Fixed, not derived from the live percentage. A series colour has to hold still —
    /// if it tracked the charge level, a legend swatch would drift out of agreement with
    /// the bar it labels while you watched. Taken from the top of the ramp, so "power
    /// going into the battery" is the same green that a healthy battery is drawn in.
    public static let accent = legible(0.85)

    /// Its partner in the power-split chart: what the machine itself is drawing.
    ///
    /// Blue against `accent`'s green. Adjacent hues can't carry a category distinction in
    /// a 10pt-tall bar; these two are separated by hue *and* by temperature, and neither
    /// is the red the ramp reserves for trouble.
    public static let systemDraw = OKLab(l: 0.66, chroma: 0.085, hue: 250)

    /// Unplugged: off the ramp entirely, and almost colourless. Losing power is not a
    /// level, so giving it a level's colour would be a lie — this is the same cool
    /// neutral whatever the battery reads.
    public static let unplugged = OKLab(l: 0.82, chroma: 0.010, hue: 250)

    /// The unlit part of a meter. Dim and hueless so the boundary between filled and
    /// empty survives being drawn over a photograph.
    public static let unlit = OKLab(l: 0.90, chroma: 0.0, hue: 0)
}
