import AppKit
import QuartzCore

/// Full-display effects: confetti and the portal Clawd uses to go to another Desktop.
/// Each display gets one click-through panel, shown only while an effect plays.
@MainActor
final class Effects {
    private var panels: [String: NSPanel] = [:]
    private var users: [String: Int] = [:]

    func confetti(on screen: NSScreen, seconds: Double = 3.5) {
        let (panel, key) = overlay(for: screen)
        guard let layer = panel.contentView?.layer else { return }
        let emitter = CAEmitterLayer()
        emitter.frame = layer.bounds
        emitter.emitterPosition = CGPoint(x: layer.bounds.midX, y: layer.bounds.maxY + 10)
        emitter.emitterSize = CGSize(width: layer.bounds.width, height: 1)
        emitter.emitterShape = .line
        let colors: [CGColor] = [Sprite.body, Sprite.yellow, Sprite.teal, Sprite.white, Sprite.pumpkin,
                                 CGColor(srgbRed: 0.6, green: 0.45, blue: 0.95, alpha: 1)]
        emitter.emitterCells = colors.map { color in
            let cell = CAEmitterCell()
            cell.contents = Self.chip
            cell.color = color
            cell.birthRate = 28
            cell.lifetime = 6
            cell.velocity = 180
            cell.velocityRange = 120
            cell.emissionLongitude = -.pi / 2
            cell.emissionRange = .pi / 5
            cell.yAcceleration = -160
            cell.spin = 3
            cell.spinRange = 6
            cell.scale = 1
            cell.scaleRange = 0.5
            return cell
        }
        layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds + 3) { [weak self] in
            emitter.removeFromSuperlayer()
            self?.release(key)
        }
    }

    /// Opens a portal at `point` (AppKit coordinates) and returns a function that closes it.
    func portal(at point: CGPoint) -> () -> Void {
        let screen = World.screen(at: point) ?? World.screen(nearX: point.x)
        let (panel, key) = overlay(for: screen)
        guard let layer = panel.contentView?.layer else { return {} }
        let size = CGSize(width: 54, height: 120)
        let local = CGPoint(x: point.x - screen.frame.minX, y: point.y - screen.frame.minY + size.height / 2 - 6)
        let portal = CALayer()
        portal.bounds = CGRect(origin: .zero, size: size)
        portal.position = local

        let glow = CAShapeLayer()
        glow.path = CGPath(ellipseIn: CGRect(origin: .zero, size: size), transform: nil)
        glow.fillColor = CGColor(srgbRed: 0.25, green: 0.1, blue: 0.4, alpha: 0.9)
        glow.shadowColor = CGColor(srgbRed: 0.7, green: 0.4, blue: 1, alpha: 1)
        glow.shadowRadius = 16
        glow.shadowOpacity = 1
        glow.shadowOffset = .zero
        portal.addSublayer(glow)
        for (inset, color) in [(4.0, Sprite.body), (12.0, Sprite.pumpkin), (20.0, Sprite.yellow)] {
            let ring = CAShapeLayer()
            ring.path = CGPath(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset * 1.6), transform: nil)
            ring.fillColor = nil
            ring.strokeColor = color
            ring.lineWidth = 3
            ring.lineDashPattern = [10, 7]
            let spin = CABasicAnimation(keyPath: "lineDashPhase")
            spin.fromValue = 0
            spin.toValue = inset == 12 ? -34 : 34
            spin.duration = 0.6
            spin.repeatCount = .infinity
            ring.add(spin, forKey: "spin")
            portal.addSublayer(ring)
        }
        layer.addSublayer(portal)
        let open = CASpringAnimation(keyPath: "transform.scale.y")
        open.fromValue = 0.02
        open.toValue = 1
        open.damping = 9
        open.duration = open.settlingDuration
        portal.add(open, forKey: "open")

        return { [weak self] in
            CATransaction.begin()
            CATransaction.setCompletionBlock {
                portal.removeFromSuperlayer()
                self?.release(key)
            }
            let close = CABasicAnimation(keyPath: "transform.scale")
            close.toValue = 0.01
            close.duration = 0.25
            close.fillMode = .forwards
            close.isRemovedOnCompletion = false
            portal.add(close, forKey: "close")
            CATransaction.commit()
        }
    }

    private func overlay(for screen: NSScreen) -> (NSPanel, String) {
        let key = World.uuid(of: screen) ?? "\(screen.frame)"
        users[key, default: 0] += 1
        if let panel = panels[key] {
            panel.setFrame(screen.frame, display: false)
            panel.orderFrontRegardless()
            return (panel, key)
        }
        let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        panel.contentView = view
        panel.setFrame(screen.frame, display: false)
        panel.orderFrontRegardless()
        panels[key] = panel
        return (panel, key)
    }

    private func release(_ key: String) {
        users[key, default: 1] -= 1
        if users[key] == 0 { panels[key]?.orderOut(nil) }
    }

    private static let chip: CGImage? = {
        let context = CGContext(data: nil, width: 8, height: 12, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, // swiftlint:disable:this force_unwrapping
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.setFillColor(CGColor(gray: 1, alpha: 1))
        context?.fill(CGRect(x: 0, y: 0, width: 8, height: 12))
        return context?.makeImage()
    }()
}
