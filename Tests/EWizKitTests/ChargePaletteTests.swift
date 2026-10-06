import Testing
import Foundation
@testable import EWizKit

/// The charge ramp makes claims that are cheap to assert and expensive to notice
/// breaking: it reads red at empty and green at full, it never leaves the sRGB gamut, it
/// never turns grey at the crossover, and it climbs monotonically in perceived lightness.
/// All of them are properties of the *stops*, so a well-meant tweak to one of them is
/// exactly what these tests exist to catch.
@Suite struct ChargePaletteTests {

    /// Every 1% of charge, plus the boundaries.
    private var ramp: [(level: Double, color: OKLab)] {
        (0...100).map { (Double($0) / 100, ChargePalette.charging(Double($0) / 100)) }
    }

    @Test func neverWashesOutAtTheCrossover() {
        // Red → green in a naive space passes through mud. Interpolating in Lab keeps the
        // path through real oranges and yellows, and the way to prove that is chroma: no
        // level on the ramp may fall to where a hue stops being nameable.
        for (level, color) in ramp {
            #expect(color.chroma > 0.10,
                    "level \(level) has washed out to chroma \(color.chroma)")
        }
    }

    @Test func staysInGamut() {
        // `sRGB` gamut-maps, so asserting on its output proves nothing. The real claim is
        // that it never had to: a stop needing rescue is a stop whose authored chroma is
        // a lie about what will be drawn.
        for (level, color) in ramp {
            #expect(color.isDisplayable, "level \(level) is outside sRGB before mapping")
        }
    }

    @Test func brightensMonotonically() {
        // A meter whose colour dips in lightness partway up has a dark band across it
        // that means nothing.
        for pair in zip(ramp, ramp.dropFirst()) {
            #expect(pair.1.color.L >= pair.0.color.L - 1e-9,
                    "lightness fell between \(pair.0.level) and \(pair.1.level)")
        }
    }

    @Test func redAtEmptyGreenAtFull() {
        // a > 0 is red, a < 0 is green. The whole point of the ramp.
        #expect(ChargePalette.charging(0).a > 0.10)
        #expect(ChargePalette.charging(1).a < -0.05)
        #expect(ChargePalette.charging(0).L < ChargePalette.charging(1).L)
        // And red has to still be red where it matters, not already turning orange: at
        // 15% the hue may not have left the red end.
        #expect(ChargePalette.charging(0.15).a > 0.10)
    }

    @Test func clampsOutOfRangeLevels() {
        #expect(ChargePalette.charging(-3) == ChargePalette.charging(0))
        #expect(ChargePalette.charging(42) == ChargePalette.charging(1))
    }

    @Test func legibleVariantWorksOnBothAppearances() {
        // Pinned mid-lightness, so it has contrast against a white menu bar and a black
        // one. Relative luminance either side of the extremes is the crude check that
        // matters: nothing near 0, nothing near 1.
        for level in stride(from: 0.0, through: 1.0, by: 0.05) {
            let (r, g, b) = ChargePalette.legible(level).sRGB
            let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
            #expect(luminance > 0.12 && luminance < 0.88,
                    "menu-bar tint at \(level) has luminance \(luminance)")
        }
    }

    @Test func chartSeriesColoursAreTellableApart() {
        // The power-split bar puts these two side by side, sometimes only 10pt tall. If
        // they ever drift together the chart stops carrying information — and they're
        // authored independently, so nothing else would catch it.
        let a = ChargePalette.accent, b = ChargePalette.systemDraw
        let distance = ((a.L - b.L) * (a.L - b.L)
                        + (a.a - b.a) * (a.a - b.a)
                        + (a.b - b.b) * (a.b - b.b)).squareRoot()
        #expect(distance > 0.10, "series colours are only \(distance) apart in OKLab")
        // Green against blue: a < 0 is green, b < 0 is blue.
        #expect(a.a < 0 && b.b < 0)
        #expect(a.isDisplayable && b.isDisplayable)
    }

    @Test func accentIsGreen() {
        // Everything that means "charging" routes through this, so it carries the same
        // promise the top of the ramp does.
        let accent = ChargePalette.accent
        #expect(accent.a < -0.05 && accent.chroma > 0.05)
    }

    @Test func roundTripsThroughLinearSRGB() {
        // Guards the Ottosson matrices against a transcription slip: mid grey in, mid
        // grey out, with a > 0.5 lightness and no colour cast.
        let grey = OKLab(l: 0.6, chroma: 0, hue: 0)
        let (r, g, b) = grey.sRGB
        #expect(abs(r - g) < 1e-6 && abs(g - b) < 1e-6)
        #expect(r > 0.5 && r < 0.65)
    }
}
