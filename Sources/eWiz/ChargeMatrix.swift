import SwiftUI
import EWizKit

/// The dot-matrix charge animation, drawn as textures and masks rather than as paths.
///
/// The old version rebuilt the whole matrix every frame inside a `Canvas`: on a 16" display
/// that is some eight thousand antialiased shapes per frame, assembled on the CPU and
/// rasterised by Core Graphics, sixty or a hundred and twenty times a second. Nothing about
/// the picture changes between frames except *where the front is* — every dot is in the same
/// place it was 8ms ago — so almost all of that work was spent redrawing an unchanged grid.
/// That is what made the rise stutter, and no amount of trimming the inner loop fixes the
/// shape of it.
///
/// A custom Metal shader would be the other way to do this, and it is what this wants to be;
/// it needs Xcode's Metal toolchain installed to build, which this machine doesn't have. So:
/// the grid is baked once into two images (ordinary cells, and fatter ones for the glow), and
/// the animation is three masks moving over them. Per frame that is three textured quads and
/// a couple of gradients — the compositor's entire job, done on the GPU, at whatever rate the
/// display runs.
///
/// What the motion has to get right, in the order it matters:
///
///   - **The fill is the reading.** The lit region stops at the charge level. The front's
///     momentum is allowed to carry the *glow* past it and pull back; the fill never moves
///     past the number it is claiming.
///   - **The front is an edge, not a stripe.** It lights cells as it passes and leaves them
///     lit. A highlight travelling through an already-lit matrix is a barber's pole.
///   - **Colour is calibration.** Each height is drawn in the colour of the level it stands
///     for, so the ramp from red at the bottom to green at the top means something.
///   - **It enters at the port.** The mask is tilted a few degrees so the left side fills
///     marginally first, which reads as energy arriving at the connector.
struct ChargeMatrixLayer: View {
    /// 0…1 through the animation. Owned by the caller so the fade envelope and the matrix
    /// can't disagree about where in the shot they are.
    let t: Double
    /// Charge level, 0…1.
    let level: Double
    /// False runs the unplug variant: a full matrix draining to the floor, in neutral.
    let plugging: Bool

    @State private var cells: Image?
    @State private var glowCells: Image?
    @State private var baked: CGSize = .zero

    /// Cell pitch. 16pt reads as a display rather than as a halftone, and the baked texture
    /// means the count no longer costs anything per frame.
    private let spacing: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                if let cells, let glowCells {
                    matrix(cells: cells, glowCells: glowCells, size: size)
                }
            }
            .task(id: size) { await bake(for: size) }
        }
    }

    // MARK: - Layers

    @ViewBuilder
    private func matrix(cells: Image, glowCells: Image, size: CGSize) -> some View {
        let height = size.height
        let front = frontHeight(in: height)

        ZStack {
            // 1. The unlit grid. Always the whole screen, so the matrix exists before the
            //    front reaches it and the fill has somewhere to arrive.
            cells
                .foregroundStyle(Color(ChargePalette.unlit).opacity(0.07))

            // 2. The lit region, coloured by height. One gradient masked by the grid and
            //    then by the front, which is three cheap compositing steps in place of a
            //    per-row colour bucket.
            rampGradient
                .mask(cells)
                .mask(fillMask(front: front, height: height))
                .opacity(0.62)

            // 3. The front itself: the fat cells, tinted with the colour of the level the
            //    edge is currently reading, masked to a soft band around it. Additive, so
            //    where it crosses lit cells they bloom rather than change colour.
            Color(edgeColor)
                .mask(glowCells)
                .mask(bandMask(front: glowFront(in: height), height: height))
                .blendMode(.plusLighter)
        }
        // One texture for the whole stack. Without it each mask is a separate offscreen
        // pass every frame; with it the composite is flattened once and reused.
        .drawingGroup()
    }

    /// The charge ramp as a vertical gradient: bottom of the screen is 0%, top is 100%.
    private var rampGradient: LinearGradient {
        let stops = (0...8).map { step -> Gradient.Stop in
            let fraction = Double(step) / 8
            let colour = plugging ? ChargePalette.charging(fraction) : ChargePalette.unplugged
            return .init(color: Color(colour), location: 1 - fraction)
        }
        return LinearGradient(stops: stops.reversed(), startPoint: .bottom, endPoint: .top)
    }

    /// Everything below the front, hard-edged but for a cell of softness at the top, and
    /// tilted so the port side leads.
    ///
    /// The tilt is 1.5% of the width expressed as a vertical offset between the two edges of
    /// the mask — a couple of degrees. Any more and the front stops being a level and starts
    /// being a wipe.
    private func fillMask(front: CGFloat, height: CGFloat) -> some View {
        LinearGradient(stops: [
            .init(color: .white, location: 0),
            .init(color: .white, location: max(0, 1 - (front + spacing * 0.35) / height)),
            .init(color: .clear, location: max(0, 1 - front / height)),
            .init(color: .clear, location: 1)
        ], startPoint: UnitPoint(x: 0, y: 1.015), endPoint: UnitPoint(x: 1, y: -0.015))
        .scaleEffect(x: 1, y: -1)         // gradient runs top-down; the meter fills bottom-up
    }

    /// A soft band centred on the front, for the glow. Reach is about two cells either side,
    /// which is what makes the edge read as energy rather than as a line.
    private func bandMask(front: CGFloat, height: CGFloat) -> some View {
        let reach = spacing * 2.4
        let centre = 1 - front / height
        return LinearGradient(stops: [
            .init(color: .clear, location: max(0, centre - reach / height)),
            .init(color: .white.opacity(0.55), location: centre),
            .init(color: .clear, location: min(1, centre + reach / height))
        ], startPoint: UnitPoint(x: 0, y: 1.015), endPoint: UnitPoint(x: 1, y: -0.015))
    }

    // MARK: - Motion

    /// Where the fill has got to, in points off the bottom. Clamped to the level: this is
    /// the number the animation is claiming and it is never allowed to overstate it.
    private func frontHeight(in height: CGFloat) -> CGFloat {
        let target = plugging ? level : 1
        let progress = plugging ? settle(rise) : 1 - settle(rise)
        return CGFloat(max(0, min(1, progress)) * target) * height
    }

    /// Where the *glow* has got to. Same spring, but this one keeps its overshoot — the
    /// couple of percent the front travels past the level before settling back is the whole
    /// reason the rise reads as physical rather than as a fade.
    private func glowFront(in height: CGFloat) -> CGFloat {
        let target = plugging ? level : 1
        let progress = plugging ? overshoot(rise) : 1 - overshoot(rise)
        return CGFloat(max(0, min(1.04, progress)) * target) * height
    }

    /// The rise occupies the first 55% of the shot; the rest is the number landing and the
    /// fade. A charge animation that is still moving when it disappears never resolved.
    private var rise: Double { min(1, max(0, t / 0.55)) }

    /// A damped oscillation, not an easing curve.
    ///
    /// Easing can only decelerate into its target, so it always arrives with no momentum —
    /// which is why eased travel reads as something being positioned rather than something
    /// arriving. This carries energy past the mark and pulls it back. Damping is tuned for
    /// roughly 3% overshoot: enough to read as mass, not enough to read as a bounce.
    private func overshoot(_ p: Double) -> Double {
        guard p > 0 else { return 0 }
        guard p < 1 else { return 1 }
        return 1 - exp(-9 * p) * cos(7.2 * p)
    }

    /// The same spring with the overshoot clipped off, for anything that must not overstate
    /// the level.
    private func settle(_ p: Double) -> Double { min(1, overshoot(p)) }

    private var edgeColor: OKLab {
        plugging ? ChargePalette.charging(min(1, settle(rise) * level)) : ChargePalette.unplugged
    }

    // MARK: - Baking

    /// Draw the grid twice, once at cell size and once fat, and keep both as images.
    ///
    /// Renders at the display's scale so the cells land on whole pixels instead of being
    /// resampled into mush, and keyed on `size` so a move to another display re-bakes.
    @MainActor
    private func bake(for size: CGSize) async {
        guard size.width > 1, size.height > 1, size != baked else { return }
        baked = size
        cells = render(size: size, radius: 1.15)
        glowCells = render(size: size, radius: 2.9)
    }

    @MainActor
    private func render(size: CGSize, radius: CGFloat) -> Image? {
        let grid = Canvas { gc, canvasSize in
            var path = Path()
            let cols = max(1, Int(canvasSize.width / spacing))
            let rows = max(1, Int(canvasSize.height / spacing))
            let originX = (canvasSize.width - CGFloat(cols - 1) * spacing) / 2
            let originY = (canvasSize.height - CGFloat(rows - 1) * spacing) / 2
            for c in 0..<cols {
                for r in 0..<rows {
                    path.addRect(CGRect(x: originX + CGFloat(c) * spacing - radius,
                                        y: originY + CGFloat(r) * spacing - radius,
                                        width: radius * 2, height: radius * 2))
                }
            }
            gc.fill(path, with: .color(.white))
        }
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: grid)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        renderer.isOpaque = false
        guard let cg = renderer.cgImage else { return nil }
        return Image(decorative: cg, scale: renderer.scale)
    }
}
