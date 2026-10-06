import AppKit

/// Shape-to-shape interpolation for the glyphs the app draws.
///
/// Two SVG paths almost never have matching segment counts — a bolt has three curves,
/// a checkmark two lines — so interpolating control points pairwise is not an option.
/// Instead both outlines are flattened and resampled to the same number of points,
/// spaced evenly *by arc length*, and those点 point sets are interpolated. That morphs
/// any pair of shapes, at the cost of replacing curves with a dense polyline — which at
/// the 14–28pt these glyphs are drawn is indistinguishable from the real curve.
public enum PathMorph {

    /// Blend `from` into `to`. `t` 0 returns the shape of `from`, 1 the shape of `to`.
    ///
    /// `closed` matters: a closed outline can start anywhere along its length, so its
    /// sample rings are rotated into the alignment with the least total travel before
    /// interpolating. Without that, morphing two circles whose paths happen to start on
    /// opposite sides collapses the shape through its own centre on the way across.
    public static func morph(from: NSBezierPath, to: NSBezierPath, t: CGFloat,
                             closed: Bool = false, samples: Int = 48) -> NSBezierPath {
        let clamped = max(0, min(1, t))
        var a = resample(from, count: samples, closed: closed)
        let b = resample(to, count: samples, closed: closed)
        guard a.count == b.count, !a.isEmpty else {
            return (clamped < 0.5 ? from : to).copy() as! NSBezierPath
        }
        if closed { a = alignedForLeastTravel(a, to: b) }

        let path = NSBezierPath()
        for (i, p) in a.enumerated() {
            let q = b[i]
            let point = NSPoint(x: p.x + (q.x - p.x) * clamped,
                                y: p.y + (q.y - p.y) * clamped)
            i == 0 ? path.move(to: point) : path.line(to: point)
        }
        if closed { path.close() }
        return path
    }

    /// Points along `path`, evenly spaced by arc length. An open path samples both
    /// endpoints; a closed one leaves the last point off, since it coincides with the
    /// first and would waste a sample and skew the alignment search.
    public static func resample(_ path: NSBezierPath, count: Int, closed: Bool) -> [NSPoint] {
        guard count > 1 else { return [] }
        let poly = polyline(path)
        guard poly.count > 1 else { return poly }

        var points = poly
        if closed, let first = poly.first, poly.last != first { points.append(first) }

        // Cumulative arc length along the polyline.
        var lengths: [CGFloat] = [0]
        lengths.reserveCapacity(points.count)
        for i in 1..<points.count {
            let d = hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y)
            lengths.append(lengths[i - 1] + d)
        }
        let total = lengths[lengths.count - 1]
        guard total > 0 else { return Array(repeating: points[0], count: count) }

        let last = closed ? count : count - 1
        var out: [NSPoint] = []
        out.reserveCapacity(count)
        var seg = 1
        for k in 0..<count {
            let target = total * CGFloat(k) / CGFloat(last)
            while seg < lengths.count - 1 && lengths[seg] < target { seg += 1 }
            let segStart = lengths[seg - 1], segEnd = lengths[seg]
            let span = segEnd - segStart
            let u = span > 0 ? (target - segStart) / span : 0
            let p = points[seg - 1], q = points[seg]
            out.append(NSPoint(x: p.x + (q.x - p.x) * u, y: p.y + (q.y - p.y) * u))
        }
        return out
    }

    /// Rotate `ring` so it lines up with `other` at the lowest total point travel.
    /// O(n²) over 48 points — a few thousand operations, and the result is cached by
    /// the caller anyway.
    static func alignedForLeastTravel(_ ring: [NSPoint], to other: [NSPoint]) -> [NSPoint] {
        guard ring.count == other.count, ring.count > 2 else { return ring }
        var bestOffset = 0
        var bestCost = CGFloat.greatestFiniteMagnitude
        for offset in 0..<ring.count {
            var cost: CGFloat = 0
            for i in 0..<ring.count {
                let p = ring[(i + offset) % ring.count], q = other[i]
                cost += (p.x - q.x) * (p.x - q.x) + (p.y - q.y) * (p.y - q.y)
                if cost >= bestCost { break }          // prune: already worse
            }
            if cost < bestCost { bestCost = cost; bestOffset = offset }
        }
        guard bestOffset != 0 else { return ring }
        return Array(ring[bestOffset...] + ring[..<bestOffset])
    }

    /// Flatten a path to its points. `flattened()` turns every curve into line
    /// segments, so afterwards only move/line/close elements remain.
    private static func polyline(_ path: NSBezierPath) -> [NSPoint] {
        let flat = path.flattenedForMorph
        var points: [NSPoint] = []
        var element = [NSPoint](repeating: .zero, count: 3)
        for i in 0..<flat.elementCount {
            switch flat.element(at: i, associatedPoints: &element) {
            case .moveTo, .lineTo:
                points.append(element[0])
            case .curveTo:
                points.append(element[2])            // shouldn't occur post-flatten
            case .closePath:
                break                                 // the ring is closed by the caller
            @unknown default:
                break
            }
        }
        return points
    }
}

extension NSBezierPath {
    /// Flattened at a fineness that keeps the polyline smooth at glyph sizes. Restores
    /// the global default afterwards — flatness is process-wide state, and leaving it
    /// changed would quietly affect every other path the app draws.
    var flattenedForMorph: NSBezierPath {
        let previous = NSBezierPath.defaultFlatness
        NSBezierPath.defaultFlatness = 0.08
        defer { NSBezierPath.defaultFlatness = previous }
        return flattened
    }
}
