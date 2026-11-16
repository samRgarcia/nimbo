import SpriteKit
import AppKit

@MainActor
final class Particle {
    enum Behavior { case drift, rain, firefly, mote, ballistic, resting }

    let node: SKSpriteNode
    var behavior: Behavior = .drift
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var phase: CGFloat = 0
    var sway: CGFloat = 0
    var spin: CGFloat = 0
    var life: CGFloat = 0
    var maxLife: CGFloat = 1
    var baseAlpha: CGFloat = 1
    /// Las partículas pasajeras se eliminan al terminar en vez de reaparecer arriba.
    var transient = false
    var deposits = false
    /// Los copos cercanos y grandes pasan de largo sin posarse.
    var lands = true

    init(texture: SKTexture) {
        node = SKSpriteNode(texture: texture)
    }
}

private struct Hit {
    let ledge: Ledge
    let index: Int
}

/// La escena que se dibuja encima del escritorio, una por pantalla.
@MainActor
final class WeatherScene: SKScene {
    private(set) var kind: SceneKind = .clear
    private var intensity: CGFloat = 1
    private var baseWind: CGFloat = 0
    private var showCabin = true
    private var configured = false
    private var night = false
    private var eco = false

    private let screenFrame: CGRect
    private let hostsExtras: Bool
    /// Altura hasta donde llega el área útil (debajo de la barra de menús).
    private let topLimit: CGFloat
    private var backdrop = SKNode()

    private let tint = SKSpriteNode(color: .black, size: .zero)
    private let flash = SKSpriteNode(color: .white, size: .zero)
    private let backLayer = SKNode()
    private let pileLayer = SKNode()
    private let particleLayer = SKNode()

    private var particles: [Particle] = []
    private var ledges: [Int: Ledge] = [:]
    private var clock: CGFloat = 0
    private var lastTime: TimeInterval = 0
    private var windowTimer: CGFloat = 0
    private var busyUntil: CGFloat = 0
    private var meltTimer: CGFloat = 0
    private var redrawTimer: CGFloat = 0
    private var eventTimer: CGFloat = 2
    private var smokeTimer: CGFloat = 0
    private var lastMouse: CGPoint?

    // Taller de invierno
    private var cabinNode: SKNode?
    private var treeNode: SKNode?
    private var ornaments: [SKNode] = []
    private var plowNode: SKNode?
    private var plowRoute: [Ledge] = []
    private var plowX: CGFloat = 0
    private var ball: SKShapeNode?
    private var ballVolume: CGFloat = 0
    private var ballRadius: CGFloat = 0
    private var ballLedge: Ledge?

    var hasTree: Bool { treeNode != nil }
    var ornamentCount: Int { ornaments.count }

    /// Las escenas con caída rápida se ven mejor a 60 cuadros; las tranquilas van bien a 30.
    var prefersHighFrameRate: Bool {
        switch kind {
        case .snow, .rain, .storm, .petals, .leaves, .meteors: return true
        case .fireflies, .cloud, .mist, .clear: return false
        }
    }

    init(size: CGSize, screenFrame: CGRect, topLimit: CGFloat, dockRect: CGRect?, hostsExtras: Bool) {
        self.screenFrame = screenFrame
        self.hostsExtras = hostsExtras
        self.topLimit = topLimit
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear

        for overlay in [tint, flash] {
            overlay.anchorPoint = .zero
            overlay.size = size
            overlay.alpha = 0
        }
        tint.color = NSColor(red: 0.02, green: 0.04, blue: 0.12, alpha: 1)
        tint.zPosition = -10
        backLayer.zPosition = 0
        backLayer.addChild(backdrop)
        pileLayer.zPosition = 5
        particleLayer.zPosition = 10
        flash.zPosition = 50
        addChild(tint)
        addChild(backLayer)
        addChild(pileLayer)
        addChild(particleLayer)
        addChild(flash)

        register(Ledge(id: -2, x0: 0, y: 0, width: size.width, maxHeight: 34))
        if let dockRect {
            register(Ledge(id: -1, x0: dockRect.minX, y: dockRect.maxY, width: dockRect.width, maxHeight: 20))
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) no se usa")
    }

    private func register(_ ledge: Ledge) {
        ledges[ledge.id] = ledge
        pileLayer.addChild(ledge.decor)
        pileLayer.addChild(ledge.shape)
    }

    /// El Dock si está abajo en esta pantalla; si no, el piso.
    private var ground: Ledge? { ledges[-1] ?? ledges[-2] }

    // MARK: Configuración

    func apply(kind: SceneKind, intensity: Double, wind: Double, cabin: Bool, night: Bool, eco: Bool) {
        let newIntensity = CGFloat(intensity)
        baseWind = max(-90, min(90, CGFloat(wind) * 1.6))
        let changed = !configured || kind != self.kind || eco != self.eco
            || abs(newIntensity - self.intensity) > 0.01
        let nightChanged = night != self.night
        self.kind = kind
        self.intensity = newIntensity
        self.night = night
        self.eco = eco
        showCabin = cabin
        if changed {
            configure()
        } else if nightChanged {
            updateTint()
        }
        updateCabin()
    }

    private func updateTint() {
        var alpha: CGFloat
        switch kind {
        case .rain: alpha = 0.06
        case .storm: alpha = 0.16
        case .fireflies: alpha = 0.14
        case .meteors: alpha = 0.16
        case .cloud: alpha = 0.04
        case .snow, .petals, .leaves, .mist, .clear: alpha = 0
        }
        // De noche, un tinte azul muy suave en las escenas que no son ya nocturnas.
        if night, kind != .fireflies, kind != .meteors { alpha += 0.07 }
        tint.removeAllActions()
        tint.run(.fadeAlpha(to: alpha, duration: 1.2))
    }

    private func configure() {
        let first = !configured
        configured = true

        // Lo que ya está cayendo termina de caer; lo demás se desvanece.
        var kept: [Particle] = []
        for particle in particles {
            if particle.transient {
                kept.append(particle)
                continue
            }
            switch particle.behavior {
            case .drift, .rain:
                particle.transient = true
                kept.append(particle)
            case .firefly, .mote, .ballistic, .resting:
                particle.node.run(.sequence([.fadeOut(withDuration: 1), .removeFromParent()]))
            }
        }
        particles = kept

        backdrop.run(.sequence([.fadeOut(withDuration: 1.2), .removeFromParent()]))
        backdrop = SKNode()
        backdrop.alpha = 0
        backdrop.run(.fadeIn(withDuration: 1.2))
        backLayer.addChild(backdrop)
        flash.removeAllActions()
        flash.alpha = 0
        eventTimer = 2

        // La primera vez la pantalla aparece llena; después lo nuevo entra desde arriba.
        let placement: Placement = first ? .fill : .stagger
        switch kind {
        case .snow:
            addParticles(320, Tex.dot, placement)
        case .rain:
            addParticles(420, Tex.streak, placement)
        case .storm:
            addParticles(540, Tex.streak, placement)
        case .petals:
            addParticles(80, Tex.petal, placement)
        case .leaves:
            addParticles(60, Tex.leaf, placement)
        case .fireflies:
            addParticles(40, Tex.glow, .fill)
        case .meteors:
            addStars()
        case .cloud:
            addClouds()
        case .mist:
            addMist()
        case .clear:
            addSun()
            addParticles(24, Tex.dot, .fill)
        }
        updateTint()
    }

    private enum Placement { case fill, top, stagger }

    private func addParticles(_ count: Int, _ texture: SKTexture, _ placement: Placement) {
        let saving: CGFloat = eco ? 0.6 : 1
        let total = max(1, Int(CGFloat(count) * intensity * saving * size.width / 1600))
        for _ in 0..<total {
            let particle = Particle(texture: texture)
            particleLayer.addChild(particle.node)
            particles.append(particle)
            respawn(particle, placement)
        }
    }

    private func respawn(_ p: Particle, _ placement: Placement) {
        let node = p.node
        node.zRotation = 0
        node.colorBlendFactor = 0
        p.phase = CGFloat.random(in: 0...(2 * CGFloat.pi))
        p.transient = false
        p.deposits = false
        p.lands = true
        p.baseAlpha = 1
        p.spin = 0
        p.sway = 0
        p.vx = 0
        let anywhere = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height))
        let above = placement == .stagger ? CGFloat.random(in: 10...max(60, size.height * 0.9))
                                          : CGFloat.random(in: 10...60)
        let fromTop = CGPoint(x: CGFloat.random(in: -60...(size.width + 60)), y: size.height + above)
        node.position = placement == .fill ? anywhere : fromTop

        switch kind {
        case .snow:
            node.color = NSColor(red: 0.93, green: 0.97, blue: 1, alpha: 1)
            node.colorBlendFactor = 1
            p.behavior = .drift
            if Int.random(in: 0..<16) == 0 {
                // Copo cercano: grande, desenfocado y rápido, para dar profundidad.
                let side = CGFloat.random(in: 11...18)
                node.size = CGSize(width: side, height: side)
                p.lands = false
                p.vy = -CGFloat.random(in: 110...160)
                p.sway = CGFloat.random(in: 20...40)
                p.baseAlpha = CGFloat.random(in: 0.25...0.4)
            } else {
                let side = CGFloat.random(in: 3...8)
                node.size = CGSize(width: side, height: side)
                p.deposits = true
                p.vy = -CGFloat.random(in: 35...85) * (0.6 + side / 10)
                p.sway = CGFloat.random(in: 8...26)
                p.baseAlpha = CGFloat.random(in: 0.6...1)
            }
        case .rain, .storm:
            node.size = CGSize(width: 1.6, height: CGFloat.random(in: 12...22))
            p.behavior = .rain
            p.vy = -CGFloat.random(in: 650...900) * (kind == .storm ? 1.2 : 1)
            p.vx = kind == .storm ? -170 : -40
            p.baseAlpha = CGFloat.random(in: 0.3...0.6)
        case .petals:
            let scale = CGFloat.random(in: 0.7...1.3)
            node.size = CGSize(width: 9 * scale, height: 6.5 * scale)
            node.color = NSColor(red: 1, green: CGFloat.random(in: 0.7...0.85), blue: CGFloat.random(in: 0.8...0.92), alpha: 1)
            node.colorBlendFactor = 1
            p.behavior = .drift
            p.vy = -CGFloat.random(in: 30...60)
            p.sway = CGFloat.random(in: 30...60)
            p.spin = CGFloat.random(in: -2...2)
            p.baseAlpha = 0.9
        case .leaves:
            let colors: [NSColor] = [
                NSColor(red: 0.85, green: 0.35, blue: 0.1, alpha: 1), NSColor(red: 0.95, green: 0.6, blue: 0.12, alpha: 1),
                NSColor(red: 0.7, green: 0.2, blue: 0.1, alpha: 1), NSColor(red: 0.9, green: 0.75, blue: 0.2, alpha: 1),
            ]
            let scale = CGFloat.random(in: 0.8...1.4)
            node.size = CGSize(width: 14 * scale, height: 9 * scale)
            node.color = colors[Int.random(in: 0..<colors.count)]
            node.colorBlendFactor = 1
            p.behavior = .drift
            p.vy = -CGFloat.random(in: 45...90)
            p.sway = CGFloat.random(in: 40...80)
            p.spin = CGFloat.random(in: -3...3)
            p.baseAlpha = 0.95
        case .fireflies:
            let side = CGFloat.random(in: 9...15)
            node.size = CGSize(width: side, height: side)
            node.color = NSColor(red: 0.85, green: 1, blue: 0.4, alpha: 1)
            node.colorBlendFactor = 1
            node.position = CGPoint(x: anywhere.x, y: CGFloat.random(in: 20...(size.height * 0.7)))
            p.behavior = .firefly
            p.vx = CGFloat.random(in: -20...20)
            p.vy = CGFloat.random(in: -20...20)
        case .clear:
            let side = CGFloat.random(in: 2...4)
            node.size = CGSize(width: side, height: side)
            node.color = NSColor(red: 1, green: 0.92, blue: 0.7, alpha: 1)
            node.colorBlendFactor = 1
            node.position = anywhere
            p.behavior = .mote
            p.vx = CGFloat.random(in: -6...6)
            p.vy = CGFloat.random(in: 4...12)
            p.baseAlpha = CGFloat.random(in: 0.25...0.5)
        case .meteors, .cloud, .mist:
            break
        }
        node.alpha = p.baseAlpha
    }

    @discardableResult
    private func emit(at point: CGPoint, side: CGFloat, vx: CGFloat, vy: CGFloat,
                      behavior: Particle.Behavior, life: CGFloat, alpha: CGFloat, deposits: Bool) -> Particle? {
        guard particles.count < 1600 else { return nil }
        let p = Particle(texture: Tex.dot)
        p.node.size = CGSize(width: side, height: side)
        p.node.position = point
        p.node.alpha = alpha
        p.baseAlpha = alpha
        p.behavior = behavior
        p.vx = vx
        p.vy = vy
        p.life = life
        p.maxLife = max(0.01, life)
        p.transient = true
        p.deposits = deposits
        p.sway = 5
        particleLayer.addChild(p.node)
        particles.append(p)
        return p
    }

    // MARK: Fondos

    private func loopAcross(_ node: SKSpriteNode, speed: CGFloat) {
        let half = node.size.width / 2
        let startX = -half
        let endX = size.width + half
        let first = SKAction.moveTo(x: endX, duration: TimeInterval(max(0, endX - node.position.x) / speed))
        let lap = SKAction.sequence([
            .moveTo(x: startX, duration: 0),
            .moveTo(x: endX, duration: TimeInterval((endX - startX) / speed)),
        ])
        node.run(.sequence([first, .repeatForever(lap)]))
    }

    private func addClouds() {
        let count = max(3, Int(7 * intensity))
        for _ in 0..<count {
            let cloud = SKSpriteNode(texture: Tex.cloud)
            let width = CGFloat.random(in: 420...760)
            cloud.size = CGSize(width: width, height: width * 0.5)
            cloud.alpha = CGFloat.random(in: 0.35...0.6)
            cloud.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                     y: size.height - CGFloat.random(in: 40...(size.height * 0.3)))
            backdrop.addChild(cloud)
            loopAcross(cloud, speed: CGFloat.random(in: 8...22) + abs(baseWind) * 0.3)
        }
    }

    private func addMist() {
        let count = max(4, Int(9 * intensity))
        for _ in 0..<count {
            let blob = SKSpriteNode(texture: Tex.blob)
            blob.size = CGSize(width: CGFloat.random(in: 700...1100), height: CGFloat.random(in: 280...440))
            blob.alpha = CGFloat.random(in: 0.1...0.2)
            blob.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                    y: CGFloat.random(in: 0...(size.height * 0.65)))
            backdrop.addChild(blob)
            loopAcross(blob, speed: CGFloat.random(in: 6...16))
        }
    }

    private func addSun() {
        let sun = SKSpriteNode(texture: Tex.glow)
        sun.size = CGSize(width: 900, height: 900)
        sun.color = NSColor(red: 1, green: 0.85, blue: 0.5, alpha: 1)
        sun.colorBlendFactor = 1
        sun.alpha = 0.3
        sun.position = CGPoint(x: size.width - 60, y: size.height - 30)
        sun.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.4, duration: 4), .fadeAlpha(to: 0.26, duration: 4),
        ])))
        backdrop.addChild(sun)
    }

    private func addStars() {
        let count = Int(70 * intensity)
        for _ in 0..<max(10, count) {
            let star = SKSpriteNode(texture: Tex.dot)
            let side = CGFloat.random(in: 1.5...3.5)
            let alpha = CGFloat.random(in: 0.25...0.75)
            let time = TimeInterval.random(in: 0.8...2.6)
            star.size = CGSize(width: side, height: side)
            star.alpha = alpha
            star.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                    y: CGFloat.random(in: (size.height * 0.35)...size.height))
            star.run(.repeatForever(.sequence([
                .fadeAlpha(to: alpha * 0.3, duration: time), .fadeAlpha(to: alpha, duration: time),
            ])))
            backdrop.addChild(star)
        }
        let moon = SKSpriteNode(texture: Tex.glow)
        moon.size = CGSize(width: 240, height: 240)
        moon.color = NSColor(red: 0.93, green: 0.95, blue: 1, alpha: 1)
        moon.colorBlendFactor = 1
        moon.alpha = 0.55
        moon.position = CGPoint(x: size.width * 0.14, y: size.height - 130)
        backdrop.addChild(moon)
    }

    private func meteor() {
        let streak = SKSpriteNode(texture: Tex.meteor)
        streak.size = CGSize(width: CGFloat.random(in: 110...190), height: 2.5)
        let dx = -CGFloat.random(in: 420...700)
        let dy = -CGFloat.random(in: 220...380)
        streak.zRotation = atan2(dy, dx)
        streak.alpha = 0
        streak.position = CGPoint(x: CGFloat.random(in: (size.width * 0.3)...(size.width + 100)),
                                  y: size.height - CGFloat.random(in: 0...(size.height * 0.3)))
        backdrop.addChild(streak)
        streak.run(.sequence([
            .group([
                .moveBy(x: dx, y: dy, duration: 1),
                .sequence([.fadeAlpha(to: 0.9, duration: 0.15), .fadeOut(withDuration: 0.85)]),
            ]),
            .removeFromParent(),
        ]))
    }

    private func lightning() {
        flash.removeAllActions()
        flash.run(.sequence([
            .fadeAlpha(to: 0.2, duration: 0.04), .fadeAlpha(to: 0.03, duration: 0.08),
            .fadeAlpha(to: 0.14, duration: 0.04), .fadeOut(withDuration: 0.45),
        ]))

        // El rayo: una línea quebrada que baja desde arriba y se apaga enseguida.
        let path = CGMutablePath()
        var point = CGPoint(x: CGFloat.random(in: (size.width * 0.15)...(size.width * 0.85)), y: size.height)
        path.move(to: point)
        let bottom = size.height * CGFloat.random(in: 0.35...0.6)
        while point.y > bottom {
            point = CGPoint(x: point.x + CGFloat.random(in: -38...38), y: point.y - CGFloat.random(in: 28...70))
            path.addLine(to: point)
        }
        let bolt = SKShapeNode(path: path)
        bolt.strokeColor = NSColor(red: 0.9, green: 0.93, blue: 1, alpha: 1)
        bolt.fillColor = .clear
        bolt.lineWidth = 2
        bolt.glowWidth = 5
        bolt.zPosition = 40
        addChild(bolt)
        bolt.run(.sequence([.wait(forDuration: 0.08), .fadeOut(withDuration: 0.25), .removeFromParent()]))
    }

    // MARK: Ciclo

    override func update(_ currentTime: TimeInterval) {
        let dt = CGFloat(min(max(currentTime - lastTime, 0), 0.05))
        lastTime = currentTime
        guard dt > 0 else { return }
        clock += dt

        // Las ventanas se revisan más seguido mientras algo se está moviendo.
        windowTimer -= dt
        if windowTimer <= 0 {
            if refreshLedges() { busyUntil = clock + 1.5 }
            windowTimer = clock < busyUntil ? 0.066 : 0.25
        }

        stepParticles(dt)
        stepEvents(dt)
        stepMouse(dt)
        stepPlow(dt)
        stepSmoke(dt)
        meltTimer += dt
        if meltTimer >= 0.3 {
            melt(meltTimer)
            meltTimer = 0
        }

        redrawTimer -= dt
        if redrawTimer <= 0 {
            redrawTimer = 0.08
            for ledge in ledges.values where ledge.dirty {
                ledge.rebuildPath()
            }
        }
    }

    private func landing(x: CGFloat, from y0: CGFloat, to y1: CGFloat) -> Hit? {
        var best: Hit?
        var bestY = -CGFloat.greatestFiniteMagnitude
        for ledge in ledges.values where ledge.contains(x) {
            let index = ledge.index(at: x)
            let surface = ledge.y + ledge.heights[index]
            guard surface <= y0, surface >= y1, surface > bestY, ledge.isVisible(x) else { continue }
            best = Hit(ledge: ledge, index: index)
            bestY = surface
        }
        return best
    }

    private func stepParticles(_ dt: CGFloat) {
        let wind = baseWind + sin(clock * 0.25) * 12
        var i = particles.count - 1
        while i >= 0 {
            let p = particles[i]
            let node = p.node
            let old = node.position
            var remove = false

            switch p.behavior {
            case .drift:
                let nx = old.x + (p.vx + wind + sin(clock * 1.3 + p.phase) * p.sway) * dt
                let ny = old.y + p.vy * dt
                node.zRotation += p.spin * dt
                if p.lands, let hit = landing(x: nx, from: old.y, to: ny) {
                    if p.deposits {
                        hit.ledge.add(1, at: hit.index)
                        if p.transient { remove = true } else { respawn(p, .top) }
                    } else {
                        node.position = CGPoint(x: nx, y: hit.ledge.surface(at: nx) + 1)
                        p.behavior = .resting
                        p.life = CGFloat.random(in: 3...7)
                    }
                } else if ny < -20 || nx < -90 || nx > size.width + 90 {
                    if p.transient { remove = true } else { respawn(p, .top) }
                } else {
                    node.position = CGPoint(x: nx, y: ny)
                }

            case .rain:
                let vx = p.vx + wind * 1.5
                let nx = old.x + vx * dt
                let ny = old.y + p.vy * dt
                node.zRotation = atan2(vx, -p.vy)
                if let hit = landing(x: nx, from: old.y, to: ny) {
                    let point = CGPoint(x: nx, y: hit.ledge.surface(at: nx) + 1)
                    for _ in 0..<2 {
                        emit(at: point, side: 2, vx: CGFloat.random(in: -55...55), vy: CGFloat.random(in: 50...130),
                             behavior: .ballistic, life: 0.35, alpha: 0.5, deposits: false)
                    }
                    // A veces el agua escurre por el costado de la ventana.
                    if hit.ledge.id > 0, Int.random(in: 0..<12) == 0 {
                        let left = nx - hit.ledge.x0 < hit.ledge.width / 2
                        let edge = left ? hit.ledge.x0 - 1 : hit.ledge.x0 + hit.ledge.width + 1
                        emit(at: CGPoint(x: edge, y: hit.ledge.y), side: 3, vx: 0, vy: -20,
                             behavior: .ballistic, life: 1.6, alpha: 0.6, deposits: false)
                    }
                    if p.transient { remove = true } else { respawn(p, .top) }
                } else if ny < -30 || nx < -120 || nx > size.width + 120 {
                    if p.transient { remove = true } else { respawn(p, .top) }
                } else {
                    node.position = CGPoint(x: nx, y: ny)
                }

            case .resting:
                p.life -= dt
                node.alpha = p.baseAlpha * min(1, max(0, p.life))
                if p.life <= 0 {
                    if p.transient { remove = true } else { respawn(p, .top) }
                }

            case .firefly:
                p.vx = min(28, max(-28, p.vx + CGFloat.random(in: -60...60) * dt))
                p.vy = min(28, max(-28, p.vy + CGFloat.random(in: -60...60) * dt))
                var nx = old.x + p.vx * dt
                var ny = old.y + p.vy * dt
                if nx < -20 { nx = size.width + 20 } else if nx > size.width + 20 { nx = -20 }
                if ny < 10 { ny = 10; p.vy = abs(p.vy) } else if ny > size.height * 0.8 { p.vy = -abs(p.vy) }
                node.position = CGPoint(x: nx, y: ny)
                let pulse = max(0, sin(clock * 1.5 + p.phase))
                node.alpha = 0.15 + 0.85 * pulse * pulse

            case .mote:
                var ny = old.y + p.vy * dt
                let nx = old.x + (p.vx + sin(clock * 0.6 + p.phase) * 5) * dt
                if ny > size.height + 10 { ny = -10 }
                node.position = CGPoint(x: nx, y: ny)

            case .ballistic:
                p.vy -= 520 * dt
                p.life -= dt
                node.position = CGPoint(x: old.x + p.vx * dt, y: old.y + p.vy * dt)
                node.alpha = p.baseAlpha * max(0, p.life / p.maxLife)
                if p.life <= 0 { remove = true }
            }

            if remove {
                node.removeFromParent()
                particles.remove(at: i)
            }
            i -= 1
        }
    }

    private func stepEvents(_ dt: CGFloat) {
        eventTimer -= dt
        guard eventTimer <= 0 else { return }
        switch kind {
        case .storm:
            lightning()
            eventTimer = CGFloat.random(in: 5...16)
        case .meteors:
            meteor()
            eventTimer = CGFloat.random(in: 1.5...6)
        default:
            eventTimer = 5
        }
    }

    private func melt(_ dt: CGFloat) {
        let rate: CGFloat
        switch kind {
        case .snow: return
        case .rain, .storm: rate = 2.5
        case .clear: rate = 1.2
        default: rate = 0.5
        }
        for ledge in ledges.values where ledge.hasSnow {
            ledge.melt(rate * dt)
        }
    }

    // MARK: Ventanas

    private func subtract(_ ranges: [ClosedRange<CGFloat>], from a: CGFloat, to b: CGFloat) -> [ClosedRange<CGFloat>] {
        var out: [ClosedRange<CGFloat>] = []
        for range in ranges {
            if b <= range.lowerBound || a >= range.upperBound {
                out.append(range)
                continue
            }
            if a - range.lowerBound > 8 { out.append(range.lowerBound...a) }
            if range.upperBound - b > 8 { out.append(b...range.upperBound) }
        }
        return out
    }

    /// Devuelve true si alguna ventana apareció, se movió o se cerró.
    @discardableResult
    private func refreshLedges() -> Bool {
        let windows = WindowTracker.windows()
        var seen = Set<Int>()
        var changed = false
        for (position, window) in windows.enumerated() {
            let top = window.frame.maxY - screenFrame.minY
            let x0 = window.frame.minX - screenFrame.minX
            let width = window.frame.width
            // Fuera de esta pantalla, pegada a la barra de menús o casi en el piso: no cuenta.
            guard top > 60, top < topLimit - 26, x0 < size.width - 20, x0 + width > 20 else { continue }

            var ranges: [ClosedRange<CGFloat>] = [max(0, x0)...min(size.width, x0 + width)]
            for front in windows[..<position]
            where front.frame.minY < window.frame.maxY - 1 && front.frame.maxY > window.frame.maxY + 1 {
                ranges = subtract(ranges, from: front.frame.minX - screenFrame.minX,
                                  to: front.frame.maxX - screenFrame.minX)
            }
            seen.insert(window.id)

            if let ledge = ledges[window.id] {
                if abs(ledge.x0 - x0) > 1.5 || abs(ledge.y - top) > 1.5 || abs(ledge.width - width) > 1.5 {
                    spill(ledge)
                    ledge.move(x0: x0, y: top, width: width)
                    changed = true
                }
                if ledge.visible != ranges {
                    ledge.visible = ranges
                    ledge.dirty = true
                }
            } else {
                let ledge = Ledge(id: window.id, x0: x0, y: top, width: width, maxHeight: 24)
                ledge.visible = ranges
                register(ledge)
                changed = true
            }
        }
        for (id, ledge) in ledges where id > 0 && !seen.contains(id) {
            spill(ledge)
            ledge.shape.removeFromParent()
            ledge.decor.removeFromParent()
            ledges[id] = nil
            changed = true
        }
        return changed
    }

    /// La nieve de una repisa cae cuando la ventana se mueve o se cierra.
    private func spill(_ ledge: Ledge) {
        var budget = 140
        for (j, height) in ledge.heights.enumerated() where height > 1.5 && j % 2 == 0 {
            guard budget > 0 else { break }
            budget -= 1
            let point = CGPoint(x: ledge.x0 + CGFloat(j) * Ledge.step, y: ledge.y + CGFloat.random(in: 0...height))
            emit(at: point, side: CGFloat.random(in: 4...8), vx: CGFloat.random(in: -25...25),
                 vy: -CGFloat.random(in: 90...220), behavior: .drift, life: 0, alpha: 0.95, deposits: true)
        }
    }

    // MARK: Ratón

    private func ledgeUnder(_ p: CGPoint, slack: CGFloat, needsSnow: Bool) -> Ledge? {
        var best: Ledge?
        var bestY = -CGFloat.greatestFiniteMagnitude
        for ledge in ledges.values where ledge.contains(p.x) && ledge.isVisible(p.x) {
            let height = ledge.heights[ledge.index(at: p.x)]
            if needsSnow && height < 1.5 { continue }
            let surface = ledge.y + height
            guard p.y >= ledge.y - 6, p.y <= surface + slack, surface > bestY else { continue }
            best = ledge
            bestY = surface
        }
        return best
    }

    private func stepMouse(_ dt: CGFloat) {
        let global = NSEvent.mouseLocation
        let p = CGPoint(x: global.x - screenFrame.minX, y: global.y - screenFrame.minY)
        let previous = lastMouse ?? p
        lastMouse = p
        guard p.x >= 0, p.x <= size.width, p.y >= 0, p.y <= size.height else {
            finishBall()
            return
        }
        let dx = p.x - previous.x
        let dy = p.y - previous.y
        let moved = hypot(dx, dy)

        // Con Opción presionada se rueda una bola de nieve.
        if NSEvent.modifierFlags.contains(.option), NSEvent.pressedMouseButtons == 0 {
            roll(at: p, moved: moved)
            return
        }
        finishBall()

        // Pasar el cursor rápido por un montón lo esparce.
        guard moved / dt > 250, let ledge = ledgeUnder(p, slack: 8, needsSnow: true) else { return }
        let index = ledge.index(at: p.x)
        let taken = ledge.take(around: index, radius: 3, amount: 3)
        let flakes = min(8, Int(taken / 2))
        guard flakes > 0 else { return }
        for _ in 0..<flakes {
            emit(at: CGPoint(x: p.x + CGFloat.random(in: -10...10), y: ledge.y + CGFloat.random(in: 2...10)),
                 side: CGFloat.random(in: 3...6), vx: dx / dt * 0.15 + CGFloat.random(in: -40...40),
                 vy: CGFloat.random(in: 70...170), behavior: .ballistic, life: 0.9, alpha: 0.95, deposits: false)
        }
    }

    private func roll(at p: CGPoint, moved: CGFloat) {
        guard let ledge = ledgeUnder(p, slack: ballRadius * 2 + 12, needsSnow: ball == nil) else { return }
        if moved > 0.5 {
            ballVolume += ledge.take(around: ledge.index(at: p.x), radius: 2, amount: 0.8) * Ledge.step
        }
        guard ballVolume > 0 else { return }
        ballRadius = min(34, 3 + sqrt(ballVolume) * 0.75)
        let node: SKShapeNode
        if let existing = ball {
            node = existing
        } else {
            node = Decor.snowball()
            node.zPosition = 4
            particleLayer.addChild(node)
            ball = node
        }
        node.setScale(ballRadius / 10)
        node.position = CGPoint(x: p.x, y: ledge.surface(at: p.x) + ballRadius * 0.9)
        ballLedge = ledge
    }

    /// Al soltar Opción la bola se queda; tres apiladas forman un muñeco.
    private func finishBall() {
        guard let node = ball else { return }
        let radius = ballRadius
        let home = ballLedge
        ball = nil
        ballVolume = 0
        ballRadius = 0
        ballLedge = nil
        node.removeFromParent()
        guard let ledge = home, ledges[ledge.id] === ledge, radius >= 6 else { return }

        let x = node.position.x - ledge.x0
        if let slot = ledge.stacks.firstIndex(where: { abs($0.x - x) < 30 && $0.count < 3 }) {
            var stack = ledge.stacks[slot]
            node.position = CGPoint(x: stack.x, y: stack.top + radius * 0.8)
            stack.top += radius * 1.6
            stack.count += 1
            ledge.stacks[slot] = stack
            if stack.count == 3 { Decor.addFace(to: node) }
        } else {
            node.position = CGPoint(x: x, y: radius * 0.9)
            ledge.stacks.append(BallStack(x: x, top: radius * 1.8, count: 1))
        }
        node.zPosition = 0
        ledge.decor.addChild(node)
    }

    // MARK: Taller de invierno

    private func updateCabin() {
        guard hostsExtras, let ground = self.ground else { return }
        let wanted = showCabin && kind == .snow
        if wanted, cabinNode == nil {
            let cabin = Decor.cabin()
            cabin.position = CGPoint(x: min(60, ground.width * 0.2), y: 0)
            ground.decor.addChild(cabin)
            cabinNode = cabin
        } else if !wanted, let cabin = cabinNode {
            cabin.removeFromParent()
            cabinNode = nil
        }
    }

    private func stepSmoke(_ dt: CGFloat) {
        guard let cabin = cabinNode else { return }
        smokeTimer -= dt
        guard smokeTimer <= 0 else { return }
        smokeTimer = 0.7
        cabin.addChild(Decor.smokePuff())
    }

    func toggleTree() {
        guard hostsExtras, let ground = self.ground else { return }
        if let tree = treeNode {
            tree.removeFromParent()
            treeNode = nil
            ornaments = []
            return
        }
        let tree = Decor.tree()
        tree.position = CGPoint(x: max(40, ground.width - 60), y: 0)
        ground.decor.addChild(tree)
        treeNode = tree
        for _ in 0..<6 { addOrnament() }
    }

    func addOrnament() {
        guard let tree = treeNode, ornaments.count < 40 else { return }
        let ornament = Decor.ornament()
        tree.addChild(ornament)
        ornaments.append(ornament)
    }

    func removeOrnament() {
        guard let last = ornaments.popLast() else { return }
        last.removeFromParent()
    }

    func addSnowman() {
        guard hostsExtras, let ground = self.ground else { return }
        let snowman = Decor.snowman()
        let low = min(120, ground.width * 0.3)
        let high = max(low + 1, ground.width - 120)
        snowman.position = CGPoint(x: CGFloat.random(in: low...high), y: 0)
        ground.decor.addChild(snowman)
    }

    func clearSnow() {
        for ledge in ledges.values {
            ledge.clear()
        }
    }

    func sendPlow() {
        guard hostsExtras, plowNode == nil else { return }
        plowRoute = [ledges[-1], ledges[-2]].compactMap { $0 }
        guard !plowRoute.isEmpty else { return }
        let node = Decor.plow()
        node.zPosition = 3
        pileLayer.addChild(node)
        plowNode = node
        startPlowLeg()
    }

    private func startPlowLeg() {
        guard let node = plowNode, let ledge = plowRoute.first else { return }
        plowX = ledge.x0 - 50
        node.position = CGPoint(x: plowX, y: ledge.y)
    }

    private func stepPlow(_ dt: CGFloat) {
        guard let node = plowNode, let ledge = plowRoute.first else { return }
        plowX += 200 * dt
        node.position = CGPoint(x: plowX, y: ledge.y)
        let blade = plowX + 44
        if ledge.contains(blade) {
            let index = ledge.index(at: blade)
            let taken = ledge.take(around: max(0, index - 2), radius: 2, amount: 100)
            if taken > 2, Int.random(in: 0..<2) == 0 {
                emit(at: CGPoint(x: blade + 4, y: ledge.y + 6), side: CGFloat.random(in: 3...6),
                     vx: CGFloat.random(in: 120...260), vy: CGFloat.random(in: 120...240),
                     behavior: .ballistic, life: 0.8, alpha: 0.95, deposits: false)
            }
        }
        if plowX > ledge.x0 + ledge.width + 20 {
            plowRoute.removeFirst()
            if plowRoute.isEmpty {
                node.removeFromParent()
                plowNode = nil
            } else {
                startPlowLeg()
            }
        }
    }
}
