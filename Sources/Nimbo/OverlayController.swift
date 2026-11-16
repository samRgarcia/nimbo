import AppKit
import SpriteKit
import Combine

/// Una ventana transparente por pantalla, encima de todo, que deja pasar los clics.
@MainActor
final class OverlayController {
    private var windows: [NSWindow] = []
    private var views: [SKView] = []
    private var scenes: [WeatherScene] = []
    private var bag = Set<AnyCancellable>()
    private let state = AppState.shared
    /// Pantalla apagada o sesión bloqueada: no tiene caso dibujar.
    private var asleep = false

    /// La escena de la pantalla principal, donde vive el taller de invierno.
    var mainScene: WeatherScene? { scenes.first }

    init() {
        rebuild()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.rebuild() }
        }
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.sync() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.setAsleep(true) }
            }
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.setAsleep(false) }
            }
        }

        // Cualquier cambio del estado se aplica junto, un instante después.
        state.objectWillChange
            .debounce(for: .milliseconds(120), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.sync() }
            .store(in: &bag)
    }

    func rebuild() {
        for window in windows { window.orderOut(nil) }
        windows = []
        views = []
        scenes = []

        for (index, screen) in NSScreen.screens.enumerated() {
            let frame = screen.frame
            let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.level = .statusBar

            let view = SKView(frame: CGRect(origin: .zero, size: frame.size))
            view.allowsTransparency = true
            view.autoresizingMask = [.width, .height]
            let scene = WeatherScene(size: frame.size, screenFrame: frame,
                                     topLimit: screen.visibleFrame.maxY - frame.minY,
                                     dockRect: Self.dockRect(on: screen), hostsExtras: index == 0)
            view.presentScene(scene)
            window.contentView = view
            window.setFrame(frame, display: true)

            windows.append(window)
            views.append(view)
            scenes.append(scene)
        }
        sync()
    }

    private func setAsleep(_ value: Bool) {
        asleep = value
        sync()
    }

    /// Aplica el estado actual a todas las pantallas.
    private func sync() {
        let eco = state.ecoActive
        let hidden = state.paused || asleep
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        if !state.hideInFullscreen { behavior.insert(.fullScreenAuxiliary) }

        for (index, scene) in scenes.enumerated() {
            scene.apply(kind: state.scene, intensity: state.effectiveIntensity, wind: state.signedWind,
                        cabin: state.cabin, night: !state.isDay && state.auto, eco: eco)
            let view = views[index]
            let window = windows[index]
            let fps = eco || !scene.prefersHighFrameRate ? 30 : 60
            if view.preferredFramesPerSecond != fps { view.preferredFramesPerSecond = fps }
            if window.collectionBehavior != behavior { window.collectionBehavior = behavior }
            if view.isPaused != hidden { view.isPaused = hidden }
            if hidden {
                window.orderOut(nil)
            } else if !window.isVisible {
                window.orderFrontRegardless()
            }
        }
    }

    func clearSnow() {
        for scene in scenes { scene.clearSnow() }
    }

    /// Estima el rectángulo del Dock cuando está abajo, en coordenadas de la escena.
    /// macOS no da su ancho exacto sin permisos de accesibilidad, así que se calcula
    /// con el tamaño de los iconos y cuántos hay.
    private static func dockRect(on screen: NSScreen) -> CGRect? {
        let height = screen.visibleFrame.minY - screen.frame.minY
        guard height > 30 else { return nil }
        let dock = UserDefaults(suiteName: "com.apple.dock")
        let apps = dock?.array(forKey: "persistent-apps")?.count ?? 8
        let others = dock?.array(forKey: "persistent-others")?.count ?? 1
        let showsRecents = (dock?.object(forKey: "show-recents") as? Bool) ?? true
        let items = CGFloat(apps + others + (showsRecents ? 3 : 0) + 2)
        let tile = max(24, height - 16)
        let width = min(screen.frame.width - 16, items * tile * 1.04 + 40)
        return CGRect(x: (screen.frame.width - width) / 2, y: 0, width: width, height: height - 3)
    }
}
