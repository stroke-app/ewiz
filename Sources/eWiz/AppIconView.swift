import SwiftUI
import AppKit

/// The app's own icon, the one the Dock and Finder show, read from the bundle.
///
/// About and the license window used to draw a battery glyph in a tile as a stand-in, which
/// was a second copy of the brand that had to be redrawn by hand whenever the icon changed,
/// and wasn't. Reading the bundle's icon means a new `branding/` icon shows up here with
/// nothing else to touch. The icon carries its own tile and margin, so none is added.
struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityLabel("eWiz")
    }
}
