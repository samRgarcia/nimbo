import AppKit
import Combine

/// Las diez escenas de clima.
enum SceneKind: String, CaseIterable, Identifiable {
    case snow, rain, petals, leaves, fireflies, meteors, storm, cloud, mist, clear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .snow: return "Nieve"
        case .rain: return "Lluvia"
        case .petals: return "Pétalos"
        case .leaves: return "Hojas"
        case .fireflies: return "Luciérnagas"
        case .meteors: return "Meteoros"
        case .storm: return "Tormenta"
        case .cloud: return "Nublado"
        case .mist: return "Neblina"
        case .clear: return "Despejado"
        }
    }

    var symbol: String {
        switch self {
        case .snow: return "snowflake"
        case .rain: return "cloud.rain"
        case .petals: return "camera.macro"
        case .leaves: return "leaf"
        case .fireflies: return "sparkles"
        case .meteors: return "moon.stars"
        case .storm: return "cloud.bolt.rain"
        case .cloud: return "cloud"
        case .mist: return "cloud.fog"
        case .clear: return "sun.max"
        }
    }
}

struct City: Codable, Equatable, Identifiable {
    var name: String
    var region: String
    var latitude: Double
    var longitude: Double

    var id: String { "\(name)|\(region)|\(latitude)|\(longitude)" }
}

struct HourForecast: Identifiable {
    let id: Int
    let date: Date
    let temperature: Double
    let code: Int
    let isDay: Bool
}

/// Códigos de clima WMO (los que devuelve Open-Meteo).
enum WMO {
    static func text(_ code: Int) -> String {
        switch code {
        case 0: return "Despejado"
        case 1: return "Mayormente despejado"
        case 2: return "Parcialmente nublado"
        case 3: return "Nublado"
        case 45, 48: return "Neblina"
        case 51, 53, 55, 56, 57: return "Llovizna"
        case 61, 63, 65, 66, 67: return "Lluvia"
        case 71, 73, 75, 77: return "Nieve"
        case 80, 81, 82: return "Chubascos"
        case 85, 86: return "Nevadas"
        case 95, 96, 99: return "Tormenta"
        default: return "—"
        }
    }

    static func symbol(_ code: Int, isDay: Bool) -> String {
        switch code {
        case 0, 1: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67, 80, 81, 82: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    /// Qué tan fuerte cae según el código: ligero, normal o intenso.
    static func strength(_ code: Int) -> Double {
        switch code {
        case 51, 56, 61, 66, 71, 80, 85: return 0.6
        case 55, 57, 65, 67, 75, 82, 86, 99: return 1.5
        default: return 1
        }
    }

    /// Qué escena corresponde al clima real.
    static func scene(code: Int, isDay: Bool, temperature: Double, latitude: Double, date: Date = Date()) -> SceneKind {
        switch code {
        case 2, 3: return .cloud
        case 45, 48: return .mist
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: return .rain
        case 71, 73, 75, 77, 85, 86: return .snow
        case 95, 96, 99: return .storm
        default: break
        }
        // Cielo despejado: un toque según la hora y la estación.
        if !isDay { return temperature >= 20 ? .fireflies : .meteors }
        var month = Calendar.current.component(.month, from: date)
        if latitude < 0 { month = (month + 5) % 12 + 1 }  // estaciones invertidas en el sur
        switch month {
        case 3, 4, 5: return .petals
        case 9, 10, 11: return .leaves
        default: return .clear
        }
    }
}

/// Estado compartido de la app. Se guarda en UserDefaults.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    private let defaults = UserDefaults.standard

    @Published var auto: Bool { didSet { defaults.set(auto, forKey: "auto"); applyAutoScene() } }
    @Published var scene: SceneKind { didSet { defaults.set(scene.rawValue, forKey: "scene") } }
    @Published var intensity: Double { didSet { defaults.set(intensity, forKey: "intensity") } }
    @Published var paused: Bool { didSet { defaults.set(paused, forKey: "paused") } }
    @Published var cabin: Bool { didSet { defaults.set(cabin, forKey: "cabin") } }
    @Published var eco: Bool { didSet { defaults.set(eco, forKey: "eco") } }
    @Published var showTemperature: Bool { didSet { defaults.set(showTemperature, forKey: "showTemperature") } }
    @Published var fahrenheit: Bool { didSet { defaults.set(fahrenheit, forKey: "fahrenheit") } }
    @Published var hideInFullscreen: Bool { didSet { defaults.set(hideInFullscreen, forKey: "hideInFullscreen") } }
    @Published var city: City? {
        didSet {
            if let city = city, let data = try? JSONEncoder().encode(city) {
                defaults.set(data, forKey: "city")
            } else {
                defaults.removeObject(forKey: "city")
            }
        }
    }

    @Published var temperature: Double?
    @Published var weatherCode: Int?
    @Published var isDay = true
    @Published var wind: Double = 0
    /// De dónde viene el viento, en grados (270 = del oeste).
    @Published var windDirection: Double = 270
    /// Multiplica la intensidad cuando el clima real es ligero o fuerte.
    @Published var boost: Double = 1
    @Published var hours: [HourForecast] = []
    @Published var lastError: String?

    private var timer: Timer?

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: ["auto": true, "intensity": 1.0, "cabin": true, "hideInFullscreen": true])
        auto = defaults.bool(forKey: "auto")
        scene = SceneKind(rawValue: defaults.string(forKey: "scene") ?? "") ?? .snow
        intensity = defaults.double(forKey: "intensity")
        paused = defaults.bool(forKey: "paused")
        cabin = defaults.bool(forKey: "cabin")
        eco = defaults.bool(forKey: "eco")
        showTemperature = defaults.bool(forKey: "showTemperature")
        fahrenheit = defaults.bool(forKey: "fahrenheit")
        hideInFullscreen = defaults.bool(forKey: "hideInFullscreen")
        if let data = defaults.data(forKey: "city") {
            city = try? JSONDecoder().decode(City.self, from: data)
        } else {
            city = nil
        }
    }

    /// Ahorro activo: lo eligió el usuario o la Mac está en modo de bajo consumo.
    var ecoActive: Bool { eco || ProcessInfo.processInfo.isLowPowerModeEnabled }

    /// Viento con signo: positivo sopla hacia la derecha de la pantalla.
    var signedWind: Double { -sin(windDirection * .pi / 180) * wind }

    var effectiveIntensity: Double { intensity * boost }

    func temperatureText(_ celsius: Double) -> String {
        let value = fahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))°"
    }

    /// Empieza a consultar el clima cada 15 minutos y al despertar la Mac.
    func start() {
        Task { await refreshWeather() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in await AppState.shared.refreshWeather() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { _ in
            Task { @MainActor in await AppState.shared.refreshWeather() }
        }
    }

    func choose(_ kind: SceneKind) {
        auto = false
        scene = kind
    }

    func setCity(_ newCity: City) {
        city = newCity
        Task { await refreshWeather() }
    }

    func refreshWeather() async {
        guard let city = city else { return }
        do {
            let response = try await WeatherService.forecast(for: city)
            temperature = response.current.temperature_2m
            weatherCode = response.current.weather_code
            isDay = response.current.is_day == 1
            wind = response.current.wind_speed_10m
            windDirection = response.current.wind_direction_10m ?? 270
            var list: [HourForecast] = []
            for (index, time) in response.hourly.time.enumerated() {
                guard index < response.hourly.temperature_2m.count,
                      index < response.hourly.weather_code.count,
                      let temp = response.hourly.temperature_2m[index],
                      let code = response.hourly.weather_code[index] else { continue }
                let day = index < response.hourly.is_day.count ? (response.hourly.is_day[index] ?? 1) == 1 : true
                list.append(HourForecast(id: index, date: Date(timeIntervalSince1970: time),
                                         temperature: temp, code: code, isDay: day))
            }
            hours = list
            lastError = nil
            applyAutoScene()
        } catch {
            lastError = "No se pudo consultar el clima. Revisa tu conexión."
        }
    }

    private func applyAutoScene() {
        guard auto, let city = city, let code = weatherCode, let temp = temperature else {
            if boost != 1 { boost = 1 }
            return
        }
        let strength = WMO.strength(code)
        if boost != strength { boost = strength }
        let next = WMO.scene(code: code, isDay: isDay, temperature: temp, latitude: city.latitude)
        if next != scene { scene = next }
    }
}
