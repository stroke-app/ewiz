import SwiftUI
import AppKit
import EWizKit

/// Which animation the screen flashes when you plug in.
/// Whether the plug-in animation ships in this build.
///
/// Off for now, and deliberately a flag rather than deleted code. The matrix was just moved
/// off per-frame path rasterisation onto baked textures (`ChargeMatrixLayer`) and it wants a
/// fragment shader to finish the job — which needs a Metal toolchain this build machine
/// doesn't have. Shipping a full-screen animation that is *nearly* right is worse than
/// shipping none: it plays over whatever the user is doing, so it is the one feature in the
/// app that can't be quietly mediocre.
///
/// Everything behind the flag stays wired up, and every stored preference (style, duration,
/// unplug variant, custom frames) is left alone, so turning it back on returns the user to
/// the choices they had made.
enum ChargeOverlayFeature {
    static let shipped = false
}

enum ChargeOverlayStyle: String, CaseIterable, Identifiable, Codable {
    /// A grid of dots that ripples out from the charge port, each dot jittering as the
    /// wave passes through it.
    case dotGrid
    /// Rings pushing out from the port with the charge level in the middle — the phone
    /// charging animation everybody recognises.
    case ring
    /// A soft glow rising off the bottom edge. The quiet one.
    case aurora
    /// Whatever image sequence you've dropped in the frames folder — a Rive, Lottie or
    /// After Effects export, played back frame by frame.
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dotGrid: return "Dot Grid"
        case .ring:    return "Rings"
        case .aurora:  return "Glow"
        case .custom:  return "Custom"
        }
    }

    var summary: String {
        switch self {
        case .dotGrid: return "A dot matrix fills to your charge level in one rise, warm amber at the bottom cooling to white at the top."
        case .ring:    return "Rings push out from the port with the charge level in the middle."
        case .aurora:  return "A soft glow rises off the bottom edge and fades."
        case .custom:  return "Plays your own frames. Export a numbered image sequence from Rive, Lottie or After Effects and drop it in the folder."
        }
    }
}

/// Shows the plug-in animation: a borderless, click-through window over everything for
/// up to a couple of seconds, then gone.
///
/// Deliberately cheap. It exists for about a second, draws on the screen the pointer is
/// on rather than all of them, and the window is torn down afterwards rather than kept
/// around — a battery app has no business holding a full-screen layer open.
@MainActor
final class ChargeOverlayController: ObservableObject {
    private var window: NSWindow?
    private var dismissal: Task<Void, Never>?

    /// `plugging` false runs the unplug variant (cooler colour, no level).
    /// `allowMotion` false draws the still variant — the caller owns that decision, so
    /// the system's Reduce Motion setting and the user's override for this app are
    /// resolved in one place rather than read again down here.
    func show(style: ChargeOverlayStyle, duration: Double, percentage: Int,
              plugging: Bool = true, allowMotion: Bool = true) {
        dismissal?.cancel()
        teardown()

        let screen = NSScreen.screens.first {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        } ?? NSScreen.main
        guard let frame = screen?.frame else { return }

        let panel = NSPanel(contentRect: frame,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        // Above full-screen apps, like a system HUD, but never taking focus or clicks:
        // this fires while the user is working and must not interrupt anything.
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle,
                                    .fullScreenAuxiliary]
        // No start date handed in. Standing up the panel and its hosting view costs
        // anywhere from a few milliseconds to a third of a second on the first show of a
        // session (Canvas and the text renderer both warm up here), and a clock started
        // back when `show()` was called has already burned that time by the moment the
        // first frame reaches the screen — so the animation appeared to begin part-way
        // through. The view starts its own clock when it is actually visible.
        panel.contentView = NSHostingView(
            rootView: ChargeOverlayView(style: style, duration: duration,
                                        percentage: percentage, plugging: plugging,
                                        allowMotion: allowMotion))
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()
        window = panel

        // Past the animation's own end by enough to cover a late start: the view's clock
        // begins on its first appearance, so the window has to outlive `duration` by the
        // worst-case setup cost or the tail gets cut off again from the other end.
        dismissal = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((duration + 0.45) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.teardown()
        }
    }

    private func teardown() {
        window?.orderOut(nil)
        window = nil
    }
}

/// One shot of the animation, driven by wall-clock time rather than a stored frame
/// counter so it plays at the same speed whatever the display refresh rate.
private struct ChargeOverlayView: View {
    let style: ChargeOverlayStyle
    let duration: Double
    let percentage: Int
    let plugging: Bool
    let allowMotion: Bool

    /// Set on first appearance. See the note in `show()`: the animation has to be timed
    /// from the frame the user can see, not from the call that asked for it.
    @State private var start: Date?

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(start ?? context.date)
            let t = max(0, min(1, elapsed / duration))
            // Rasterised off the main thread. The matrix is a few thousand shapes a frame
            // and the main thread is also running whatever the user is doing.
            Canvas(rendersAsynchronously: true) { gc, size in
                // Everything eWiz draws here is light-on-dark, and it lands on
                // whatever wallpaper you happen to have — on a white one the matrix would
                // be invisible. A gradient scrim, heaviest at the bottom where the meter
                // fills and gone by the top, buys the contrast without blacking out the
                // screen you're still working on. Skipped for custom frames: those are
                // somebody else's artwork and it isn't ours to tint.
                if style != .custom { drawScrim(gc, size: size) }
                if !allowMotion {
                    drawStill(gc, size: size, t: t)
                } else {
                    switch style {
                    // Drawn as textures and masks instead, in `ChargeMatrixLayer` — see the
                    // note there on why a matrix has no business being rebuilt per frame.
                    case .dotGrid: break
                    case .ring:    drawRings(gc, size: size, t: t)
                    case .aurora:  drawAurora(gc, size: size, t: t)
                    case .custom:  drawCustom(gc, size: size, t: t)
                    }
                }
            }
            .overlay {
                if allowMotion, style == .dotGrid || matrixFallsBackForCustom {
                    ZStack {
                        ChargeMatrixLayer(t: t, level: level, plugging: plugging)
                        chargeReading(t)
                    }
                }
            }
            .opacity(envelope(t))
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .onAppear { if start == nil { start = Date() } }
    }

    /// In fast, out slower: arriving deserves the attention, leaving shouldn't ask for any.
    private func envelope(_ t: Double) -> Double {
        if t < 0.12 { return t / 0.12 }
        if t > 0.62 { return max(0, 1 - (t - 0.62) / 0.38) }
        return 1
    }

    private var level: Double { Double(max(0, min(100, percentage))) / 100 }

    /// The colour standing for the current charge — computed, not picked. See
    /// `ChargePalette`: the ramp runs red at empty through yellow to green at full.
    private var accent: OKLab {
        plugging ? ChargePalette.charging(level) : ChargePalette.unplugged
    }

    private var tint: Color { Color(accent) }

    /// Where the energy comes from: the port side of a MacBook, low and to the left,
    /// so the wave looks like it enters the machine rather than appearing in mid-air.
    private func origin(_ size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.12, y: size.height * 0.94)
    }

    // MARK: - Styles

    private func drawScrim(_ gc: GraphicsContext, size: CGSize) {
        gc.fill(Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .black.opacity(0.00), location: 0.0),
                        .init(color: .black.opacity(0.10), location: 0.45),
                        .init(color: .black.opacity(0.30), location: 1.0)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)))
    }


    /// A pulse leaving the port, and the level it delivered.
    ///
    /// Three things were wrong with the first version, and all three are the same mistake
    /// in different clothes — time was being used where physics was wanted.
    ///
    ///   - **The radius was linear in time.** A pressure wave spends its energy against
    ///     the medium: it covers most of its distance immediately and crawls at the edge.
    ///     Expanding at a constant rate is the tell of something that was timed rather than
    ///     modelled, and it reads as a circle being resized rather than as a wave.
    ///   - **The rings ran out before the animation did.** With three rings on a 1.5×
    ///     clock the last one died at 67% of the duration, so the final third was an empty
    ///     screen with a number fading on it. Rings are now staggered across the whole
    ///     shot, so there is always one in flight until the scrim takes over.
    ///   - **Opacity faded linearly.** Light doesn't. Fading on a curve keeps the ring
    ///     readable through the middle of its travel and lets it disappear rather than
    ///     switch off.
    ///
    /// The line also thins as the ring grows: the same energy is being spread around a
    /// longer circumference, so a constant-weight stroke reads as a drawn circle instead of
    /// a dissipating front.
    private func drawRings(_ gc: GraphicsContext, size: CGSize, t: Double) {
        let from = origin(size)
        let maxR = hypot(size.width, size.height) * 0.92

        // Staggered by a tenth of the shot — the interval that reads as a sequence rather
        // than as one thick ring or as five unrelated events.
        let stagger = 0.10
        let life = 0.62

        for k in 0..<ringCount {
            let p = (t - Double(k) * stagger) / life
            guard p > 0, p < 1 else { continue }
            let eased = Easing.outQuint(p)
            let r = CGFloat(eased) * maxR
            guard r > 1 else { continue }

            let rect = CGRect(x: from.x - r, y: from.y - r, width: r * 2, height: r * 2)
            // Squared falloff: bright while it's doing something, gone by the edge.
            let alpha = pow(1 - p, 1.9) * 0.62
            // 4pt at birth down to a hairline, so the front dissipates instead of
            // arriving at the screen edge as a drawn circle.
            let weight = 0.7 + 3.5 * (1 - eased)
            gc.stroke(Path(ellipseIn: rect),
                      with: .color(tint.opacity(alpha)),
                      lineWidth: CGFloat(weight))
        }

        drawPortBloom(gc, at: from, t: t)
        guard plugging else { return }
        drawLevelReadout(gc, size: size, t: t)
    }

    /// The flare at the port itself: one pulse, at the moment contact is made.
    ///
    /// Without it the rings appear from nothing — there is no *source*, just circles that
    /// happen to share a centre. A bloom that peaks in the first 90ms and is gone by a third
    /// of the way through gives the wave somewhere to have come from.
    private func drawPortBloom(_ gc: GraphicsContext, at from: CGPoint, t: Double) {
        let p = min(1, t / 0.34)
        guard p < 1 else { return }
        let intensity = pow(1 - p, 2.2)
        let r = CGFloat(30 + 120 * Easing.outQuint(min(1, t / 0.22)))
        let rect = CGRect(x: from.x - r, y: from.y - r, width: r * 2, height: r * 2)
        gc.fill(Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [tint.opacity(0.55 * intensity), tint.opacity(0)]),
                    center: from, startRadius: 0, endRadius: r))
    }

    /// The number the whole thing exists to deliver.
    ///
    /// Enters on the `better-ui` recipe — opacity with a small scale and a blur resolving
    /// to zero — rather than the bare linear fade it had. A large numeral that simply
    /// appears reads as a label being switched on; one that resolves out of a blur reads as
    /// something arriving. It leaves on a small downward drift, because exits are softer
    /// than entrances and a symmetric one draws attention to itself on the way out.
    private func drawLevelReadout(_ gc: GraphicsContext, size: CGSize, t: Double) {
        let appear = Easing.outStrong(max(0, min(1, (t - 0.10) / 0.30)))
        let leave = t > 0.70 ? Easing.outStrong(min(1, (t - 0.70) / 0.30)) : 0
        let alpha = appear * (1 - leave)
        guard alpha > 0.01 else { return }

        var layer = gc
        layer.opacity = alpha
        layer.translateBy(x: size.width / 2,
                          y: size.height / 2 + CGFloat(10 * leave))
        let scale = 0.94 + 0.06 * appear
        layer.scaleBy(x: scale, y: scale)
        // 4pt → 0, the same figure the icon transitions use, so everything in the app
        // resolves at the same rate.
        layer.addFilter(.blur(radius: CGFloat(4 * (1 - appear))))
        layer.draw(Text("\(percentage)%")
                    .font(.system(size: 84, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint),
                  at: .zero)
    }

    /// Five is the count at which the wave reads as continuous without the screen becoming
    /// a target. Four leaves a visible gap between fronts; six starts to moiré.
    private var ringCount: Int { 5 }

    private func drawAurora(_ gc: GraphicsContext, size: CGSize, t: Double) {
        let height = size.height * (0.18 + 0.22 * sin(t * .pi))
        let rect = CGRect(x: 0, y: size.height - height, width: size.width, height: height)
        gc.fill(Path(rect),
                with: .linearGradient(
                    Gradient(colors: [tint.opacity(0), tint.opacity(0.42)]),
                    startPoint: CGPoint(x: 0, y: rect.minY),
                    endPoint: CGPoint(x: 0, y: rect.maxY)))
    }

    /// A frame from the user's own sequence, scaled to fit and centred so a square export
    /// isn't stretched across a 16:10 display. With no frames to play it draws nothing and
    /// the matrix layer underneath shows through — see `matrixFallsBackFor`.
    private func drawCustom(_ gc: GraphicsContext, size: CGSize, t: Double) {
        guard let frame = ChargeFrameSequence.frame(at: t) else { return }
        let source = frame.size
        guard source.width > 0, source.height > 0 else { return }
        let scale = min(size.width / source.width, size.height / source.height)
        let drawn = CGSize(width: source.width * scale, height: source.height * scale)
        let rect = CGRect(x: (size.width - drawn.width) / 2,
                          y: (size.height - drawn.height) / 2,
                          width: drawn.width, height: drawn.height)
        gc.draw(Image(nsImage: frame), in: rect)
    }

    /// Reduce Motion: the same information, no travel — just the level fading in place.
    /// "Custom" with nothing in the frames folder. The matrix stands in, rather than the
    /// overlay being a second of dimmed screen and no explanation.
    private var matrixFallsBackForCustom: Bool {
        style == .custom && ChargeFrameSequence.frame(at: 0) == nil
    }

    /// The level, in the same register as the matrix, once the rise has landed. Monospaced
    /// so the digits don't shuffle sideways, and it arrives late: the number is the
    /// conclusion, so it shouldn't be on screen while the meter is still making the case.
    @ViewBuilder
    private func chargeReading(_ t: Double) -> some View {
        if plugging {
            Text("\(percentage)%")
                .font(.system(size: 74, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(tint)
                .opacity(max(0, min(1, (t - 0.34) / 0.24)))
                // A hair of scale with it. Type that fades in without moving reads as a
                // layer being switched on; a few percent of growth reads as it arriving.
                .scaleEffect(0.97 + 0.03 * max(0, min(1, (t - 0.34) / 0.24)))
        }
    }

    private func drawStill(_ gc: GraphicsContext, size: CGSize, t: Double) {
        var text = gc
        text.translateBy(x: size.width / 2, y: size.height / 2)
        text.draw(Text(plugging ? "\(percentage)%" : "Unplugged")
                    .font(.system(size: 72, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint),
                  at: .zero)
    }
}
