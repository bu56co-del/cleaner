import SwiftUI
import PawlyCore

enum Palette {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
    static let background = adaptive(0xFBF9F6, 0x242220)
    static let sidebar = adaptive(0xF3EEE8, 0x201E1D)
    static let card = adaptive(0xFFFFFF, 0x302C29)
    static let ink = adaptive(0x493C36, 0xF4E8DE)
    static let muted = adaptive(0x8D8178, 0xB6A99D)
    static let coral = adaptive(0xC96F54, 0xED9E80)
    static let peach = adaptive(0xF7E6DA, 0x51392F)
    static let sage = adaptive(0x738A72, 0xADC8A2)
    static let sageTint = adaptive(0xEAF0E6, 0x303C31)
    static let border = adaptive(0xE9E1D9, 0x493F38)
    static let lavender = adaptive(0x91819B, 0xBCA8C9)
    static let lavenderTint = adaptive(0xF0EAF4, 0x3E3445)
}

extension CleanupCategory {
    var icon: String { switch self { case .caches: "square.stack.3d.up"; case .logs: "doc.text"; case .installers: "shippingbox" } }
    var color: Color { switch self { case .caches: Palette.coral; case .logs: Palette.lavender; case .installers: Palette.sage } }
    var tint: Color { switch self { case .caches: Palette.peach; case .logs: Palette.lavenderTint; case .installers: Palette.sageTint } }
}

struct PawButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .padding(.horizontal, 15).padding(.vertical, 9)
            .foregroundStyle(prominent ? Color.white : Palette.ink)
            .background(prominent ? Palette.coral : Palette.card, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(prominent ? .clear : Palette.border, lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

struct IconTile: View {
    let icon: String
    var color: Color = Palette.coral
    var tint: Color = Palette.peach
    var body: some View {
        Image(systemName: icon).font(.system(size: 20, weight: .medium))
            .foregroundStyle(color).frame(width: 44, height: 44)
            .background(tint, in: RoundedRectangle(cornerRadius: 6))
    }
}

struct CatMark: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 44
            context.scaleBy(x: scale, y: scale)
            var head = Path()
            head.move(to: CGPoint(x: 6, y: 20))
            head.addLine(to: CGPoint(x: 6, y: 5))
            head.addQuadCurve(to: CGPoint(x: 17, y: 11), control: CGPoint(x: 13, y: 5))
            head.addQuadCurve(to: CGPoint(x: 27, y: 11), control: CGPoint(x: 22, y: 8))
            head.addQuadCurve(to: CGPoint(x: 38, y: 5), control: CGPoint(x: 36, y: 3))
            head.addLine(to: CGPoint(x: 38, y: 21))
            head.addCurve(to: CGPoint(x: 6, y: 20), control1: CGPoint(x: 45, y: 44), control2: CGPoint(x: -1, y: 44))
            context.fill(head, with: .color(Palette.peach))
            context.stroke(head, with: .color(Palette.coral), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            for x in [15.0, 29.0] {
                context.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: 22, width: 3, height: 4)), with: .color(Palette.ink))
            }
            var mouth = Path()
            mouth.move(to: CGPoint(x: 17, y: 29))
            mouth.addQuadCurve(to: CGPoint(x: 22, y: 29), control: CGPoint(x: 20, y: 33))
            mouth.addQuadCurve(to: CGPoint(x: 27, y: 29), control: CGPoint(x: 24, y: 33))
            context.stroke(mouth, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }.accessibilityHidden(true)
    }
}

struct Mascot: View {
    private static let artwork: NSImage? = {
        if let url = Bundle.main.url(forResource: "mascot", withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.module.url(forResource: "mascot", withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return nil
    }()
    var body: some View {
        if let image = Self.artwork {
            Image(nsImage: image).resizable().scaledToFit()
                .accessibilityLabel("A little cat sweeping with a broom")
        } else {
            CatMark().accessibilityLabel("Pawly cat")
        }
    }
}

struct PageHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 25, weight: .semibold, design: .rounded)).foregroundStyle(Palette.ink)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(Palette.muted)
        }
    }
}

extension View {
    func pawCard() -> some View {
        background(Palette.card, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
    }
}
