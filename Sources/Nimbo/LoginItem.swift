import ServiceManagement

/// Abrir Nimbo al iniciar sesión. Solo funciona con la app armada (Nimbo.app).
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Nimbo: no se pudo cambiar el inicio de sesión: \(error.localizedDescription)")
        }
    }
}
