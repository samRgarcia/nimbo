import SpriteKit
import AppKit

/// Texturas dibujadas por código: la app no necesita imágenes.
enum Tex {
    static let dot = make(32, 32) { ctx in
        radial(ctx, x: 16, y: 16, radius: 16, alpha: 1)
    }

    static let glow = make(96, 96) { ctx in
        radial(ctx, x: 48, y: 48, radius: 48, alpha: 0.9)
        radial(ctx, x: 48, y: 48, radius: 14, alpha: 1)
    }

    static let blob = make(256, 256) { ctx in
        radial(ctx, x: 128, y: 128, radius: 128, alpha: 0.8)
    }

    static let streak = make(4, 48) { ctx in
        let space = CGColorSpaceCreateDeviceRGB()
        let parts: [CGFloat] = [0.82, 0.9, 1, 0.9, 0.82, 0.9, 1, 0]
        if let gradient = CGGradient(colorSpace: space, colorComponents: parts, locations: [0, 1], count: 2) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 2, y: 0), end: CGPoint(x: 2, y: 48), options: [])
        }
    }

    static let meteor = make(256, 8) { ctx in
        let space = CGColorSpaceCreateDeviceRGB()
        let parts: [CGFloat] = [1, 1, 1, 0, 1, 1, 1, 1]
        if let gradient = CGGradient(colorSpace: space, colorComponents: parts, locations: [0, 1], count: 2) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 4), end: CGPoint(x: 256, y: 4), options: [])
        }
    }

    static let petal = make(32, 24) { ctx in
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        ctx.fillEllipse(in: CGRect(x: 1, y: 3, width: 30, height: 18))
    }

    static let leaf = make(48, 32) { ctx in
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        ctx.move(to: CGPoint(x: 2, y: 16))
        ctx.addQuadCurve(to: CGPoint(x: 46, y: 16), control: CGPoint(x: 22, y: 38))
        ctx.addQuadCurve(to: CGPoint(x: 2, y: 16), control: CGPoint(x: 22, y: -6))
        ctx.fillPath()
    }

    static let cloud = make(512, 256) { ctx in
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [
            (130, 110, 100), (220, 140, 115), (320, 125, 110), (400, 105, 90), (260, 95, 100), (180, 90, 80),
        ]
        for (x, y, radius) in puffs {
            radial(ctx, x: x, y: y, radius: radius, alpha: 0.75)
        }
    }

    private static func radial(_ ctx: CGContext, x: CGFloat, y: CGFloat, radius: CGFloat, alpha: CGFloat) {
        let space = CGColorSpaceCreateDeviceRGB()
        let parts: [CGFloat] = [1, 1, 1, alpha, 1, 1, 1, 0]
        guard let gradient = CGGradient(colorSpace: space, colorComponents: parts, locations: [0, 1], count: 2) else { return }
        let center = CGPoint(x: x, y: y)
        ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: radius, options: [])
    }

    private static func make(_ width: Int, _ height: Int, _ draw: (CGContext) -> Void) -> SKTexture {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return SKTexture()
        }
        draw(ctx)
        guard let image = ctx.makeImage() else { return SKTexture() }
        return SKTexture(cgImage: image)
    }
}
