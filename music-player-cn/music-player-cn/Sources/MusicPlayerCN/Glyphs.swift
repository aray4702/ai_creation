import SwiftUI

/// Hand-drawn vector icons. The app deliberately uses no system symbol set, logos or brand fonts.
enum Glyph {
    case play, pause, next, previous
    case heart, heartFill
    case sidebar, queue, mini, expand
    case volumeLow, volumeHigh, mute
    case shuffle, repeatAll, repeatOne
    case home, album, artist, note, playlist, search
    case plus, close, back, trash, grip, spark

    /// Filled glyphs are painted, the rest are stroked.
    var filled: Bool {
        switch self {
        case .play, .pause, .next, .previous, .heartFill: true
        default: false
        }
    }
}

struct GlyphShape: Shape {
    var glyph: Glyph

    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * w, y: r.minY + y * h) }
        var path = Path()

        func heart() {
            path.move(to: p(0.5, 0.88))
            path.addCurve(to: p(0.06, 0.36), control1: p(0.28, 0.72), control2: p(0.06, 0.58))
            path.addCurve(to: p(0.5, 0.2), control1: p(0.06, 0.08), control2: p(0.4, 0.04))
            path.addCurve(to: p(0.94, 0.36), control1: p(0.6, 0.04), control2: p(0.94, 0.08))
            path.addCurve(to: p(0.5, 0.88), control1: p(0.94, 0.58), control2: p(0.72, 0.72))
            path.closeSubpath()
        }
        func speaker() {
            path.move(to: p(0.08, 0.38)); path.addLine(to: p(0.26, 0.38)); path.addLine(to: p(0.48, 0.18))
            path.addLine(to: p(0.48, 0.82)); path.addLine(to: p(0.26, 0.62)); path.addLine(to: p(0.08, 0.62))
            path.closeSubpath()
        }
        func arc(_ radius: CGFloat) {
            path.addArc(center: p(0.48, 0.5), radius: radius * w, startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: false)
        }
        func loop() {
            path.move(to: p(0.2, 0.62)); path.addLine(to: p(0.2, 0.42))
            path.addQuadCurve(to: p(0.34, 0.28), control: p(0.2, 0.28))
            path.addLine(to: p(0.84, 0.28))
            path.move(to: p(0.72, 0.16)); path.addLine(to: p(0.84, 0.28)); path.addLine(to: p(0.72, 0.4))
            path.move(to: p(0.8, 0.38)); path.addLine(to: p(0.8, 0.58))
            path.addQuadCurve(to: p(0.66, 0.72), control: p(0.8, 0.72))
            path.addLine(to: p(0.16, 0.72))
            path.move(to: p(0.28, 0.6)); path.addLine(to: p(0.16, 0.72)); path.addLine(to: p(0.28, 0.84))
        }

        switch glyph {
        case .play:
            path.move(to: p(0.22, 0.1)); path.addLine(to: p(0.88, 0.5)); path.addLine(to: p(0.22, 0.9)); path.closeSubpath()
        case .pause:
            path.addRoundedRect(in: CGRect(origin: p(0.18, 0.1), size: CGSize(width: w * 0.22, height: h * 0.8)), cornerSize: CGSize(width: w * 0.05, height: w * 0.05))
            path.addRoundedRect(in: CGRect(origin: p(0.6, 0.1), size: CGSize(width: w * 0.22, height: h * 0.8)), cornerSize: CGSize(width: w * 0.05, height: w * 0.05))
        case .next:
            path.move(to: p(0.08, 0.16)); path.addLine(to: p(0.48, 0.5)); path.addLine(to: p(0.08, 0.84)); path.closeSubpath()
            path.move(to: p(0.46, 0.16)); path.addLine(to: p(0.86, 0.5)); path.addLine(to: p(0.46, 0.84)); path.closeSubpath()
            path.addRect(CGRect(origin: p(0.84, 0.16), size: CGSize(width: w * 0.1, height: h * 0.68)))
        case .previous:
            path.move(to: p(0.92, 0.16)); path.addLine(to: p(0.52, 0.5)); path.addLine(to: p(0.92, 0.84)); path.closeSubpath()
            path.move(to: p(0.54, 0.16)); path.addLine(to: p(0.14, 0.5)); path.addLine(to: p(0.54, 0.84)); path.closeSubpath()
            path.addRect(CGRect(origin: p(0.06, 0.16), size: CGSize(width: w * 0.1, height: h * 0.68)))
        case .heart, .heartFill:
            heart()
        case .sidebar:
            path.addRoundedRect(in: CGRect(origin: p(0.08, 0.18), size: CGSize(width: w * 0.84, height: h * 0.64)), cornerSize: CGSize(width: w * 0.12, height: w * 0.12))
            path.move(to: p(0.38, 0.18)); path.addLine(to: p(0.38, 0.82))
            path.move(to: p(0.16, 0.34)); path.addLine(to: p(0.28, 0.34))
            path.move(to: p(0.16, 0.48)); path.addLine(to: p(0.28, 0.48))
        case .queue:
            for y in [0.24, 0.46] as [CGFloat] { path.move(to: p(0.1, y)); path.addLine(to: p(0.9, y)) }
            path.move(to: p(0.1, 0.68)); path.addLine(to: p(0.5, 0.68))
            path.move(to: p(0.64, 0.6)); path.addLine(to: p(0.9, 0.76)); path.addLine(to: p(0.64, 0.9)); path.closeSubpath()
        case .mini:
            path.addRoundedRect(in: CGRect(origin: p(0.06, 0.16), size: CGSize(width: w * 0.88, height: h * 0.68)), cornerSize: CGSize(width: w * 0.1, height: w * 0.1))
            path.addRoundedRect(in: CGRect(origin: p(0.48, 0.5), size: CGSize(width: w * 0.34, height: h * 0.22)), cornerSize: CGSize(width: w * 0.05, height: w * 0.05))
        case .expand:
            path.move(to: p(0.56, 0.14)); path.addLine(to: p(0.86, 0.14)); path.addLine(to: p(0.86, 0.44))
            path.move(to: p(0.86, 0.14)); path.addLine(to: p(0.56, 0.44))
            path.move(to: p(0.44, 0.86)); path.addLine(to: p(0.14, 0.86)); path.addLine(to: p(0.14, 0.56))
            path.move(to: p(0.14, 0.86)); path.addLine(to: p(0.44, 0.56))
        case .volumeLow:
            speaker(); arc(0.18)
        case .volumeHigh:
            speaker(); arc(0.18); arc(0.34)
        case .mute:
            speaker()
            path.move(to: p(0.64, 0.36)); path.addLine(to: p(0.92, 0.64))
            path.move(to: p(0.92, 0.36)); path.addLine(to: p(0.64, 0.64))
        case .shuffle:
            path.move(to: p(0.08, 0.28)); path.addLine(to: p(0.3, 0.28))
            path.addCurve(to: p(0.86, 0.72), control1: p(0.56, 0.28), control2: p(0.56, 0.72))
            path.move(to: p(0.08, 0.72)); path.addLine(to: p(0.3, 0.72))
            path.addCurve(to: p(0.86, 0.28), control1: p(0.56, 0.72), control2: p(0.56, 0.28))
            path.move(to: p(0.74, 0.16)); path.addLine(to: p(0.88, 0.28)); path.addLine(to: p(0.74, 0.4))
            path.move(to: p(0.74, 0.6)); path.addLine(to: p(0.88, 0.72)); path.addLine(to: p(0.74, 0.84))
        case .repeatAll:
            loop()
        case .repeatOne:
            loop()
            path.move(to: p(0.46, 0.44)); path.addLine(to: p(0.52, 0.4)); path.addLine(to: p(0.52, 0.6))
        case .home:
            path.move(to: p(0.1, 0.48)); path.addLine(to: p(0.5, 0.12)); path.addLine(to: p(0.9, 0.48))
            path.move(to: p(0.2, 0.4)); path.addLine(to: p(0.2, 0.88)); path.addLine(to: p(0.8, 0.88)); path.addLine(to: p(0.8, 0.4))
            path.move(to: p(0.42, 0.88)); path.addLine(to: p(0.42, 0.64)); path.addLine(to: p(0.58, 0.64)); path.addLine(to: p(0.58, 0.88))
        case .album:
            path.addRoundedRect(in: CGRect(origin: p(0.08, 0.08), size: CGSize(width: w * 0.84, height: h * 0.84)), cornerSize: CGSize(width: w * 0.1, height: w * 0.1))
            path.addEllipse(in: CGRect(origin: p(0.28, 0.28), size: CGSize(width: w * 0.44, height: h * 0.44)))
            path.addEllipse(in: CGRect(origin: p(0.45, 0.45), size: CGSize(width: w * 0.1, height: h * 0.1)))
        case .artist:
            path.addEllipse(in: CGRect(origin: p(0.32, 0.1), size: CGSize(width: w * 0.36, height: h * 0.36)))
            path.move(to: p(0.12, 0.9))
            path.addCurve(to: p(0.88, 0.9), control1: p(0.14, 0.5), control2: p(0.86, 0.5))
        case .note:
            path.addEllipse(in: CGRect(origin: p(0.14, 0.62), size: CGSize(width: w * 0.3, height: h * 0.24)))
            path.move(to: p(0.44, 0.74)); path.addLine(to: p(0.44, 0.12))
            path.addQuadCurve(to: p(0.84, 0.36), control: p(0.7, 0.14))
        case .playlist:
            for y in [0.2, 0.4, 0.6] as [CGFloat] { path.move(to: p(0.08, y)); path.addLine(to: p(0.56, y)) }
            path.addEllipse(in: CGRect(origin: p(0.54, 0.7), size: CGSize(width: w * 0.2, height: h * 0.16)))
            path.move(to: p(0.74, 0.78)); path.addLine(to: p(0.74, 0.28)); path.addLine(to: p(0.92, 0.36))
        case .search:
            path.addEllipse(in: CGRect(origin: p(0.1, 0.1), size: CGSize(width: w * 0.56, height: h * 0.56)))
            path.move(to: p(0.58, 0.58)); path.addLine(to: p(0.9, 0.9))
        case .plus:
            path.move(to: p(0.5, 0.14)); path.addLine(to: p(0.5, 0.86))
            path.move(to: p(0.14, 0.5)); path.addLine(to: p(0.86, 0.5))
        case .close:
            path.move(to: p(0.2, 0.2)); path.addLine(to: p(0.8, 0.8))
            path.move(to: p(0.8, 0.2)); path.addLine(to: p(0.2, 0.8))
        case .back:
            path.move(to: p(0.64, 0.14)); path.addLine(to: p(0.3, 0.5)); path.addLine(to: p(0.64, 0.86))
        case .trash:
            path.move(to: p(0.12, 0.24)); path.addLine(to: p(0.88, 0.24))
            path.move(to: p(0.38, 0.24)); path.addLine(to: p(0.4, 0.1)); path.addLine(to: p(0.6, 0.1)); path.addLine(to: p(0.62, 0.24))
            path.move(to: p(0.2, 0.24)); path.addLine(to: p(0.26, 0.9)); path.addLine(to: p(0.74, 0.9)); path.addLine(to: p(0.8, 0.24))
        case .grip:
            for y in [0.3, 0.5, 0.7] as [CGFloat] { path.move(to: p(0.2, y)); path.addLine(to: p(0.8, y)) }
        case .spark:
            path.move(to: p(0.5, 0.06))
            path.addQuadCurve(to: p(0.94, 0.5), control: p(0.56, 0.44))
            path.addQuadCurve(to: p(0.5, 0.94), control: p(0.56, 0.56))
            path.addQuadCurve(to: p(0.06, 0.5), control: p(0.44, 0.56))
            path.addQuadCurve(to: p(0.5, 0.06), control: p(0.44, 0.44))
            path.closeSubpath()
        }
        return path
    }
}

struct Icon: View {
    var glyph: Glyph
    var size: CGFloat = 16
    var weight: CGFloat = 1.6

    var body: some View {
        Group {
            if glyph.filled {
                GlyphShape(glyph: glyph).fill(style: FillStyle(eoFill: false))
            } else {
                GlyphShape(glyph: glyph)
                    .stroke(style: StrokeStyle(lineWidth: weight * size / 16, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
    }
}

/// App mark: an original gradient tile with a sound-wave motif (not any existing brand).
struct AppMark: View {
    var size: CGFloat = 28
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
            HStack(spacing: size * 0.07) {
                ForEach([0.35, 0.7, 0.5, 0.85, 0.4], id: \.self) { f in
                    Capsule().fill(.white).frame(width: size * 0.08, height: size * 0.62 * f)
                }
            }
        }
        .frame(width: size, height: size)
    }
}
