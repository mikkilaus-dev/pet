import AppKit

enum Eyes: Equatable { case open, blink, closed, happy, wide, squint, dizzy }
enum Arms: Equatable { case down, up, wave, reach, hold }
enum Costume: Equatable { case none, witch, santa, party, ghost }

struct Pose: Equatable {
    var facing: CGFloat = 1
    var eyes: Eyes = .open
    var look = 0
    var arms: Arms = .down
    var armPhase = false
    var legs = 0
    var mouth = 0
    var squash: CGFloat = 1
    var tilt: CGFloat = 0
    var scale: CGFloat = 1
    var costume: Costume = .none
    var alpha: CGFloat = 1
}

/// Clawd, drawn from the same 18 × 10 pixel grid as the terminal mascot: a wide body,
/// two slit eyes, two stubby arms and four legs. Rows count down from the top of the body.
enum Sprite {
    static let pixel: CGFloat = 5
    static let columns = 18
    static let rows = 10
    static var size: CGSize { CGSize(width: CGFloat(columns) * pixel, height: CGFloat(rows) * pixel) }

    static let body = CGColor(srgbRed: 0.851, green: 0.467, blue: 0.341, alpha: 1)
    static let ink = CGColor(srgbRed: 0.11, green: 0.07, blue: 0.06, alpha: 1)
    static let white = CGColor(srgbRed: 1, green: 0.98, blue: 0.95, alpha: 1)
    static let hat = CGColor(srgbRed: 0.18, green: 0.13, blue: 0.25, alpha: 1)
    static let pumpkin = CGColor(srgbRed: 0.95, green: 0.64, blue: 0.23, alpha: 1)
    static let red = CGColor(srgbRed: 0.82, green: 0.16, blue: 0.18, alpha: 1)
    static let teal = CGColor(srgbRed: 0.27, green: 0.68, blue: 0.66, alpha: 1)
    static let yellow = CGColor(srgbRed: 0.98, green: 0.82, blue: 0.27, alpha: 1)

    static func draw(_ pose: Pose, at feet: CGPoint, in ctx: CGContext, pixel s: CGFloat = pixel) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.setAlpha(pose.alpha)
        ctx.setShouldAntialias(pose.tilt != 0)
        ctx.translateBy(x: feet.x, y: feet.y)
        ctx.scaleBy(x: pose.scale, y: pose.scale)
        let middle = CGFloat(rows) * s / 2
        ctx.translateBy(x: 0, y: middle)
        ctx.rotate(by: pose.tilt)
        ctx.translateBy(x: 0, y: -middle)
        ctx.scaleBy(x: (2 - pose.squash) * pose.facing, y: pose.squash)

        func px(_ c: Int, _ r: Int, _ w: Int = 1, _ h: Int = 1, _ color: CGColor = body) {
            ctx.setFillColor(color)
            ctx.fill(CGRect(x: (CGFloat(c) - CGFloat(columns) / 2) * s, y: CGFloat(rows - r - h) * s,
                            width: CGFloat(w) * s, height: CGFloat(h) * s))
        }

        if pose.costume == .ghost {
            let sheet = CGColor(srgbRed: 0.97, green: 0.97, blue: 1, alpha: 0.92)
            px(4, -2, 10, 1, sheet)
            px(3, -1, 12, 1, sheet)
            px(2, 0, 14, 9, sheet)
            for c in stride(from: 2, to: 16, by: 4) { px(c + (pose.armPhase ? 2 : 0), 9, 2, 1, sheet) }
            px(5, 1, 2, 3, ink)
            px(11, 1, 2, 3, ink)
            px(8, 5, 2, pose.mouth > 0 ? 2 : 1, ink)
            return
        }

        px(3, 0, 12, 8)

        switch pose.arms {
        case .down:
            px(1, 4, 2, 2); px(15, 4, 2, 2)
        case .up, .hold:
            px(1, 2, 2, 2); px(0, 0, 2, 2); px(15, 2, 2, 2); px(16, 0, 2, 2)
        case .wave:
            px(1, 4, 2, 2); px(15, 2, 2, 2)
            if pose.armPhase { px(16, 0, 2, 2) } else { px(17, 1, 1, 2) }
        case .reach:
            px(1, 3, 2, 2); px(15, 4, 4, 2)
        }

        let legs: [(Int, Int)] = switch pose.legs {
        case 1: [(4, 2), (6, 1), (11, 2), (13, 1)]
        case 2: [(4, 1), (6, 2), (11, 1), (13, 2)]
        case 3: [(4, 1), (6, 1), (11, 1), (13, 1)]
        default: [(4, 2), (6, 2), (11, 2), (13, 2)]
        }
        for (c, h) in legs { px(c, 8, 1, h) }

        let l = 5 + pose.look, r = 12 + pose.look
        switch pose.eyes {
        case .open: px(l, 2, 1, 2, ink); px(r, 2, 1, 2, ink)
        case .blink: px(l, 3, 1, 1, ink); px(r, 3, 1, 1, ink)
        case .closed: px(l - 1, 3, 2, 1, ink); px(r, 3, 2, 1, ink)
        case .happy:
            for c in [l, r] { px(c, 2, 1, 1, ink); px(c - 1, 3, 1, 1, ink); px(c + 1, 3, 1, 1, ink) }
        case .wide:
            px(l, 1, 2, 3, ink); px(r - 1, 1, 2, 3, ink); px(l, 1, 1, 1, white); px(r - 1, 1, 1, 1, white)
        case .squint:
            px(4, 1, 1, 1, ink); px(5, 2, 1, 1, ink); px(4, 3, 1, 1, ink)
            px(13, 1, 1, 1, ink); px(12, 2, 1, 1, ink); px(13, 3, 1, 1, ink)
        case .dizzy:
            for c in [4, 11] {
                px(c, 1, 1, 1, ink); px(c + 2, 1, 1, 1, ink); px(c + 1, 2, 1, 1, ink)
                px(c, 3, 1, 1, ink); px(c + 2, 3, 1, 1, ink)
            }
        }
        if pose.mouth > 0 { px(8, 5, 2, pose.mouth, ink) }

        switch pose.costume {
        case .witch:
            px(1, -1, 16, 1, hat)
            px(5, -2, 8, 1, pumpkin)
            px(5, -3, 8, 1, hat); px(6, -4, 6, 1, hat); px(7, -5, 4, 1, hat)
            px(8, -6, 3, 1, hat); px(10, -7, 2, 1, hat); px(11, -8, 2, 1, hat)
        case .santa:
            px(2, -1, 14, 1, white)
            px(4, -2, 10, 1, red); px(5, -3, 8, 1, red); px(7, -4, 6, 1, red); px(10, -5, 4, 1, red)
            px(13, -7, 2, 2, white)
        case .party:
            px(6, -1, 6, 1, teal); px(7, -2, 4, 1, yellow); px(7, -3, 4, 1, teal)
            px(8, -4, 2, 1, yellow); px(8, -5, 2, 1, teal); px(8, -7, 2, 2, red)
        case .none, .ghost:
            break
        }
    }

    static func icon() -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 16), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            draw(Pose(), at: CGPoint(x: 11, y: 2), in: ctx, pixel: 1.15)
            return true
        }
        return image
    }
}
