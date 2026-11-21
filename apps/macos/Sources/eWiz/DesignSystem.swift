import SwiftUI
import EWizKit

/// The app's visual vocabulary in one place: spacing, radii, elevation, motion.
///
/// Every one of these existed before — as `.padding(10)` here, `cornerRadius: 12` there,
/// `.quaternary.opacity(0.4)` in a dozen files that had each drifted a little from the
/// others. Scattered like that they aren't decisions, they're guesses, and the interface
/// reads as "assembled" rather than "designed" for exactly that reason. Naming them makes
/// them arguable, and makes changing one of them a single edit.
enum DS {

    /// A spacing scale, not arbitrary numbers. Everything is a multiple of 4, so vertical
    /// rhythm holds across views that don't know about each other.
    enum Space {
        static let hair: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    /// Radii, chosen as a set rather than one at a time.
    ///
    /// Nested corners have to be *concentric* — the inner radius is the outer radius minus
    /// the gap between them — or the two curves run at different rates and the gap visibly
    /// pinches at the corner. Anything inset by `Space.xs` inside a `group` lands on `row`;
    /// pick the pair, don't pick a number.
    enum Radius {
        /// A standalone control: a tile, a button, a nested panel.
        static let control: CGFloat = 8
        /// A row inside a flush-edged list. 14 − 4 = 10.
        static let row: CGFloat = 10
        /// Flush-edged container (settings groups, whose rows run to the edge).
        static let group: CGFloat = 14
    }

    /// Icon sizes, as a set of three rather than a number picked per call site.
    ///
    /// The menu had grown six — 10, 11, 12, 14, 16 and 17pt — often two of them in rows
    /// stacked directly on top of each other. Nothing was wrong with any one value; what
    /// read as untidy was that no two rows agreed, so the eye picked up the variation
    /// before it picked up the content.
    ///
    /// Each size is tied to the text it sits beside, which is what keeps an icon from
    /// looking either bolted on or apologetic: `row` beside a `Typo.rowTitle`, `caption` beside
    /// `.caption`/`.caption2`, `label` for the uppercase section headings.
    enum Icon {
        /// Beside a `.caption`-sized line: an inline hint, a status note.
        static let caption: CGFloat = 13
        /// Beside a `.callout` row title, and inside the quick-action tiles.
        static let row: CGFloat = 16
        /// The glyph on a section heading. Smaller than the row icons on purpose — it
        /// labels the group rather than joining the list of things in it.
        static let label: CGFloat = 12
    }

    /// Two text sizes and the rule for which is which.
    ///
    /// The panel had four. Row titles were `.body` in one section and `.callout` in the
    /// next; a note under a row was `.caption2` while a note standing on its own was
    /// `.caption`; and the footer was `.body` — larger than any control it navigates away
    /// from. Nothing was wrong with any single value. What read as untidy was that two
    /// rows stacked directly on top of each other disagreed about how big a row title is.
    enum Typo {
        /// Every row title: a switch row, a slider label, a status line.
        static let rowTitle = Font.body
        /// The line under a row title. Subordinate to it, so one step down.
        static let rowCaption = Font.caption2
        /// A note, hint or receipt that stands on its own rather than under a title.
        static let note = Font.caption
        /// Navigation: smaller than the content it leads to, never larger.
        static let nav = Font.callout
    }

    /// Control metrics. One row height for every row, so a row with a caption under it and
    /// a row without don't sit at two different rhythms in the same list; one hit size for
    /// the icon-only buttons, since a 16pt glyph is a 16pt target unless it's given one.
    enum Metric {
        static let row: CGFloat = 24
        static let hit: CGFloat = 26
    }

    /// Durations, in the ranges that read as responsive rather than as animation.
    /// Press and hover stay under 180ms; nothing user-initiated goes past 300ms.
    enum Duration {
        static let press: Double = 0.14
        static let hover: Double = 0.15
        static let state: Double = 0.22
    }

    /// Status colours, muted on purpose.
    ///
    /// System `.green` is a signal colour — it exists to be the brightest thing on a
    /// screen, which is right for a notification badge and wrong for a line of text that
    /// is simply reporting that everything is fine. On a dark panel it fluoresces, and the
    /// eye goes to it before the control it's describing.
    ///
    /// These are the same hues pulled down in chroma and up in lightness, so "good" still
    /// reads as green at a glance without shouting. Defined in OKLab and converted once,
    /// so a muted green and a muted amber are muted by the same *perceived* amount rather
    /// than by two numbers that happened to look right.
    enum Status {
        /// Something is working as promised. Chroma 0.10 against system green's ~0.19.
        static let good = Color(OKLab(l: 0.76, chroma: 0.10, hue: 148))
        /// Something needs a decision, but nothing is broken.
        static let attention = Color(OKLab(l: 0.80, chroma: 0.11, hue: 75))
    }

    /// Shadows are never pure black. Pure black over a coloured or dark surface reads as
    /// a hole rather than a shadow — real shadows take the colour of the environment, so
    /// this is a very dark blue-grey and lets opacity do the work.
    static let shadowTint = Color(red: 0.04, green: 0.05, blue: 0.09)

    /// How far off the surface something sits.
    ///
    /// Each level is *three* stacked shadows: a tight contact shadow, a mid spread, and a
    /// wide ambient one. A single shadow has one falloff rate and always looks like a
    /// sticker, because nothing in the world is lit by one point source with no bounce.
    /// Every layer offsets straight down, so the whole interface is lit from one place.
    enum Elevation {
        case flat, card, popover, overlay

        var layers: [(opacity: Double, radius: CGFloat, y: CGFloat)] {
            switch self {
            case .flat:    return []
            case .card:    return [(0.10, 1, 0.5), (0.06, 4, 2)]
            case .popover: return [(0.12, 2, 1), (0.08, 8, 4), (0.05, 20, 10)]
            case .overlay: return [(0.16, 3, 1), (0.11, 12, 6), (0.07, 30, 16)]
            }
        }
    }
}

// MARK: - Surface

/// Card/panel background: fill, hairline border, top light-catch, layered shadow.
private struct DSSurface: ViewModifier {
    let radius: CGFloat
    let elevation: DS.Elevation
    let fill: AnyShapeStyle
    let borderOpacity: Double
    let highlight: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let layers = elevation.layers
        return content
            .background(shape.fill(fill))
            // A semi-transparent border rather than a fixed grey: it holds its
            // relationship to whatever sits behind it, in either appearance, without a
            // second value to maintain.
            .overlay { shape.strokeBorder(Color.primary.opacity(borderOpacity), lineWidth: 1) }
            .overlay {
                if highlight {
                    // The single light source from above, caught on the top edge and
                    // gone by halfway down. It's the difference between a filled
                    // rectangle and something with a surface.
                    shape.strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0)],
                                       startPoint: .top, endPoint: .center),
                        lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
            // Fixed three slots so the shadow count never changes shape mid-render.
            .shadow(color: DS.shadowTint.opacity(layers.count > 0 ? layers[0].opacity : 0),
                    radius: layers.count > 0 ? layers[0].radius : 0,
                    y: layers.count > 0 ? layers[0].y : 0)
            .shadow(color: DS.shadowTint.opacity(layers.count > 1 ? layers[1].opacity : 0),
                    radius: layers.count > 1 ? layers[1].radius : 0,
                    y: layers.count > 1 ? layers[1].y : 0)
            .shadow(color: DS.shadowTint.opacity(layers.count > 2 ? layers[2].opacity : 0),
                    radius: layers.count > 2 ? layers[2].radius : 0,
                    y: layers.count > 2 ? layers[2].y : 0)
    }
}

extension View {
    /// Give this view a surface — the app's one way of saying "this is a thing sitting on
    /// top of something else".
    func dsSurface(radius: CGFloat = DS.Radius.group,
                   elevation: DS.Elevation = .card,
                   fill: some ShapeStyle = .quaternary.opacity(0.4),
                   borderOpacity: Double = 0.07,
                   highlight: Bool = true) -> some View {
        modifier(DSSurface(radius: radius, elevation: elevation,
                           fill: AnyShapeStyle(fill),
                           borderOpacity: borderOpacity, highlight: highlight))
    }

    /// A flush-edged group whose rows run corner to corner (settings lists).
    ///
    /// Clipped *before* the surface, not after: a `clipShape` applied on top of
    /// `dsSurface` would cut off the shadow it just drew, since a shadow lives outside
    /// the shape that cast it.
    func dsGroup(elevation: DS.Elevation = .card) -> some View {
        clipShape(RoundedRectangle(cornerRadius: DS.Radius.group, style: .continuous))
            .dsSurface(radius: DS.Radius.group, elevation: elevation)
    }
}

// MARK: - Section label

/// The small uppercase heading above a group.
///
/// Uppercase text needs letter-spacing that lowercase doesn't: the glyphs are all
/// cap-height with no ascenders or descenders to separate them, so at default tracking
/// they read as a single block rather than as words.
struct DSSectionLabel: View {
    let title: String
    var icon: String?

    var body: some View {
        HStack(spacing: DS.Space.xs + 2) {
            if let icon {
                HugeIcon(icon, size: DS.Icon.label, weight: 2).foregroundStyle(.tertiary)
            }
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.7)
        }
    }
}

// MARK: - Note

/// A glyph and a line of text — the one shape for every hint, warning and receipt.
///
/// These were all `Label`s, and `Label` sizes its icon column for a `.body` row. Beside
/// `.caption` text that column is about 20pt of indent, so every note in the panel began
/// well to the right of the row it was describing: the panel had two leading edges, one
/// for its controls and a deeper one for anything it wanted to say about them. Here the
/// glyph sits in a caption-sized column and the text starts one spacing step after it, so
/// a note, a checklist row and the panel's own inset all share one edge.
///
/// The baseline guide is why this isn't simply `HStack(alignment: .firstTextBaseline)`: a
/// stroked path has no baseline, so SwiftUI falls back to aligning the glyph's *bottom*
/// edge to the first line's baseline, which leaves it floating high above a note that
/// wraps to two lines.
struct DSNote<Content: View>: View {
    let icon: String
    var tint: Color = .secondary
    var font: Font = DS.Typo.note
    var iconSize: CGFloat = DS.Icon.caption
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
            HugeIcon(icon, size: iconSize)
                .foregroundStyle(tint)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
            content
                .font(font)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Separator

/// The line between rows in a group.
///
/// Inset from the leading edge, and drawn from the text colour at low alpha rather than
/// `Divider()`: a full-bleed divider cuts the group in two, while one that starts where
/// the text starts reads as separating items *within* something.
struct DSSeparator: View {
    var inset: CGFloat = DS.Space.m

    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, inset)
    }
}

// MARK: - Confirmation

/// An inline "are you sure", for surfaces where a modal sheet can't be used or shouldn't.
///
/// Inside a `MenuBarExtra` window it can't: a `confirmationDialog` draws over the popover
/// but its buttons never receive the click, because pressing makes the popover resign key
/// and tear itself down first. It also shouldn't — a menu-bar panel throwing a system
/// modal is the wrong shape for what is really just a question about the panel.
///
/// The destructive action is the only tinted, filled control in view. When two buttons sit
/// together, the one that differs is the one that gets read; making both look the same is
/// how people confirm things they meant to cancel.
struct DSConfirmCard: View {
    let title: String
    let message: String
    var confirmTitle: String = "Turn On"
    var tint: Color = .red
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text(title).font(.callout.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: DS.Space.s) {
                Button("Cancel", action: onCancel)
                    .controlSize(.small)
                Button(confirmTitle, action: onConfirm)
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
                Spacer(minLength: 0)
            }
        }
        .padding(DS.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface(radius: DS.Radius.control + DS.Space.xs,
                   elevation: .flat,
                   fill: tint.opacity(0.11),
                   borderOpacity: 0,
                   highlight: false)
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.control + DS.Space.xs, style: .continuous)
                .strokeBorder(tint.opacity(0.30), lineWidth: 1)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}


// MARK: - Segmented control

/// A segmented picker that belongs to this panel rather than to a form.
///
/// `Picker(.segmented)` is an `NSSegmentedControl` underneath, and inside
/// `MenuBarExtra(.window)` that control arrives as first responder wearing a blue focus
/// ring — something no system menu-bar panel ever draws, so it reads as a rendering fault
/// rather than as focus. SwiftUI's `.focusEffectDisabled()` governs SwiftUI's own focus
/// effects and doesn't reach AppKit's ring. It also sizes every segment to its own label,
/// which is why four modes came out four different widths.
///
/// Drawn here instead: equal segments, one pill that slides between them, and no AppKit
/// control anywhere in it — so there is no ring to suppress in the first place.
struct DSSegmentedControl<Value: Hashable>: View {
    let items: [Value]
    let title: (Value) -> String
    @Binding var selection: Value

    /// Inset of the pill inside the track. The pill's radius is the track's minus this, or
    /// the two curves run at different rates and the gap pinches at the corners.
    private let padding: CGFloat = 2

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                segment(item)
            }
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .animation(.snappy(duration: DS.Duration.state), value: selection)
    }

    private func segment(_ item: Value) -> some View {
        let selected = item == selection
        return Button {
            if !selected { selection = item }
        } label: {
            Text(title(item))
                .font(.footnote.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, DS.Space.hair)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Space.xs + DS.Space.hair)
                .background {
                    if selected {
                        // No border on the pill. A stroke plus a fill on a control this
                        // small is two edges describing the same shape, and at 22pt tall it
                        // reads as a button that wandered into a segmented control.
                        RoundedRectangle(cornerRadius: DS.Radius.control - padding,
                                         style: .continuous)
                            .fill(Color.primary.opacity(0.14))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

// MARK: - Menu panel surface

/// The menu-bar panel's own background: the system's menu material, not a flat fill.
///
/// `MenuBarExtra(.window)` hands you a plain opaque window and nothing else. Everything
/// macOS's own menu-bar panels have — the translucency that picks up the desktop behind
/// them, the way they sit *over* the screen rather than on it — comes from an
/// `NSVisualEffectView`, and without one the panel reads as a grey rectangle pasted onto
/// the display. That is the single thing that separates a menu-bar app that looks native
/// from one that looks like a window someone forgot to style.
///
/// `.behindWindow` blending is the important part: it samples what is actually behind the
/// panel. `.withinWindow` would blur the app's own content against itself, which looks
/// like a mistake because it is one.
struct MenuPanelBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .behindWindow
        // `.active` rather than `.followsWindowActiveState`: a menu-bar panel is dismissed
        // the moment it stops being key, so "inactive" is a state it is never seen in — but
        // it *is* the state it briefly renders in while opening, which showed as a flash of
        // flat grey before the material caught up.
        view.state = .active
        return view
    }

    // Deliberately does nothing.
    //
    // An earlier version reached up and set `isOpaque = false` / `backgroundColor = .clear`
    // on the hosting window, reasoning that `.behindWindow` blending needs a see-through
    // window. It does — but SwiftUI's `MenuBarExtra` panel is not ours to re-configure, and
    // clearing its background made the whole panel render invisible: no material, no
    // content, just the desktop where the menu should be. The window stays as SwiftUI
    // built it.
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// Fill, hairline, rounded corners — the panel's whole surface.
///
/// Opaque, and that is the decision. `NSVisualEffectView` is what the system's own panels
/// use, but `.behindWindow` blending samples whatever the panel happens to be over, so the
/// same menu read as near-black on the desktop and as washed grey — tinted by whatever was
/// underneath — over an editor. A control panel whose background depends on the window
/// behind it isn't translucent, it's unpredictable, and every fill inside it (rows, tiles,
/// the segmented track) is drawn as a percentage of that background. One flat surface makes
/// all of them mean the same thing every time the menu opens.
private struct MenuPanelChrome: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let radius: CGFloat

    /// The surface itself. Not `windowBackgroundColor` — that is the grey macOS paints
    /// *windows*, several steps lighter than a menu, and against the desktop it made the
    /// panel read as a settings window that had parked under the menu bar. These are the
    /// values the system's own menu-bar panels land on once their material has resolved.
    private var fill: Color {
        scheme == .dark
            ? Color(red: 0.11, green: 0.11, blue: 0.12)
            : Color(red: 0.97, green: 0.97, blue: 0.98)
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background(fill)
            .clipShape(shape)
            .overlay {
                // One hairline, from the text colour, so it holds its relationship to the
                // fill in either appearance instead of being a grey that only works
                // against one of them.
                shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

/// Sizes the hosting window to the view, and clips it to the panel's own corner.
///
/// `MenuBarExtra(.window)` sizes its panel from the content's frame, but only upwards: it
/// grows when the content grows and keeps the larger size when the content shrinks. Switch
/// from Extreme Performance (two extra lines of caption) back to Off and the window stays
/// ~80pt taller than the panel inside it — and since the panel paints only its own frame,
/// that difference is a see-through band above it with the desktop showing through.
///
/// So the window is told. The top edge is pinned while the height changes, because the
/// panel hangs from the menu bar: resizing around the AppKit origin (bottom-left) would
/// slide it down the screen every time a section opened.
struct WindowSizer: NSViewRepresentable {
    let size: CGSize
    /// The radius the panel draws itself with. The window is clipped to the same shape —
    /// see `clipToPanelShape`, and keep the two in step or the corner doubles again.
    var radius: CGFloat = DS.Radius.group

    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    /// Clip everything the window paints to the shape the panel actually draws.
    ///
    /// `MenuBarExtra(.window)` doesn't hand you a bare window: it paints its own backdrop
    /// with a corner radius of about 4pt, and our panel draws a 14pt *continuous* corner
    /// inside that. A continuous corner cuts further in along the diagonal than a circular
    /// one of the same radius, so the system's shallower corner stuck out past ours — a
    /// lighter, almost-square shoulder in each of the four corners, which is what read as
    /// "the radius is wrong". Clearing `backgroundColor` never touched it, because the
    /// backdrop isn't the window's background colour.
    ///
    /// So the content layer carries the mask. `.continuous` on the layer is the same
    /// squircle `RoundedRectangle(style: .continuous)` draws, which is the only way the
    /// mask and the hairline we stroke inside it describe one curve rather than two.
    private func clipToPanelShape(_ window: NSWindow) {
        guard let content = window.contentView else { return }
        content.wantsLayer = true
        guard let layer = content.layer else { return }
        if layer.cornerRadius != radius {
            layer.cornerRadius = radius
            layer.cornerCurve = .continuous
            layer.masksToBounds = true
            window.invalidateShadow()
        }
    }

    func updateNSView(_ view: NSView, context: Context) {
        // Next runloop pass: during `updateNSView` the window is mid-layout, and setting
        // its frame from inside that is how you get a window that fights its own content.
        DispatchQueue.main.async {
            guard let window = view.window, size.width > 0, size.height > 0 else { return }

            // The window is square and the panel is round, so an opaque window paints its
            // own corners just outside ours — four dark right angles tucked behind the
            // rounded ones. Clearing the backing is what lets the corner be a corner, and
            // the shadow follow the shape we actually drew rather than the window's box.
            //
            // (An earlier attempt at this made the whole panel vanish. That version was
            // painting the background with an `NSVisualEffectView` blending `.behindWindow`,
            // which has nothing to blend against once the window stops drawing — the panel
            // is a solid `Color` now, so it paints itself and there is nothing to lose.)
            if window.backgroundColor != .clear {
                window.backgroundColor = .clear
            }
            // And an opaque window paints its corners whatever its background colour is.
            if window.isOpaque { window.isOpaque = false }
            clipToPanelShape(window)

            let current = window.frame.size
            guard abs(current.height - size.height) > 0.5
                    || abs(current.width - size.width) > 0.5 else {
                return
            }
            var frame = window.frame
            frame.origin.y += frame.size.height - size.height
            frame.size = size
            window.setFrame(frame, display: true)
            // The shadow is cast from the old shape until it's told otherwise.
            window.invalidateShadow()
        }
    }
}

extension View {
    /// Give a menu-bar panel the system's own surface: material, hairline, rounded corners.
    ///
    /// The radius has to be drawn here rather than left to the window. SwiftUI's panel
    /// clips its content to a rounded rect but the content's own background is painted
    /// underneath that clip, so an opaque fill squares the corners back off — which is why
    /// this panel had four sharp corners sitting inside a rounded shadow.
    func dsMenuPanel(radius: CGFloat = DS.Radius.group) -> some View {
        modifier(MenuPanelChrome(radius: radius))
    }
}
