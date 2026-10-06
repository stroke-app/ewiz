import SwiftUI
import AppKit
import EWizKit

/// Bridges `OKLab` into the two colour types AppKit and SwiftUI actually draw with.
///
/// Kept out of `EWizKit` on purpose: the privileged helper links that library and has
/// no business importing SwiftUI. The colour maths is shared; the drawing types are not.
extension Color {
    init(_ lab: OKLab, opacity: Double = 1) {
        let (r, g, b) = lab.sRGB
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

extension NSColor {
    convenience init(_ lab: OKLab, alpha: Double = 1) {
        let (r, g, b) = lab.sRGB
        self.init(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}
