import Testing
import AppKit
@testable import EWizKit

/// A square, drawn clockwise from the top-left.
private func square(_ side: CGFloat, at origin: CGPoint = .zero) -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: origin)
    p.line(to: NSPoint(x: origin.x + side, y: origin.y))
    p.line(to: NSPoint(x: origin.x + side, y: origin.y + side))
    p.line(to: NSPoint(x: origin.x, y: origin.y + side))
    p.close()
    return p
}

private func line(from a: NSPoint, to b: NSPoint) -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: a)
    p.line(to: b)
    return p
}

/// Bounding box, since a morphed path is a fresh polyline — the points are what matter,
/// not the element list.
private func box(_ path: NSBezierPath) -> NSRect { path.bounds }

@Suite struct PathMorphTests {

    @Test func resamplingSpacesPointsEvenlyByArcLength() {
        let path = line(from: NSPoint(x: 0, y: 0), to: NSPoint(x: 10, y: 0))
        let points = PathMorph.resample(path, count: 11, closed: false)
        #expect(points.count == 11)
        #expect(abs(points[0].x - 0) < 0.001)
        #expect(abs(points[10].x - 10) < 0.001)
        // Even spacing: every step is the same length along the line.
        for i in 1..<points.count {
            #expect(abs((points[i].x - points[i - 1].x) - 1.0) < 0.01)
        }
    }

    @Test func endpointsAreReachedAtTZeroAndOne() {
        let a = line(from: NSPoint(x: 0, y: 0), to: NSPoint(x: 10, y: 0))
        let b = line(from: NSPoint(x: 0, y: 20), to: NSPoint(x: 10, y: 20))
        let atStart = PathMorph.morph(from: a, to: b, t: 0)
        let atEnd = PathMorph.morph(from: a, to: b, t: 1)
        #expect(abs(box(atStart).minY - 0) < 0.01)
        #expect(abs(box(atEnd).minY - 20) < 0.01)
    }

    @Test func halfwayLandsHalfway() {
        let a = line(from: NSPoint(x: 0, y: 0), to: NSPoint(x: 10, y: 0))
        let b = line(from: NSPoint(x: 0, y: 10), to: NSPoint(x: 10, y: 10))
        let mid = PathMorph.morph(from: a, to: b, t: 0.5)
        #expect(abs(box(mid).minY - 5) < 0.01)
        #expect(abs(box(mid).maxY - 5) < 0.01)
    }

    @Test func tIsClampedRatherThanExtrapolated() {
        let a = line(from: NSPoint(x: 0, y: 0), to: NSPoint(x: 10, y: 0))
        let b = line(from: NSPoint(x: 0, y: 10), to: NSPoint(x: 10, y: 10))
        #expect(abs(box(PathMorph.morph(from: a, to: b, t: -3)).minY - 0) < 0.01)
        #expect(abs(box(PathMorph.morph(from: a, to: b, t: 4)).minY - 10) < 0.01)
    }

    @Test func shapesWithDifferentSegmentCountsStillMorph() {
        // Two segments into one: the point counts match after resampling, which is the
        // whole reason for resampling instead of pairing control points.
        let bolt = NSBezierPath()
        bolt.move(to: NSPoint(x: 0, y: 0))
        bolt.line(to: NSPoint(x: 4, y: 6))
        bolt.line(to: NSPoint(x: 1, y: 12))
        let straight = line(from: NSPoint(x: 0, y: 0), to: NSPoint(x: 0, y: 12))
        let mid = PathMorph.morph(from: bolt, to: straight, t: 0.5)
        #expect(mid.elementCount > 8, "morph should produce a resampled polyline")
        // Halfway between a zig-zag reaching x=4 and a vertical line at x=0.
        #expect(box(mid).maxX > 1.4 && box(mid).maxX < 2.6)
    }

    @Test func closedRingsAreAlignedBeforeInterpolating() {
        // Same square, one starting a quarter of the way around. Aligned, the morph is a
        // no-op; unaligned, every point would travel to a different corner and the shape
        // would collapse on the way.
        let a = square(10)
        let rotated = NSBezierPath()
        rotated.move(to: NSPoint(x: 10, y: 0))
        rotated.line(to: NSPoint(x: 10, y: 10))
        rotated.line(to: NSPoint(x: 0, y: 10))
        rotated.line(to: NSPoint(x: 0, y: 0))
        rotated.close()

        let mid = PathMorph.morph(from: a, to: rotated, t: 0.5, closed: true)
        let b = box(mid)
        #expect(abs(b.width - 10) < 0.6, "aligned rings keep the shape's size")
        #expect(abs(b.height - 10) < 0.6)
    }

    @Test func alignmentPicksTheLeastTravelOffset() {
        let ring = [NSPoint(x: 0, y: 0), NSPoint(x: 1, y: 0),
                    NSPoint(x: 1, y: 1), NSPoint(x: 0, y: 1)]
        let shifted = Array(ring[2...] + ring[..<2])
        let aligned = PathMorph.alignedForLeastTravel(ring, to: shifted)
        #expect(aligned == shifted)
    }

    @Test func emptyPathsDegradeToTheNearerShape() {
        let empty = NSBezierPath()
        let l = line(from: NSPoint(x: 0, y: 0), to: NSPoint(x: 10, y: 0))
        #expect(PathMorph.morph(from: empty, to: l, t: 0.9).bounds.width > 9)
        #expect(PathMorph.resample(empty, count: 12, closed: false).isEmpty)
    }
}
