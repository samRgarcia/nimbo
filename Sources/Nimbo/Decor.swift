import SpriteKit
import AppKit

/// Adornos del taller de invierno, dibujados con formas simples.
@MainActor
enum Decor {
    static let snowName = "snow"

    private static func rect(_ r: CGRect, _ color: NSColor, corner: CGFloat = 0) -> SKShapeNode {
        let node = SKShapeNode(rect: r, cornerRadius: corner)
        node.fillColor = color
        node.strokeColor = .clear
        return node
    }

    private static func poly(_ points: [CGPoint], _ color: NSColor) -> SKShapeNode {
        let path = CGMutablePath()
        path.addLines(between: points)
        path.closeSubpath()
        let node = SKShapeNode(path: path)
        node.fillColor = color
        node.strokeColor = .clear
        return node
    }

    private static func circle(_ radius: CGFloat, _ color: NSColor, x: CGFloat, y: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        node.fillColor = color
        node.strokeColor = .clear
        node.position = CGPoint(x: x, y: y)
        return node
    }

    // MARK: Cabaña

    static let chimneyTop = CGPoint(x: 12, y: 50)

    static func cabin() -> SKNode {
        let node = SKNode()
        let wood = NSColor(red: 0.45, green: 0.28, blue: 0.16, alpha: 1)
        let dark = NSColor(red: 0.3, green: 0.18, blue: 0.1, alpha: 1)
        node.addChild(rect(CGRect(x: 8, y: 30, width: 8, height: 18), dark))               // chimenea
        node.addChild(rect(CGRect(x: -22, y: 0, width: 44, height: 26), wood))             // paredes
        for line in 1..<4 {
            node.addChild(rect(CGRect(x: -22, y: CGFloat(line) * 6.5, width: 44, height: 0.8), dark))
        }
        node.addChild(poly([CGPoint(x: -28, y: 25), CGPoint(x: 0, y: 46), CGPoint(x: 28, y: 25)], dark))
        node.addChild(poly([CGPoint(x: -28, y: 28), CGPoint(x: 0, y: 49), CGPoint(x: 28, y: 28),
                            CGPoint(x: 24, y: 26), CGPoint(x: 0, y: 44), CGPoint(x: -24, y: 26)],
                           NSColor(white: 1, alpha: 0.97)))                                  // nieve del techo
        node.addChild(rect(CGRect(x: -16, y: 0, width: 10, height: 17), dark, corner: 1))  // puerta
        let glow = SKSpriteNode(texture: Tex.glow)
        glow.size = CGSize(width: 46, height: 46)
        glow.color = NSColor(red: 1, green: 0.75, blue: 0.3, alpha: 1)
        glow.colorBlendFactor = 1
        glow.alpha = 0.55
        glow.position = CGPoint(x: 9, y: 13)
        glow.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.35, duration: 0.9), .fadeAlpha(to: 0.6, duration: 1.3),
        ])))
        node.addChild(glow)
        node.addChild(rect(CGRect(x: 3, y: 8, width: 12, height: 10),
                           NSColor(red: 1, green: 0.82, blue: 0.4, alpha: 1), corner: 1)) // ventana
        node.addChild(rect(CGRect(x: 8.6, y: 8, width: 0.8, height: 10), dark))
        node.addChild(rect(CGRect(x: 3, y: 12.6, width: 12, height: 0.8), dark))
        return node
    }

    static func smokePuff() -> SKSpriteNode {
        let puff = SKSpriteNode(texture: Tex.dot)
        puff.size = CGSize(width: 9, height: 9)
        puff.color = NSColor(white: 0.85, alpha: 1)
        puff.colorBlendFactor = 1
        puff.alpha = 0.55
        puff.position = chimneyTop
        let time = 2.6
        puff.run(.sequence([
            .group([
                .moveBy(x: CGFloat.random(in: 6...18), y: 40, duration: time),
                .scale(to: 2.6, duration: time),
                .fadeOut(withDuration: time),
            ]),
            .removeFromParent(),
        ]))
        return puff
    }

    // MARK: Árbol

    private static let tiers: [(base: CGFloat, half: CGFloat, height: CGFloat)] = [
        (8, 30, 34), (28, 23, 30), (46, 16, 26),
    ]

    static func tree() -> SKNode {
        let node = SKNode()
        node.addChild(rect(CGRect(x: -4, y: 0, width: 8, height: 10),
                           NSColor(red: 0.36, green: 0.22, blue: 0.12, alpha: 1)))
        for (index, tier) in tiers.enumerated() {
            let shade = 0.36 + CGFloat(index) * 0.06
            node.addChild(poly([CGPoint(x: -tier.half, y: tier.base), CGPoint(x: 0, y: tier.base + tier.height),
                                CGPoint(x: tier.half, y: tier.base)],
                               NSColor(red: 0.08, green: shade, blue: 0.2, alpha: 1)))
        }
        // Estrella de cinco puntas.
        var points: [CGPoint] = []
        for step in 0..<10 {
            let angle = CGFloat(step) * .pi / 5 + .pi / 2
            let radius: CGFloat = step % 2 == 0 ? 7 : 3
            points.append(CGPoint(x: cos(angle) * radius, y: 74 + sin(angle) * radius))
        }
        node.addChild(poly(points, NSColor(red: 1, green: 0.84, blue: 0.25, alpha: 1)))
        return node
    }

    static func ornament() -> SKNode {
        let colors: [NSColor] = [
            NSColor(red: 0.9, green: 0.15, blue: 0.2, alpha: 1), NSColor(red: 1, green: 0.8, blue: 0.2, alpha: 1),
            NSColor(red: 0.25, green: 0.55, blue: 1, alpha: 1), NSColor(white: 0.92, alpha: 1),
            NSColor(red: 0.95, green: 0.45, blue: 0.75, alpha: 1),
        ]
        let tier = tiers[Int.random(in: 0..<tiers.count)]
        let v = CGFloat.random(in: 0.08...0.7)
        let x = CGFloat.random(in: -1...1) * tier.half * (1 - v) * 0.8
        return circle(2.8, colors[Int.random(in: 0..<colors.count)], x: x, y: tier.base + tier.height * v)
    }

    // MARK: Nieve

    /// Bola de radio 10; se escala al tamaño que haga falta.
    static func snowball() -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: 10)
        node.fillColor = NSColor(white: 1, alpha: 1)
        node.strokeColor = NSColor(white: 0.78, alpha: 1)
        node.lineWidth = 0.6
        node.name = snowName
        return node
    }

    /// Cara y sombrero para una bola de radio 10.
    static func addFace(to ball: SKNode) {
        let black = NSColor(white: 0.1, alpha: 1)
        ball.addChild(circle(1.2, black, x: -3.2, y: 2.5))
        ball.addChild(circle(1.2, black, x: 3.2, y: 2.5))
        ball.addChild(poly([CGPoint(x: 0, y: 0.8), CGPoint(x: 8, y: -0.6), CGPoint(x: 0, y: -1.8)],
                           NSColor(red: 1, green: 0.5, blue: 0.1, alpha: 1)))
        ball.addChild(rect(CGRect(x: -9, y: 8, width: 18, height: 1.8), black))
        ball.addChild(rect(CGRect(x: -5.5, y: 9, width: 11, height: 9), black))
    }

    static func snowman() -> SKNode {
        let node = SKNode()
        node.name = snowName
        let sizes: [(radius: CGFloat, y: CGFloat)] = [(15, 13), (11, 33), (8, 48)]
        var top: SKShapeNode?
        for size in sizes {
            let ball = snowball()
            ball.name = nil
            ball.setScale(size.radius / 10)
            ball.position = CGPoint(x: 0, y: size.y)
            node.addChild(ball)
            top = ball
        }
        if let top { addFace(to: top) }
        let brown = NSColor(red: 0.4, green: 0.26, blue: 0.14, alpha: 1)
        let leftArm = rect(CGRect(x: -16, y: -0.6, width: 16, height: 1.2), brown)
        leftArm.position = CGPoint(x: -9, y: 35)
        leftArm.zRotation = -0.45
        let rightArm = rect(CGRect(x: 0, y: -0.6, width: 16, height: 1.2), brown)
        rightArm.position = CGPoint(x: 9, y: 35)
        rightArm.zRotation = 0.45
        node.addChild(leftArm)
        node.addChild(rightArm)
        for y in [30, 36] as [CGFloat] {
            node.addChild(circle(1, NSColor(white: 0.15, alpha: 1), x: 0, y: y))
        }
        return node
    }

    // MARK: Quitanieves

    /// Camión que avanza hacia la derecha; la pala queda en x = 44.
    static func plow() -> SKNode {
        let node = SKNode()
        let orange = NSColor(red: 0.95, green: 0.55, blue: 0.1, alpha: 1)
        node.addChild(rect(CGRect(x: 0, y: 6, width: 26, height: 12), orange, corner: 2))
        node.addChild(rect(CGRect(x: 24, y: 6, width: 13, height: 18), orange, corner: 2))
        node.addChild(rect(CGRect(x: 28, y: 15, width: 7, height: 6), NSColor(red: 0.7, green: 0.88, blue: 1, alpha: 1), corner: 1))
        node.addChild(poly([CGPoint(x: 39, y: 0), CGPoint(x: 46, y: 0), CGPoint(x: 43, y: 15), CGPoint(x: 40, y: 15)],
                           NSColor(white: 0.75, alpha: 1)))
        node.addChild(circle(4.5, NSColor(white: 0.12, alpha: 1), x: 8, y: 5))
        node.addChild(circle(4.5, NSColor(white: 0.12, alpha: 1), x: 29, y: 5))
        let light = circle(1.6, NSColor(red: 1, green: 0.85, blue: 0.2, alpha: 1), x: 30, y: 26)
        light.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.3), .fadeAlpha(to: 1, duration: 0.3)])))
        node.addChild(light)
        return node
    }
}
