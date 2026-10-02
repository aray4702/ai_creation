import SwiftUI

/// Procedurally generated album artwork (no bundled images).
struct ArtworkView: View {
    var seed: UInt64
    var cornerRadius: CGFloat = 6
    var title: String? = nil

    var body: some View {
        Canvas { ctx, size in
            var rng = LCG(seed)
            let h1 = rng.unit()
            let h2 = (h1 + 0.12 + rng.unit() * 0.35).truncatingRemainder(dividingBy: 1)
            let c1 = Color(hue: h1, saturation: 0.55 + rng.unit() * 0.35, brightness: 0.55 + rng.unit() * 0.35)
            let c2 = Color(hue: h2, saturation: 0.6 + rng.unit() * 0.3, brightness: 0.25 + rng.unit() * 0.35)
            let rect = CGRect(origin: .zero, size: size)
            ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: [c1, c2]),
                                                       startPoint: .zero,
                                                       endPoint: CGPoint(x: size.width, y: size.height)))
            let w = size.width, h = size.height
            let style = Int(seed % 4)
            switch style {
            case 0: // concentric rings
                let cx = w * (0.3 + rng.unit() * 0.4), cy = h * (0.3 + rng.unit() * 0.4)
                for i in stride(from: 6, through: 1, by: -1) {
                    let r = CGFloat(i) * w * 0.11
                    ctx.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                               with: .color(.white.opacity(0.10 + Double(6 - i) * 0.03)), lineWidth: max(1, w * 0.012))
                }
            case 1: // soft orbs
                for _ in 0..<5 {
                    let r = w * (0.15 + rng.unit() * 0.3)
                    let x = w * rng.unit(), y = h * rng.unit()
                    let hue = (h1 + rng.unit() * 0.3).truncatingRemainder(dividingBy: 1)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .radialGradient(Gradient(colors: [Color(hue: hue, saturation: 0.7, brightness: 1).opacity(0.75), .clear]),
                                                   center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
                }
            case 2: // waves
                for i in 0..<7 {
                    var p = Path()
                    let base = h * (0.25 + CGFloat(i) * 0.09)
                    let amp = h * (0.03 + rng.unit() * 0.05)
                    let freq = 1.5 + rng.unit() * 2
                    p.move(to: CGPoint(x: 0, y: base))
                    for xs in stride(from: 0, through: w, by: max(1, w / 60)) {
                        p.addLine(to: CGPoint(x: xs, y: base + amp * sin(Double(xs / w) * .pi * 2 * freq + Double(i))))
                    }
                    ctx.stroke(p, with: .color(.white.opacity(0.12 + Double(i) * 0.04)), lineWidth: max(1, w * 0.014))
                }
            default: // geometric blocks
                for _ in 0..<6 {
                    let bw = w * (0.15 + rng.unit() * 0.35), bh = h * (0.1 + rng.unit() * 0.3)
                    let r = CGRect(x: w * rng.unit() - bw / 2, y: h * rng.unit() - bh / 2, width: bw, height: bh)
                    ctx.fill(Path(roundedRect: r, cornerRadius: w * 0.03),
                             with: .color(.white.opacity(0.08 + rng.unit() * 0.18)))
                }
            }
            // gentle vignette
            ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: [.clear, .black.opacity(0.25)]),
                                                       startPoint: CGPoint(x: 0, y: h * 0.5),
                                                       endPoint: CGPoint(x: 0, y: h)))
        }
        .overlay(alignment: .bottomLeading) {
            if let title {
                GeometryReader { geo in
                    Text(title)
                        .font(Theme.font(max(8, geo.size.width * 0.08), .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .padding(geo.size.width * 0.07)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
        .aspectRatio(1, contentMode: .fit)
    }
}

/// 2×2 mosaic used for playlist covers.
struct MosaicArtworkView: View {
    var seeds: [UInt64]
    var fallbackSeed: UInt64
    var cornerRadius: CGFloat = 8

    var body: some View {
        let s = seeds.isEmpty ? [fallbackSeed] : seeds
        Group {
            if s.count < 4 {
                ArtworkView(seed: s[0], cornerRadius: 0)
            } else {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow { ArtworkView(seed: s[0], cornerRadius: 0); ArtworkView(seed: s[1], cornerRadius: 0) }
                    GridRow { ArtworkView(seed: s[2], cornerRadius: 0); ArtworkView(seed: s[3], cornerRadius: 0) }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
