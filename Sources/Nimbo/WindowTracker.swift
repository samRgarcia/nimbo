import AppKit

struct WindowInfo {
    let id: Int
    /// Marco en coordenadas globales de Cocoa (origen abajo a la izquierda).
    let frame: CGRect
}

/// Lee la posición de las ventanas normales en pantalla, de adelante hacia atrás.
/// Solo usa la geometría: no necesita permiso de grabación de pantalla.
enum WindowTracker {
    static func windows() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var result: [WindowInfo] = []
        for entry in list {
            guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
                  let number = entry[kCGWindowNumber as String] as? Int,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            let alpha = (entry[kCGWindowAlpha as String] as? Double) ?? 1
            guard alpha > 0.1, bounds.width >= 160, bounds.height >= 80 else { continue }
            let frame = CGRect(x: bounds.minX, y: primaryHeight - bounds.maxY,
                               width: bounds.width, height: bounds.height)
            result.append(WindowInfo(id: number, frame: frame))
        }
        return result
    }
}
