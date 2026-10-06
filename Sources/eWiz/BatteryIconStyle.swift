import AppKit
import EWizKit

/// Selectable menu-bar battery glyph styles; all fill to the real charge except
/// `bars`, which is intentionally stepped.
enum BatteryIconStyle: String, CaseIterable, Identifiable, Codable {
    case rounded   // HugeIcons squircle, smooth proportional fill
    case bars      // HugeIcons squircle with discrete level bars
    case classic   // traditional horizontal battery, smooth fill
    case minimal   // clean capsule/pill, no terminal, smooth fill
    case pixel     // chunky 8-bit battery; the fill sweeps upward while charging
    case vertical  // upright battery, fill rises from the bottom
    case ring      // circular gauge; the arc tracks the charge
    case segments  // stepped bars, tallest last, like a signal meter
    case dot       // a circle filling like liquid — the quietest of the set
    case wave      // battery filled with liquid whose surface actually moves
    case boltFill  // the lightning bolt itself is the gauge
    case gauge     // half-circle dial with a travelling head

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rounded:  return "Rounded"
        case .bars:     return "Bars"
        case .classic:  return "Classic"
        case .minimal:  return "Minimal"
        case .pixel:    return "Pixel"
        case .vertical: return "Upright"
        case .ring:     return "Ring"
        case .segments: return "Meter"
        case .dot:      return "Dot"
        case .wave:     return "Wave"
        case .boltFill: return "Bolt"
        case .gauge:    return "Dial"
        }
    }

    /// True for styles whose look changes frame to frame even on battery, so the menu
    /// bar can tick for them instead of only while charging.
    var animatesOnBattery: Bool { self == .wave }

    /// The drawing box, in SVG viewBox units. The five horizontal styles share one box
    /// so switching between them never shifts the menu-bar layout; the upright and
    /// round styles are narrower by nature and get their own, which is a deliberate
    /// choice the user makes once rather than something that moves while they work.
    ///
    /// Every box is sized so the glyph lands at a sensible width at the menu bar's
    /// 14pt: a tall, narrow box scales *down* to fit the height and leaves a sliver
    /// nobody can read, so the upright battery is deliberately stout rather than
    /// true-to-life, and the round styles get a nearly square box.
    var viewBox: (x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        switch self {
        case .rounded, .bars, .classic, .minimal, .pixel, .wave:
            return (1.1, 5.1, 21.8, 13.8)
        case .boltFill:  return (6.2, 1.6, 11.6, 20.8)
        case .gauge:     return (1.4, 4.6, 21.2, 15.0)
        case .vertical:  return (5.4, 2.4, 13.2, 17.2)
        case .ring:      return (1.4, 1.4, 21.2, 21.2)
        case .segments:  return (1.8, 5.2, 20.4, 13.6)
        case .dot:       return (2.6, 2.6, 18.8, 18.8)
        }
    }
}

/// A one-off animation of the mark inside the glyph, played when the power state changes.
///
/// One motion each way, whatever the mark: it springs in when something starts (plugged
/// in, charging began or stopped, a hold switched, a charge finished) and drops away when
/// the cable comes out. A mark that pops tells you the menu bar just noticed something;
/// the mark itself tells you what.
enum IconTransition: String {
    /// The current mark grows in from nothing, overshoots a touch and settles.
    case markIn
    /// Unplugged while charging: the bolt shrinks away, accelerating, the way something
    /// pulled out does.
    case markOutBolt
    /// Unplugged while paused: the pause mark goes the same way.
    case markOutPause
}

/// Renders `BatteryIconStyle` into cached `NSImage`s. Drawing is in a 24×24
/// viewBox scaled to the requested height, so it stays crisp at any screen scale.
enum BatteryIconRenderer {
    // HugeIcons battery paths (viewBox 0 0 24 24), taken from @hugeicons/core-free-icons.
    private static let bodyPath = "M2 12C2 9.17157 2 7.75736 2.87868 6.87868C3.75736 6 5.17157 6 8 6H13C15.8284 6 17.2426 6 18.1213 6.87868C19 7.75736 19 9.17157 19 12C19 14.8284 19 16.2426 18.1213 17.1213C17.2426 18 15.8284 18 13 18H8C5.17157 18 3.75736 18 2.87868 17.1213C2 16.2426 2 14.8284 2 12Z"
    private static let terminalPath = "M19 9.5L20.0272 9.6712C20.7085 9.78475 21.0491 9.84152 21.3076 10.0067C21.5618 10.1691 21.7612 10.4044 21.8796 10.6819C22 10.964 22 11.3093 22 12C22 12.6907 22 13.036 21.8796 13.3181C21.7612 13.5956 21.5618 13.8309 21.3076 13.9933C21.0491 14.1585 20.7085 14.2153 20.0272 14.3288L19 14.5"

    private static let stroke: CGFloat = 1.5

    /// How far the fill fades while charging is held. Low enough to be unmistakable at a
    /// glance, high enough that the *level* is still readable — the point of a held battery
    /// is that you can see where it is being held.
    private static let holdFillAlpha: CGFloat = 0.4

    @MainActor private static var cache: [String: NSImage] = [:]
    /// Keys in the order they were first drawn, so the oldest can go when the cache is full.
    @MainActor private static var cacheOrder: [String] = []
    /// Roughly two full animation cycles' worth of distinct frames, across a couple of
    /// charge levels and both tints.
    ///
    /// The cache had no bound at all. Its key carries the charge percentage, the animation
    /// phase, the transition step, the tint and four flags, so a Mac left running draws a new
    /// entry for every combination it passes through and never gives one back — a menu-bar
    /// app quietly accumulating thousands of NSImages over a few days. A cache that never
    /// evicts is a leak with a lookup table in front of it.
    private static let cacheLimit = 192

    /// Menu-bar / preview glyph. `tint` neutral ⇒ template image; a colour ⇒
    /// fixed palette colour. `frame` is a monotonically increasing animation tick;
    /// the cache key stores the *resolved* animation state (fill count, pulse
    /// phase, or blink) so it stays bounded no matter how high the tick counts.
    @MainActor static func image(style: BatteryIconStyle, percentage: Int,
                                 charging: Bool, tint: MenuBarTint,
                                 height: CGFloat = 14, frame: Int = 0,
                                 celebrating: Bool = false,
                                 pluggedIn: Bool = false,
                                 holding: Bool = false,
                                 transition: IconTransition? = nil,
                                 transitionStep: Int = 0,
                                 shake: CGFloat = 0) -> NSImage {
        let pct = max(0, min(100, percentage))
        // Tenths of a unit: plenty for a tremble, and it keeps the cache to a few frames.
        let shake = (shake * 10).rounded() / 10
        let anim: Int
        if celebrating {
            anim = 0                                                        // the check holds still
        } else if charging && style == .pixel {
            anim = pixelFillCount(pct: pct, charging: charging, frame: frame) // sweep step
        } else if charging {
            anim = phase(frame, sweepSteps)                                  // fill sweep
        } else if style.animatesOnBattery {
            anim = phase(frame, sweepSteps)                                  // wave keeps moving
        } else {
            anim = 0
        }
        let key = "\(style.rawValue)|\(pct)|\(charging)|\(celebrating)|\(tint.cacheKey)|\(height)|\(anim)|\(transition?.rawValue ?? "-")\(transitionStep)|\(holding)|\(pluggedIn)|\(shake)"
        if let cached = cache[key] { return cached }

        let color: NSColor = { if case .colored(let c) = tint { return c } else { return .black } }()
        // A finished charge draws full, with the check in it. It used to blink the whole
        // glyph for three seconds as well, which read as a warning rather than a result.
        let effPct = celebrating ? 100 : pct
        let effCharging = celebrating ? false : charging
        let vb = style.viewBox
        let s = height / vb.h
        let size = NSSize(width: vb.w * s, height: vb.h * s)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let cg = NSGraphicsContext.current?.cgContext else { return true }
            // Map the y-down SVG viewBox into the (y-up) image, scaled to `height`.
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: s, y: -s)
            cg.translateBy(x: -vb.x, y: -vb.y)
            if shake != 0 {
                // Shaking: a touch smaller, so the sideways travel stays inside the box
                // rather than clipping the battery's ends.
                let cx = vb.x + vb.w / 2, cy = vb.y + vb.h / 2
                cg.translateBy(x: cx + shake, y: cy)
                cg.scaleBy(x: shakeScale, y: shakeScale)
                cg.translateBy(x: -cx, y: -cy)
            }
            draw(style: style, pct: effPct, charging: effCharging, color: color,
                 frame: frame, celebrating: celebrating,
                 pluggedIn: pluggedIn, holding: holding,
                 transition: transition, transitionStep: transitionStep)
            return true
        }
        image.isTemplate = tint.isNeutral
        remember(image, for: key)
        return image
    }

    /// Store a frame, dropping the oldest quarter when the cache is full.
    ///
    /// A quarter at a time rather than one per insert: evicting singly on every miss turns a
    /// steady stream of new frames into a steady stream of dictionary churn, and the frames
    /// being drawn right now are the ones most likely to be wanted again in a second.
    @MainActor
    private static func remember(_ image: NSImage, for key: String) {
        if cache.count >= cacheLimit {
            for stale in cacheOrder.prefix(cacheLimit / 4) { cache.removeValue(forKey: stale) }
            cacheOrder.removeFirst(min(cacheLimit / 4, cacheOrder.count))
        }
        cache[key] = image
        cacheOrder.append(key)
    }

    // MARK: - Per-style drawing (viewBox coordinates)

    /// The glyph, then the mark cut into it.
    ///
    /// The level goes into a transparency layer, the mark plus a halo around it is erased
    /// from that layer, and the mark is drawn solid in the hole.
    /// Same colour, so without the halo a bolt on a full bar would simply vanish; with it,
    /// the mark reads over a sliver, a full bar or the outline alike, and it survives the
    /// template treatment because macOS tints by alpha and the halo *is* alpha.
    private static func draw(style: BatteryIconStyle, pct: Int, charging: Bool, color: NSColor,
                             frame: Int = 0, celebrating: Bool = false,
                             pluggedIn: Bool = false, holding: Bool = false,
                             transition: IconTransition? = nil,
                             transitionStep: Int = 0) {
        color.setStroke(); color.setFill()
        let frac = CGFloat(pct) / 100
        // While charging the fill rises from the real level towards full and restarts,
        // which is what a charging battery is expected to look like. The level itself
        // still shows: the sweep starts at it, so a glance at the low point reads true.
        let fillFrac = charging ? sweepFrac(frac, frame: frame) : frac
        let mark = mark(pct: pct, charging: charging, pluggedIn: pluggedIn,
                        celebrating: celebrating, transition: transition, step: transitionStep)
        // A pause dims the level behind it. Cut into a full-strength bar, two upright bars
        // read as more level stripes; over a dimmed one they read as a symbol on top.
        let dim = holding || mark?.kind == .pause
        func body(_ part: BodyPart) {
            drawBody(style: style, part: part, frac: frac, fillFrac: fillFrac,
                     charging: charging, holding: dim, frame: frame)
        }

        if style == .pixel {
            drawPixel(pct: pct, charging: charging, frame: frame, holding: holding, mark: mark)
            return
        }
        guard let box = markBox(style), let mark,
              mark.scale > 0.02,
              let cg = NSGraphicsContext.current?.cgContext else {
            body(.outline); body(.level); return
        }

        let path = markPath(mark.kind, in: box, scale: mark.scale)
        let line = box.h * 0.2 * mark.scale          // the check's stroke
        // Only the level is cut. Cutting the outline too broke the battery's edge wherever
        // the halo reached it, and a body with gaps in it reads as damaged, not charging.
        body(.outline)
        cg.beginTransparencyLayer(auxiliaryInfo: nil)
        body(.level)
        cg.saveGState()
        cg.setBlendMode(.destinationOut)             // erases only this layer's own pixels
        paint(path, mark.kind, line: line, widen: markHalo * 2 * mark.scale)
        cg.restoreGState()
        cg.endTransparencyLayer()

        cg.saveGState()
        if mark.scale < 1 { cg.setAlpha(mark.scale) }   // fades with its size, both ways
        paint(path, mark.kind, line: line, widen: 0)
        cg.restoreGState()
    }

    /// The two halves of a glyph: what never changes, and what shows the charge.
    private enum BodyPart { case outline, level }

    /// Outline or level, per style. The level fades while charging is held and the outline
    /// never does: a dimmed level reads as "deliberately parked", a dimmed battery as
    /// "something is off".
    private static func drawBody(style: BatteryIconStyle, part: BodyPart, frac: CGFloat,
                                 fillFrac: CGFloat, charging: Bool, holding: Bool, frame: Int) {
        let outline = part == .outline
        switch style {
        case .rounded:
            if outline { strokeSVG(bodyPath); strokeSVG(terminalPath); return }
            faded(holding) { fillBar(x: 4.6, y: 9, maxW: 11.6, h: 6, r: 1.5, frac: fillFrac) }

        case .bars:
            if outline { strokeSVG(bodyPath); strokeSVG(terminalPath); return }
            faded(holding) { drawBars(frac: fillFrac) }

        case .classic:
            if outline {
                let body = NSBezierPath(roundedRect: NSRect(x: 2, y: 7, width: 16.4, height: 10),
                                        xRadius: 2.2, yRadius: 2.2)
                body.lineWidth = stroke; body.stroke()
                NSBezierPath(roundedRect: NSRect(x: 19, y: 9.6, width: 1.9, height: 4.8),
                             xRadius: 0.7, yRadius: 0.7).fill()
                return
            }
            faded(holding) { fillBar(x: 3.7, y: 8.7, maxW: 13, h: 6.6, r: 1.2, frac: fillFrac) }

        case .minimal:
            if outline {
                let pill = NSBezierPath(roundedRect: NSRect(x: 2, y: 8, width: 18, height: 8),
                                        xRadius: 4, yRadius: 4)
                pill.lineWidth = stroke; pill.stroke()
                return
            }
            faded(holding) { fillBar(x: 3.6, y: 9.6, maxW: 14.8, h: 4.8, r: 2.4, frac: fillFrac) }

        case .pixel:
            break   // drawn whole by `drawPixel`, marks included

        case .vertical:
            drawVertical(part: part, frac: fillFrac, holding: holding)

        case .ring:
            drawRing(part: part, frac: frac, charging: charging, holding: holding, frame: frame)

        case .segments:
            drawSegments(part: part, frac: fillFrac, holding: holding)

        case .dot:
            drawDot(part: part, frac: fillFrac, holding: holding)

        case .wave:
            if outline { strokeSVG(bodyPath); strokeSVG(terminalPath); return }
            faded(holding) { drawWave(frac: fillFrac, frame: frame) }

        case .boltFill:
            if outline { return }
            drawBoltGauge(frac: fillFrac, charging: charging, holding: holding)

        case .gauge:
            drawDial(part: part, frac: frac, charging: charging, holding: holding, frame: frame)
        }
    }

    /// Draw `level` at the held-charge alpha when holding, plainly otherwise.
    private static func faded(_ holding: Bool, _ level: () -> Void) {
        guard holding, let cg = NSGraphicsContext.current?.cgContext else { level(); return }
        cg.saveGState()
        cg.setAlpha(holdFillAlpha)
        level()
        cg.restoreGState()
    }

    // MARK: - The mark

    /// What the mark inside the glyph says. Nothing on battery: the glyph alone is the level.
    private enum Mark {
        /// Current is flowing in.
        case bolt
        /// On the adapter and not taking a charge: held at the limit, "Don't charge", or a
        /// pause. It said "plug" first, the macOS convention, and read as a charging sign
        /// anyway: anything drawn in the battery while it's on the charger looks like
        /// charging. Two bars say the one thing that's true here.
        case pause
        /// A charge just finished.
        case check
    }

    /// Where a style's mark sits, in its viewBox: the centre and the mark's height. Each one
    /// is centred on the body rather than the fill, so it doesn't wander as the level moves.
    private struct MarkBox { let cx: CGFloat; let cy: CGFloat; let h: CGFloat }

    private static func markBox(_ style: BatteryIconStyle) -> MarkBox? {
        switch style {
        case .rounded, .bars, .wave: return MarkBox(cx: 10.5, cy: 12, h: 8.6)
        case .classic:  return MarkBox(cx: 10.2, cy: 12, h: 7.6)
        case .minimal:  return MarkBox(cx: 11, cy: 12, h: 6.4)
        // Pixel art gets pixel marks: see `drawPixel`.
        case .pixel:    return nil
        case .vertical: return MarkBox(cx: 12, cy: 11.9, h: 9.0)
        case .ring:     return MarkBox(cx: 12, cy: 12, h: 8.6)
        case .dot:      return MarkBox(cx: 12, cy: 12, h: 9.4)
        // Up in the empty corner over the two short steps, clear of every bar.
        case .segments: return MarkBox(cx: 5.0, cy: 9.0, h: 7.4)
        // Inside the arch, under the track.
        case .gauge:    return MarkBox(cx: 12, cy: 14.3, h: 6.2)
        // The glyph is a bolt already; charging fills it solid instead.
        case .boltFill: return nil
        }
    }

    /// The clearance cut around the mark, each side, in viewBox units.
    private static let markHalo: CGFloat = 0.85

    /// The mark to draw and its scale, steady or part-way through a transition.
    private static func mark(pct: Int, charging: Bool, pluggedIn: Bool, celebrating: Bool,
                             transition: IconTransition?, step: Int) -> (kind: Mark, scale: CGFloat)? {
        // Full on the charger is just a full battery: nothing is paused, there's nothing to say.
        let steady: Mark? = celebrating ? .check : charging ? .bolt
            : pluggedIn && pct < 100 ? .pause : nil
        let t = Double(step) / Double(transitionSteps - 1)
        switch transition {
        case .markIn?:
            guard let steady else { return nil }
            return (steady, CGFloat(Easing.outBack(t)))
        case .markOutBolt?, .markOutPause?:
            // Plugged straight back in mid-animation: show what's true, not the exit.
            if let steady { return (steady, 1) }
            return (transition == .markOutBolt ? .bolt : .pause, CGFloat(1 - t * t))
        case nil:
            return steady.map { ($0, 1) }
        }
    }

    /// The mark's outline in viewBox units, scaled about its centre.
    private static func markPath(_ kind: Mark, in box: MarkBox, scale: CGFloat) -> NSBezierPath {
        let h = box.h * scale
        // Unit coordinates (x across `aspect`, y 0…1 downwards) → viewBox.
        func pt(_ aspect: CGFloat, _ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: box.cx + (x - aspect / 2) * h, y: box.cy + (y - 0.5) * h)
        }
        func rect(_ aspect: CGFloat, _ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat,
                  radius: CGFloat) -> NSBezierPath {
            let a = pt(aspect, x0, y0), b = pt(aspect, x1, y1)
            return NSBezierPath(roundedRect: NSRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y),
                                xRadius: radius * h, yRadius: radius * h)
        }

        switch kind {
        case .bolt:
            // Chunky on purpose: each arm is about a fifth of the height, which is the
            // thinnest that still holds its shape at 14pt. The slim stroked zigzag it
            // replaces read as a squiggle there.
            let a: CGFloat = 0.64
            let corners: [(CGFloat, CGFloat)] = [(0.62, 0), (0, 0.60), (0.42, 0.60),
                                                 (0.34, 1), (1, 0.38), (0.58, 0.38)]
            let path = NSBezierPath()
            for (i, c) in corners.enumerated() {
                let p = pt(a, c.0 * a, c.1)
                i == 0 ? path.move(to: p) : path.line(to: p)
            }
            path.close()
            return path

        case .pause:
            // Fat bars and a gap wider than the halo, so the two never close into one block
            // the way a pause cut into a six-point bar used to.
            let a: CGFloat = 0.62
            let path = NSBezierPath()
            // Full height of the mark, taller than any fill, so the bars stand out past it.
            path.append(rect(a, 0, 0, 0.24, 1, radius: 0.07))
            path.append(rect(a, 0.38, 0, a, 1, radius: 0.07))
            return path

        case .check:
            let path = NSBezierPath()
            path.move(to: pt(1, 0.10, 0.54))
            path.line(to: pt(1, 0.40, 0.84))
            path.line(to: pt(1, 0.92, 0.20))
            return path
        }
    }

    /// Paint a mark: solid marks are filled and their corners softened by a hairline
    /// stroke; the check is a stroke. `widen` grows the whole thing, which is the halo.
    private static func paint(_ path: NSBezierPath, _ kind: Mark, line: CGFloat, widen: CGFloat) {
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        switch kind {
        case .check:
            path.lineWidth = line + widen
            path.stroke()
        case .bolt, .pause:
            path.fill()
            path.lineWidth = 0.6 + widen
            path.stroke()
        }
    }

    // MARK: - Upright / round styles

    /// Upright battery: cap on top, fill rising from the bottom. Drawn in a flipped
    /// context, so "up" is a smaller y — the fill grows by moving its origin down.
    ///
    /// Stout on purpose. A true-to-life upright cell is about half as wide as it is
    /// tall, which at 14pt is a 6pt sliver with an invisible fill; widening the body
    /// and shortening the can buys a glyph you can actually read in a menu bar.
    private static func drawVertical(part: BodyPart, frac: CGFloat, holding: Bool) {
        let body = NSRect(x: 6.6, y: 4.6, width: 10.8, height: 14.2)
        if part == .outline {
            let path = NSBezierPath(roundedRect: body, xRadius: 2.8, yRadius: 2.8)
            path.lineWidth = 1.6; path.stroke()
            // Cap.
            NSBezierPath(roundedRect: NSRect(x: 9.6, y: 2.9, width: 4.8, height: 1.9),
                         xRadius: 0.9, yRadius: 0.9).fill()
            return
        }

        let inset = NSRect(x: body.minX + 1.6, y: body.minY + 1.6,
                           width: body.width - 3.2, height: body.height - 3.2)
        guard frac > 0 else { return }
        faded(holding) {
            let h = min(inset.height, max(2.0, inset.height * frac))
            NSBezierPath(roundedRect: NSRect(x: inset.minX, y: inset.maxY - h,
                                             width: inset.width, height: h),
                         xRadius: 1.4, yRadius: 1.4).fill()
        }
    }

    /// Circular gauge. The arc tracks the charge; while charging a short leading
    /// segment travels around the track, which reads as movement without the whole
    /// ring flickering.
    private static func drawRing(part: BodyPart, frac: CGFloat, charging: Bool, holding: Bool,
                                 frame: Int) {
        let center = NSPoint(x: 12, y: 12), radius: CGFloat = 8.2
        if part == .outline {
            // Thick enough to survive 14pt: a 1.6pt track at menu-bar size is a grey hint,
            // not a track, and the gauge stops reading as a gauge.
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = 2.6
            dimmed(0.22) { track.stroke() }
            return
        }

        let sweep = max(14, 360 * frac)          // always a visible tick of charge
        let arc = NSBezierPath()
        arc.appendArc(withCenter: center, radius: radius, startAngle: 90,
                      endAngle: 90 - sweep, clockwise: true)
        arc.lineWidth = 2.8
        arc.lineCapStyle = .round
        faded(holding) { arc.stroke() }

        // The travelling head is the charging animation; still, it's just the arc's end.
        guard charging, frame > 0 else { return }
        // A solid head travelling the track: at 14pt a dot holds its shape where a thin
        // trailing arc smears into the track behind it.
        let travel = CGFloat(Easing.outStrong(Double(phase(frame, sweepSteps)) / Double(sweepSteps)))
        let lead = (90 - sweep - travel * 360) * .pi / 180
        let head = NSPoint(x: center.x + cos(lead) * radius, y: center.y - sin(lead) * radius)
        NSBezierPath(ovalIn: NSRect(x: head.x - 1.9, y: head.y - 1.9,
                                    width: 3.8, height: 3.8)).fill()
    }

    /// Stepped meter: four blocks, each taller than the last, lit up to the level.
    ///
    /// Unlit steps are filled at low alpha rather than outlined — a 1.1pt outline at
    /// menu-bar size is a smudge, while a dimmed block keeps its shape and still reads
    /// as "a step that isn't lit". Four fat steps rather than five thin ones for the
    /// same reason: at 14pt, 3.4pt of block beats 2.6pt of block plus a gap nobody sees.
    private static func drawSegments(part: BodyPart, frac: CGFloat, holding: Bool) {
        let lit = max(frac > 0.02 ? 1 : 0, min(4, Int((frac * 4).rounded())))
        let base: CGFloat = 18.4                                  // shared baseline
        for k in 0..<4 {
            let h = 5.0 + CGFloat(k) * 2.9
            let rect = NSRect(x: 2.6 + CGFloat(k) * 4.7, y: base - h, width: 3.4, height: h)
            let bar = NSBezierPath(roundedRect: rect, xRadius: 1.1, yRadius: 1.1)
            switch (part, k < lit) {
            case (.level, true):    faded(holding) { bar.fill() }
            case (.outline, false): dimmed(0.22) { bar.fill() }
            default:                break
            }
        }
    }

    /// Liquid inside the standard battery body, with a moving surface: two sine crests
    /// across the width, the phase advancing one step per tick. The only style that
    /// animates on battery as well as while charging — it's the point of it — and it
    /// still stops dead when the animation toggle is off or Reduce Motion is on.
    private static func drawWave(frac: CGFloat, frame: Int) {
        guard frac > 0 else { return }
        let x0: CGFloat = 3.9, x1: CGFloat = 17.1          // inside the body walls
        let top: CGFloat = 8.3, bottom: CGFloat = 15.7     // flipped: bottom is larger y
        let surface = bottom - max(1.3, (bottom - top) * frac)
        let amplitude: CGFloat = min(0.85, (bottom - surface) / 2.4)
        let phase = CGFloat(self.phase(frame, sweepSteps)) / CGFloat(sweepSteps) * 2 * .pi

        let path = NSBezierPath()
        path.move(to: NSPoint(x: x0, y: bottom))
        let steps = 22
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = x0 + (x1 - x0) * t
            let y = surface + sin(phase + t * 2 * .pi * 2) * amplitude
            i == 0 ? path.line(to: NSPoint(x: x, y: y)) : path.line(to: NSPoint(x: x, y: y))
        }
        path.line(to: NSPoint(x: x1, y: bottom))
        path.close()
        // Clip to the body's inner radius so the liquid can't square off the corners.
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()
        NSBezierPath(roundedRect: NSRect(x: x0, y: top, width: x1 - x0, height: bottom - top),
                     xRadius: 1.6, yRadius: 1.6).addClip()
        path.fill()
        cg.restoreGState()
    }

    /// The bolt *is* the gauge: a lightning silhouette that fills from the bottom, so
    /// the shape says "power" and the fill says "how much". Charging inverts it —
    /// the bolt goes solid — which needs no second mark crammed inside.
    private static func drawBoltGauge(frac: CGFloat, charging: Bool, holding: Bool) {
        let bolt = SVGPath.parse(boltGaugePath)
        bolt.lineWidth = 1.6
        bolt.lineJoinStyle = .round
        // The empty part of the bolt still has to be a bolt: too faint and a nearly
        // flat battery shows nothing at all in the menu bar.
        dimmed(0.45) { bolt.stroke() }

        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()
        bolt.addClip()
        if holding { cg.setAlpha(holdFillAlpha) }
        if charging {
            NSBezierPath(rect: NSRect(x: 5, y: 0, width: 14, height: 24)).fill()
        } else if frac > 0 {
            let bottom: CGFloat = 22.2, top: CGFloat = 1.8
            // The tail is the narrowest part, so a proportional sliver there is invisible;
            // a floor of 3 units keeps a low charge readable.
            let h = max(3.0, (bottom - top) * frac)
            NSBezierPath(rect: NSRect(x: 5, y: bottom - h, width: 14, height: h)).fill()
        }
        cg.restoreGState()
    }

    /// Half-circle dial: a wide track with the charge sweeping left to right and a solid
    /// head where it stops. Reads like a fuel gauge, and the flat bottom edge sits
    /// better next to menu-bar text than a full circle does.
    private static func drawDial(part: BodyPart, frac: CGFloat, charging: Bool, holding: Bool,
                                 frame: Int) {
        let center = NSPoint(x: 12, y: 17.4), radius: CGFloat = 7.8
        if part == .outline {
            let track = NSBezierPath()
            // Flipped context: sweeping 180° → 360° draws the *upper* half.
            track.appendArc(withCenter: center, radius: radius, startAngle: 180, endAngle: 360)
            track.lineWidth = 2.6
            track.lineCapStyle = .round
            dimmed(0.22) { track.stroke() }
            return
        }

        let end = 180 + max(8, 180 * frac)
        let arc = NSBezierPath()
        arc.appendArc(withCenter: center, radius: radius, startAngle: 180, endAngle: end)
        arc.lineWidth = 2.8
        arc.lineCapStyle = .round

        // Head marker: while charging (and animating) it runs the dial, otherwise it parks
        // at the level.
        let headDeg = charging && frame > 0
            ? 180 + CGFloat(phase(frame, sweepSteps)) / CGFloat(sweepSteps) * 180
            : end
        let a = headDeg * .pi / 180
        let head = NSPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius)
        faded(holding) {
            arc.stroke()
            NSBezierPath(ovalIn: NSRect(x: head.x - 1.9, y: head.y - 1.9,
                                        width: 3.8, height: 3.8)).fill()
        }
    }

    /// A circle filling like liquid, clipped to the outline. The quietest style in the
    /// set: no terminal, no steps, just how full it is.
    ///
    /// It's the one style with no bolt while charging. There is no room for one inside a
    /// 14pt circle — every version of it came out a smudge — and the sweeping liquid
    /// already says "charging" without adding a mark that only works when zoomed in.
    private static func drawDot(part: BodyPart, frac: CGFloat, holding: Bool) {
        let box = NSRect(x: 3.8, y: 3.8, width: 16.4, height: 16.4)
        if part == .outline {
            let outline = NSBezierPath(ovalIn: box)
            outline.lineWidth = 1.8
            outline.stroke()
            return
        }

        guard frac > 0, let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()
        let inner = box.insetBy(dx: 1.7, dy: 1.7)
        NSBezierPath(ovalIn: inner).addClip()
        let h = max(2.2, inner.height * frac)
        faded(holding) {
            NSBezierPath(rect: NSRect(x: inner.minX, y: inner.maxY - h,
                                      width: inner.width, height: h)).fill()
        }
        cg.restoreGState()
    }

    // MARK: - Animation helpers

    /// How small the glyph draws while it shakes. Every box leaves about a unit of margin
    /// at 90%, which is what the shake travels.
    private static let shakeScale: CGFloat = 0.9

    /// Sideways offset, in viewBox units, `t` (0…1) of the way through a low-battery
    /// shake: four swings dying away, like something buzzing on a table.
    static func shakeOffset(_ t: Double, strength: Double) -> CGFloat {
        let c = max(0, min(1, t))
        return CGFloat(strength * sin(2 * .pi * 4 * c) * pow(1 - c, 1.5))
    }

    /// Steps in the charging fill sweep. Also the modulus for every charging
    /// animation, so one tick drives the sweep and the ring marker together instead of
    /// them drifting against each other.
    ///
    /// Six, not eight: the menu-bar tick is 500ms and can't safely go faster (each one
    /// relayouts the status item), so a shorter cycle is the only way to make the sweep
    /// read as quick. Six steps is 3s a cycle, and the ease-out below spends most of
    /// that in the first half — so it looks like a surge that settles, not a crawl.
    private static let sweepSteps = 6

    /// Fill level to draw while charging: starts at the real level and rises to full
    /// across the cycle. `frame` 0 (animation off) draws the true level, so a static
    /// icon is never a lie.
    private static func sweepFrac(_ frac: CGFloat, frame: Int) -> CGFloat {
        let linear = Double(phase(frame, sweepSteps)) / Double(sweepSteps)
        let step = CGFloat(Easing.outStrong(linear))
        return min(1, frac + (1 - frac) * step)
    }

    /// Frames a mark transition runs for. Nine at 32ms is ~290ms: long enough for the
    /// spring's overshoot to land as a frame of its own, and still under the 300ms where a
    /// state change starts to read as the app thinking.
    static let transitionSteps = 9
    /// Seconds each transition frame is held; the menu bar drives its own clock for this.
    static let transitionStepDuration = 0.032

    /// A *closed* bolt silhouette — the Bolt style fills and clips to it, which an open
    /// stroked path can't do.
    private static let boltGaugePath =
        "M14.8 1.8L7.2 13.1H11.1L9.2 22.2L16.8 10.4H12.6Z"

    /// Non-negative modulo, so an animation tick can never index out of range.
    private static func phase(_ frame: Int, _ n: Int) -> Int {
        ((frame % n) + n) % n
    }

    /// Draw at a fraction of the current colour's alpha: the unlit track, the empty steps.
    private static func dimmed(_ alpha: CGFloat, _ draw: () -> Void) {
        guard let cg = NSGraphicsContext.current?.cgContext else { draw(); return }
        cg.saveGState()
        cg.setAlpha(alpha)
        draw()
        cg.restoreGState()
    }

    // MARK: - Pixel style (8-bit battery)

    /// Lit fill columns for a charge level and frame. While charging below full,
    /// the fill sweeps up one column per frame then wraps. Pure, so the renderer
    /// also uses it to bound an ever-growing frame tick into the cache key.
    static func pixelFillCount(pct: Int, charging: Bool, frame: Int) -> Int {
        let frac = CGFloat(max(0, min(100, pct))) / 100
        var n = Int((frac * CGFloat(pixelColumns)).rounded())
        // Keep one column lit for any non-zero charge (the "not dead yet" sliver).
        if frac > 0.02 && n == 0 { n = 1 }
        n = min(pixelColumns, n)
        guard charging, n < pixelColumns else { return n }
        return n + frame % (pixelColumns - n + 1)
    }

    /// One pixel of the pixel style, in viewBox units. Everything in that style sits on
    /// this grid (frame, fill and marks), so nothing is ever half a pixel off another.
    private static let pixelCell: CGFloat = 1.5
    /// The frame is 11 × 8 cells from (2, 6), with a one-cell gap inside it all round, so
    /// the fill is 7 cells wide and 4 tall: the classic 8-bit battery.
    private static let pixelColumns = 7

    /// Cells as rows of a tiny bitmap, `#` lit. Each is 5 wide, centred on column 5.
    private static let pixelBolt  = ["...##", "..##.", ".####", "####.", ".##..", "##..."]
    private static let pixelPause = ["##.##", "##.##", "##.##", "##.##", "##.##", "##.##"]
    private static let pixelCheck = ["....#", "...##", "#.##.", "###..", ".#..."]

    private static func pixelRect(col: Int, row: Int, cols: Int = 1, rows: Int = 1) -> NSRect {
        NSRect(x: 2 + CGFloat(col) * pixelCell, y: 6 + CGFloat(row) * pixelCell,
               width: CGFloat(cols) * pixelCell, height: CGFloat(rows) * pixelCell)
    }

    /// Chunky 8-bit battery, marks and all.
    ///
    /// With a mark showing, the fill steps back to the held alpha and the mark is drawn
    /// solid over it: a bright sprite over a dim level, which reads at any level. Inverting
    /// the mark against the fill (cut where it overlaps, lit where it doesn't) was the
    /// obvious pixel-art move and garbled every level that ended under the mark: a bolt
    /// half in and half out of the fill came out as a "⊏F". It doesn't scale in and out the
    /// way the smooth marks do either (a scaled sprite is a blur): it builds up row by row
    /// from the bottom, and on unplugging it drops away from the top.
    private static func drawPixel(pct: Int, charging: Bool, frame: Int, holding: Bool,
                                  mark: (kind: Mark, scale: CGFloat)?) {
        // Frame: four bars with the corner cells left out (the notched corner), and a
        // terminal half the body's height.
        NSBezierPath(rect: pixelRect(col: 1, row: 0, cols: 9)).fill()
        NSBezierPath(rect: pixelRect(col: 1, row: 7, cols: 9)).fill()
        NSBezierPath(rect: pixelRect(col: 0, row: 1, rows: 6)).fill()
        NSBezierPath(rect: pixelRect(col: 10, row: 1, rows: 6)).fill()
        NSBezierPath(rect: pixelRect(col: 11, row: 2, rows: 4)).fill()

        let lit = pixelFillCount(pct: pct, charging: charging, frame: frame)
        let marked = (mark?.scale ?? 0) > 0.02
        if lit > 0 {
            faded(holding || marked) {
                NSBezierPath(rect: pixelRect(col: 2, row: 2, cols: lit, rows: 4)).fill()
            }
        }
        if let mark, marked {
            let bitmap: [String]
            switch mark.kind {
            case .bolt:  bitmap = pixelBolt
            case .pause: bitmap = pixelPause
            case .check: bitmap = pixelCheck
            }
            // 6 rows fill the inside; shorter sprites sit centred on the fill's rows.
            let top = bitmap.count == 6 ? 1 : 2
            let shown = Int((min(1, mark.scale) * CGFloat(bitmap.count)).rounded(.up))
            // One path, filled once: a fill per cell left an anti-aliased seam between
            // every pair of neighbours.
            let sprite = NSBezierPath()
            for (r, line) in bitmap.enumerated() where r >= bitmap.count - shown {
                for (c, ch) in line.enumerated() where ch == "#" {
                    sprite.appendRect(pixelRect(col: 3 + c, row: top + r))
                }
            }
            sprite.fill()
        }
    }

    /// Proportional rounded fill bar from the left, keeping a sliver visible for
    /// any non-zero charge so a nearly-empty battery still reads as "not dead".
    private static func fillBar(x: CGFloat, y: CGFloat, maxW: CGFloat, h: CGFloat,
                                r: CGFloat, frac: CGFloat) {
        guard frac > 0 else { return }
        let w = min(maxW, max(1.5, maxW * frac))
        let radius = min(r, w / 2, h / 2)
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h),
                     xRadius: radius, yRadius: radius).fill()
    }

    /// Four discrete level blocks. Filled rounded rects, not strokes: at 14pt a 1.5pt
    /// line lands between pixels and greys out, while a 2pt block stays a block.
    private static func drawBars(frac: CGFloat) {
        var n = Int((frac * 4).rounded())
        if frac > 0.02 && n == 0 { n = 1 }
        n = min(4, n)
        for k in 0..<max(0, n) {
            let rect = NSRect(x: 4.9 + CGFloat(k) * 3.1, y: 9.3, width: 2.1, height: 5.4)
            NSBezierPath(roundedRect: rect, xRadius: 0.8, yRadius: 0.8).fill()
        }
    }

    private static func strokeSVG(_ d: String, width: CGFloat = 1.5) {
        let path = SVGPath.parse(d)
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }
}

/// Minimal SVG path → NSBezierPath parser (absolute M, L, H, V, C, Z).
/// Coordinates stay in viewBox space; callers scale via the graphics context.
/// Shared with the notification-icon rasteriser, which needs the same glyphs outside
/// a SwiftUI view.
enum SVGPath {
    static func parse(_ d: String) -> NSBezierPath {
        let nums = tokenize(d)
        let path = NSBezierPath()
        var cur = NSPoint.zero, start = NSPoint.zero
        var i = 0
        func f() -> CGFloat { defer { i += 1 }; return i < nums.count ? nums[i].num : 0 }
        func isNum() -> Bool { i < nums.count && !nums[i].isCmd }

        while i < nums.count {
            guard nums[i].isCmd else { i += 1; continue }
            let cmd = nums[i].cmd; i += 1
            switch cmd {
            case "M":
                cur = NSPoint(x: f(), y: f()); start = cur; path.move(to: cur)
                while isNum() { cur = NSPoint(x: f(), y: f()); path.line(to: cur) }
            case "L":
                while isNum() { cur = NSPoint(x: f(), y: f()); path.line(to: cur) }
            case "H":
                while isNum() { cur.x = f(); path.line(to: cur) }
            case "V":
                while isNum() { cur.y = f(); path.line(to: cur) }
            case "C":
                while isNum() {
                    let c1 = NSPoint(x: f(), y: f())
                    let c2 = NSPoint(x: f(), y: f())
                    let p = NSPoint(x: f(), y: f())
                    path.curve(to: p, controlPoint1: c1, controlPoint2: c2); cur = p
                }
            case "Z", "z":
                path.close(); cur = start
            default:
                break
            }
        }
        return path
    }

    private struct Token { let isCmd: Bool; let cmd: Character; let num: CGFloat }

    private static func tokenize(_ s: String) -> [Token] {
        var toks: [Token] = []
        let chars = Array(s)
        let cmdSet = Set("MLHVCSQTAZmlhvcsqtaz")
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == " " || c == "," || c == "\n" || c == "\t" { i += 1; continue }
            if cmdSet.contains(c) { toks.append(Token(isCmd: true, cmd: c, num: 0)); i += 1; continue }
            var j = i
            if chars[j] == "+" || chars[j] == "-" { j += 1 }
            while j < chars.count {
                let d = chars[j]
                if d.isNumber || d == "." { j += 1 }
                else if d == "e" || d == "E" {
                    j += 1
                    if j < chars.count, chars[j] == "+" || chars[j] == "-" { j += 1 }
                } else { break }
            }
            if j > i, let v = Double(String(chars[i..<j])) {
                toks.append(Token(isCmd: false, cmd: " ", num: CGFloat(v)))
            }
            i = max(j, i + 1)
        }
        return toks
    }
}
