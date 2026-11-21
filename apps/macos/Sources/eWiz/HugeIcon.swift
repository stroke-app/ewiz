import SwiftUI

/// One drawable element of a HugeIcon (their icons are stroke paths on a 24×24 grid).
enum HugeElement {
    case path(String)
    case circle(Double, Double, Double)
    case rect(Double, Double, Double, Double, Double)
    case line(Double, Double, Double, Double)

    func add(to path: inout Path) {
        switch self {
        case .path(let d):
            HugeElement.parse(d, into: &path)
        case .circle(let cx, let cy, let r):
            path.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        case .rect(let x, let y, let w, let h, let rx):
            path.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h),
                                cornerSize: CGSize(width: rx, height: rx))
        case .line(let x1, let y1, let x2, let y2):
            path.move(to: CGPoint(x: x1, y: y1)); path.addLine(to: CGPoint(x: x2, y: y2))
        }
    }

    /// Minimal SVG `d` parser — HugeIcons only use absolute M, L, H, V, C, Z.
    private static func parse(_ d: String, into path: inout Path) {
        let s = Array(d)
        let n = s.count
        var i = 0
        func skip() { while i < n, s[i] == " " || s[i] == "," { i += 1 } }
        func num() -> CGFloat {
            skip()
            var t = ""
            if i < n, s[i] == "-" || s[i] == "+" { t.append(s[i]); i += 1 }
            while i < n, s[i].isNumber || s[i] == "." { t.append(s[i]); i += 1 }
            return CGFloat(Double(t) ?? 0)
        }
        var cur = CGPoint.zero, startPt = CGPoint.zero, cmd: Character = " "
        while i < n {
            skip()
            guard i < n else { break }
            if s[i].isLetter { cmd = s[i]; i += 1 }
            switch cmd {
            case "M":
                cur = CGPoint(x: num(), y: num()); startPt = cur
                path.move(to: cur); cmd = "L"   // implicit line-to for extra pairs
            case "L":
                cur = CGPoint(x: num(), y: num()); path.addLine(to: cur)
            case "H":
                cur.x = num(); path.addLine(to: cur)
            case "V":
                cur.y = num(); path.addLine(to: cur)
            case "C":
                let c1 = CGPoint(x: num(), y: num())
                let c2 = CGPoint(x: num(), y: num())
                cur = CGPoint(x: num(), y: num())
                path.addCurve(to: cur, control1: c1, control2: c2)
            case "Z", "z":
                path.closeSubpath(); cur = startPt
            default:
                i += 1
            }
        }
    }
}

/// The combined path for a catalog icon, scaled to the target rect (24-grid → rect).
private struct HugeIconShape: Shape {
    let key: String
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for element in HugeIcons.shapes[key] ?? [] { element.add(to: &p) }
        let scale = min(rect.width, rect.height) / 24
        return p.applying(CGAffineTransform(scaleX: scale, y: scale))
    }
}

/// A premium HugeIcons stroke glyph. Tints with the surrounding `foregroundStyle`,
/// so it drops in wherever an `Image(systemName:)` was used.
struct HugeIcon: View {
    let key: String
    var size: CGFloat
    var weight: CGFloat

    init(_ key: String, size: CGFloat = 17, weight: CGFloat = 1.8) {
        self.key = key; self.size = size; self.weight = weight
    }

    var body: some View {
        HugeIconShape(key: key)
            .stroke(style: StrokeStyle(lineWidth: weight * size / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}
