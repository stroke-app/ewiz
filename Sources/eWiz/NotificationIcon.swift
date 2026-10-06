import AppKit
import UserNotifications

/// Per-notification imagery for macOS notifications.
///
/// The big icon on the left of a notification is the app icon and an app cannot replace
/// it — that slot belongs to macOS, and it is the same for every alert eWiz posts. The
/// one image an app *can* vary per notification is an attachment, which the system draws
/// as a thumbnail on the right. So that's where the glyph goes: a thermometer for a heat
/// pause, a battery for the limit, a check for full. Not the slot you'd choose, but the
/// only one that exists, and it beats four identical banners.
///
/// Attachments are files, so each glyph is rendered once to the caches directory and
/// reused: re-rendering a PNG for every notification would be work for nothing, and
/// leaving them in a temporary directory that gets swept mid-notification loses the image.
enum NotificationIcon {

    /// An attachment showing `key` from the HugeIcons catalogue, or nil if it can't be
    /// rendered — in which case the notification is posted without one rather than not
    /// posted at all.
    @MainActor static func attachment(_ key: String, identifier: String) -> UNNotificationAttachment? {
        guard let url = render(key) else { return nil }
        return try? UNNotificationAttachment(identifier: identifier, url: url, options: nil)
    }

    /// Rendered at 128pt: notification thumbnails are drawn small, but the same file is
    /// used in Notification Center where they're larger, and a 1x glyph looks soft there.
    private static let side: CGFloat = 128

    @MainActor private static var rendered: [String: URL] = [:]

    @MainActor private static func render(_ key: String) -> URL? {
        if let existing = rendered[key], FileManager.default.fileExists(atPath: existing.path) {
            return existing
        }
        guard let directory = cachesDirectory() else { return nil }
        let url = directory.appendingPathComponent("notif-\(key)@\(Int(side)).png")

        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            // Light glyph on transparent: macOS composites the thumbnail on a light or dark
            // banner depending on appearance, and a mid-grey stroke reads on both. A pure
            // white glyph vanishes on a light banner; pure black vanishes on a dark one.
            let stroke = NSColor(white: 0.42, alpha: 1)
            stroke.setStroke()
            let scale = side / 24
            let path = HugeIconPath.path(for: key)
            path.transform(using: AffineTransform(scaleByX: scale, byY: -scale))
            path.transform(using: AffineTransform(translationByX: 0, byY: side))
            path.lineWidth = 1.8 * scale
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
            return true
        }

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]),
              (try? png.write(to: url, options: .atomic)) != nil
        else { return nil }

        rendered[key] = url
        return url
    }

    private static func cachesDirectory() -> URL? {
        guard let base = FileManager.default.urls(for: .cachesDirectory,
                                                 in: .userDomainMask).first else { return nil }
        let directory = base.appendingPathComponent("eWiz/NotificationIcons", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

/// Bridges the HugeIcons shape catalogue (built for SwiftUI `Path`) to `NSBezierPath`, so
/// the same glyphs can be rasterised outside a SwiftUI view.
enum HugeIconPath {
    static func path(for key: String) -> NSBezierPath {
        let path = NSBezierPath()
        for element in HugeIcons.shapes[key] ?? [] {
            switch element {
            case .path(let d):
                path.append(SVGPath.parse(d))
            case .circle(let cx, let cy, let r):
                path.appendOval(in: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            case .rect(let x, let y, let w, let h, let radius):
                path.append(NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h),
                                         xRadius: radius, yRadius: radius))
            case .line(let x1, let y1, let x2, let y2):
                path.move(to: NSPoint(x: x1, y: y1))
                path.line(to: NSPoint(x: x2, y: y2))
            }
        }
        return path
    }
}
