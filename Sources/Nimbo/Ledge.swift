import SpriteKit
import AppKit

struct BallStack {
    var x: CGFloat
    var top: CGFloat
    var count: Int
}

/// Una repisa donde se junta la nieve: el borde superior de una ventana, el Dock o el piso.
@MainActor
final class Ledge {
    static let step: CGFloat = 4

    let id: Int
    private(set) var x0: CGFloat
    private(set) var y: CGFloat
    private(set) var width: CGFloat
    let maxHeight: CGFloat
    var heights: [CGFloat]
    /// Tramos del borde que no tapa otra ventana (en x de la escena).
    var visible: [ClosedRange<CGFloat>]
    var dirty = false
    var stacks: [BallStack] = []
    let shape = SKShapeNode()
    let decor = SKNode()

    init(id: Int, x0: CGFloat, y: CGFloat, width: CGFloat, maxHeight: CGFloat) {
        self.id = id
        self.x0 = x0
        self.y = y
        self.width = max(Ledge.step, width)
        self.maxHeight = maxHeight
        heights = Array(repeating: 0, count: max(1, Int((max(Ledge.step, width) / Ledge.step).rounded(.up))))
        visible = [x0...(x0 + max(Ledge.step, width))]
        shape.fillColor = NSColor(white: 1, alpha: 0.96)
        // Un borde azulado para que la nieve se distinga sobre ventanas claras.
        shape.strokeColor = NSColor(red: 0.7, green: 0.79, blue: 0.9, alpha: 0.9)
        shape.lineWidth = 1
        shape.zPosition = 2
        decor.zPosition = 1
        place()
    }

    private func place() {
        shape.position = CGPoint(x: x0, y: y)
        decor.position = CGPoint(x: x0, y: y)
    }

    /// La ventana se movió: la repisa empieza vacía en su nuevo lugar.
    func move(x0: CGFloat, y: CGFloat, width: CGFloat) {
        self.x0 = x0
        self.y = y
        self.width = max(Ledge.step, width)
        heights = Array(repeating: 0, count: max(1, Int((self.width / Ledge.step).rounded(.up))))
        visible = [x0...(x0 + self.width)]
        stacks = []
        decor.removeAllChildren()
        dirty = true
        place()
    }

    var hasSnow: Bool { heights.contains { $0 > 0 } }

    func contains(_ x: CGFloat) -> Bool { x >= x0 && x < x0 + width }

    func index(at x: CGFloat) -> Int {
        min(heights.count - 1, max(0, Int((x - x0) / Ledge.step)))
    }

    func isVisible(_ x: CGFloat) -> Bool {
        for range in visible where range.contains(x) { return true }
        return false
    }

    func surface(at x: CGFloat) -> CGFloat { y + heights[index(at: x)] }

    private func cap(_ index: Int) -> CGFloat {
        let edge = CGFloat(min(index, heights.count - 1 - index)) + 1
        return maxHeight * min(1, edge / 5)
    }

    func add(_ amount: CGFloat, at index: Int) {
        let weights: [(Int, CGFloat)] = [(-2, 0.25), (-1, 0.6), (0, 1), (1, 0.6), (2, 0.25)]
        for (offset, weight) in weights {
            let j = index + offset
            guard j >= 0, j < heights.count else { continue }
            heights[j] = min(cap(j), heights[j] + amount * weight)
        }
        dirty = true
    }

    /// Quita nieve alrededor de una columna y devuelve cuánta quitó.
    func take(around index: Int, radius: Int, amount: CGFloat) -> CGFloat {
        var taken: CGFloat = 0
        for j in (index - radius)...(index + radius) where j >= 0 && j < heights.count {
            let part = min(heights[j], amount)
            heights[j] -= part
            taken += part
        }
        if taken > 0 { dirty = true }
        return taken
    }

    func melt(_ amount: CGFloat) {
        for j in heights.indices where heights[j] > 0 {
            heights[j] = max(0, heights[j] - amount)
        }
        dirty = true
    }

    func clear() {
        for j in heights.indices { heights[j] = 0 }
        stacks = []
        for child in decor.children where child.name == Decor.snowName {
            child.removeFromParent()
        }
        dirty = true
    }

    func rebuildPath() {
        dirty = false
        let path = CGMutablePath()
        // Curvas entre los puntos medios para que el montón se vea redondeado.
        var previous: CGPoint?
        for (j, height) in heights.enumerated() {
            let x = CGFloat(j) * Ledge.step
            let show = height > 0.4 && isVisible(x0 + x + Ledge.step / 2)
            if show {
                let point = CGPoint(x: x + Ledge.step / 2, y: height)
                if let last = previous {
                    path.addQuadCurve(to: CGPoint(x: (last.x + point.x) / 2, y: (last.y + point.y) / 2), control: last)
                } else {
                    path.move(to: CGPoint(x: x, y: 0))
                }
                previous = point
            } else if let last = previous {
                path.addLine(to: last)
                path.addLine(to: CGPoint(x: x, y: 0))
                path.closeSubpath()
                previous = nil
            }
        }
        if let last = previous {
            path.addLine(to: last)
            path.addLine(to: CGPoint(x: CGFloat(heights.count) * Ledge.step, y: 0))
            path.closeSubpath()
        }
        shape.path = path
    }
}
