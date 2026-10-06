import SwiftUI

/// The battery mark: a body, a level, and — when asked for — a bolt cut out of both.
///
/// It replaces an icon-font glyph that drew a two-segment body, a terminal *and* a bolt
/// inside 26 points. At that size the bolt's strokes landed on the body's, and the result
/// was a dense little knot of lines that said "charging" and nothing else — no level, and
/// barely a battery.
///
/// Two things fix it. The bolt is a *hole*, not another stroke: the gap around it is
/// punched straight through the fill and the outline, so it reads at any level, over any
/// background, without inventing a second colour to outline it with. And the body carries
/// the actual charge as fill, so the mark is worth the space it takes — the same
/// information the number beside it gives, in the shape people already know.
struct BatteryGlyph: View {
    let percentage: Int
    /// Whether to knock the bolt out of the body.
    ///
    /// Not the same question as "is it charging". While current is actually flowing the
    /// level itself moves, and motion says charging better than a static mark ever did —
    /// a bolt there is a second voice saying the same thing over the top. The bolt earns
    /// its place in the state that has no motion to speak for it: on the adapter, holding,
    /// not taking a charge.
    let bolt: Bool
    var color: Color = .primary
    /// Body width. Every other measurement derives from it, so the parts can't drift out
    /// of proportion when this is set to 27 in one place and 40 in another.
    var width: CGFloat = 27

    var body: some View {
        let h = (width * 0.55).rounded()
        let stroke = max(1.2, width * 0.058)
        // Inner radius = outer radius − the gap, or the fill's corners run at a different
        // rate to the body's and the gap visibly pinches at each end.
        let radius = h * 0.32
        let gap = stroke + max(0.9, width * 0.038)
        let frac = max(0, min(1, CGFloat(percentage) / 100))
        // The knockout is a stroke centred on the bolt, so the hole it cuts is the bolt
        // plus half that width on every side. Size the bolt from what's left inside the
        // outline, not from the body height, or the hole eats the top and bottom rails and
        // the battery comes apart.
        let knockout = max(1.4, width * 0.062)
        let boltH = min(h * 0.60, h - stroke * 2 - knockout - width * 0.04)
        // Chassis (body + terminal) sits at reduced opacity so the level, not the
        // container, is the thing the eye lands on.
        let chassis = color.opacity(0.5)

        HStack(spacing: max(1, width * 0.05)) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(chassis, lineWidth: stroke)
                RoundedRectangle(cornerRadius: max(1, radius - gap), style: .continuous)
                    .fill(color)
                    .frame(width: max(stroke, (width - gap * 2) * frac), height: h - gap * 2)
                    .padding(.leading, gap)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: percentage)
            }
            .frame(width: width, height: h)
            .overlay {
                if bolt {
                    // Stroked, not filled: the stroke *is* the clearance, and it cuts the
                    // outline as well as the fill so the bolt never has a line running
                    // through it.
                    //
                    // Round joins are load-bearing. A bolt's tips are acute, and the
                    // default miter join runs a spike out of each one for as far as the
                    // miter limit allows — which is how a hole sized to sit inside the
                    // body ends up slicing through the top and bottom rails.
                    Bolt().stroke(Color.black,
                                  style: StrokeStyle(lineWidth: knockout, lineJoin: .round))
                        .frame(width: boltH * 0.62, height: boltH)
                        .blendMode(.destinationOut)
                }
            }
            // Isolates the knockout to this subtree. Without it `destinationOut` punches
            // through whatever the glyph happens to be sitting on.
            .compositingGroup()
            .overlay {
                if bolt {
                    Bolt().fill(color).frame(width: boltH * 0.62, height: boltH)
                }
            }

            RoundedRectangle(cornerRadius: max(0.5, width * 0.028), style: .continuous)
                .fill(chassis)
                .frame(width: max(1.5, width * 0.06), height: h * 0.36)
        }
        .animation(.easeInOut(duration: DS.Duration.state), value: bolt)
    }
}

/// A lightning bolt in normalised coordinates, so one path serves every size.
private struct Bolt: Shape {
    func path(in rect: CGRect) -> Path {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: at(0.66, 0))
        path.addLine(to: at(0, 0.58))
        path.addLine(to: at(0.36, 0.58))
        path.addLine(to: at(0.30, 1))
        path.addLine(to: at(1, 0.42))
        path.addLine(to: at(0.64, 0.42))
        path.closeSubpath()
        return path
    }
}
