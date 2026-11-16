import AppKit
import SwiftUI
import Combine

@main
struct NimboMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let state = AppState.shared
    private var overlay: OverlayController?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var bag = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlay = OverlayController()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        updateStatusItem()
        state.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &bag)

        state.start()
        if state.city == nil { openSettings() }
    }

    /// Icono de la escena (o de pausa) y, si se pidió, la temperatura al lado.
    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        let symbol = state.paused ? "pause.circle" : state.scene.symbol
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Nimbo")
        if state.showTemperature, let temp = state.temperature {
            button.title = " " + state.temperatureText(temp)
            button.imagePosition = .imageLeading
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    // MARK: Menú

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header: String
        if let city = state.city, let temp = state.temperature, let code = state.weatherCode {
            header = "\(city.name) · \(state.temperatureText(temp)) · \(WMO.text(code))"
        } else if let city = state.city {
            header = city.name
        } else {
            header = "Nimbo"
        }
        let headerItem = NSMenuItem(title: header, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())

        let auto = add(menu, "Seguir el clima real", #selector(toggleAuto))
        auto.state = state.auto ? .on : .off
        if state.city == nil { auto.isEnabled = false; auto.action = nil }
        for kind in SceneKind.allCases {
            let entry = add(menu, kind.title, #selector(pickScene(_:)))
            entry.representedObject = kind.rawValue
            entry.image = NSImage(systemSymbolName: kind.symbol, accessibilityDescription: nil)
            entry.state = state.scene == kind ? .on : .off
        }
        menu.addItem(.separator())

        let workshop = NSMenu()
        add(workshop, "Hacer un muñeco de nieve", #selector(addSnowman))
        let hasTree = overlay?.mainScene?.hasTree ?? false
        add(workshop, hasTree ? "Quitar el árbol de Navidad" : "Poner un árbol de Navidad", #selector(toggleTree))
        if hasTree {
            add(workshop, "Colgar un adorno", #selector(addOrnament))
            if (overlay?.mainScene?.ornamentCount ?? 0) > 0 {
                add(workshop, "Quitar un adorno", #selector(removeOrnament))
            }
        }
        add(workshop, "Enviar el quitanieves", #selector(sendPlow))
        let cabin = add(workshop, "Cabaña con chimenea", #selector(toggleCabin))
        cabin.state = state.cabin ? .on : .off
        let workshopItem = NSMenuItem(title: "Taller de invierno", action: nil, keyEquivalent: "")
        workshopItem.submenu = workshop
        menu.addItem(workshopItem)

        add(menu, "Limpiar la nieve", #selector(clearSnow))
        add(menu, state.paused ? "Reanudar" : "Pausar", #selector(togglePause))
        menu.addItem(.separator())
        add(menu, "Ajustes…", #selector(openSettings), key: ",")
        menu.addItem(NSMenuItem(title: "Salir de Nimbo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func toggleAuto() { state.auto.toggle() }

    @objc private func pickScene(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let kind = SceneKind(rawValue: raw) else { return }
        state.choose(kind)
    }

    @objc private func addSnowman() { overlay?.mainScene?.addSnowman() }
    @objc private func toggleTree() { overlay?.mainScene?.toggleTree() }
    @objc private func addOrnament() { overlay?.mainScene?.addOrnament() }
    @objc private func removeOrnament() { overlay?.mainScene?.removeOrnament() }
    @objc private func sendPlow() { overlay?.mainScene?.sendPlow() }
    @objc private func toggleCabin() { state.cabin.toggle() }
    @objc private func clearSnow() { overlay?.clearSnow() }
    @objc private func togglePause() { state.paused.toggle() }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView(state: state))
            let window = NSWindow(contentViewController: controller)
            window.title = "Nimbo"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
