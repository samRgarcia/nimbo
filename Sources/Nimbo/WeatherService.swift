import Foundation

/// Clima y búsqueda de ciudades con Open-Meteo (gratis, sin clave).
enum WeatherService {
    struct GeoResponse: Decodable {
        struct Result: Decodable {
            let name: String
            let latitude: Double
            let longitude: Double
            let country: String?
            let admin1: String?
        }
        let results: [Result]?
    }

    struct ForecastResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
            let is_day: Int
            let wind_speed_10m: Double
            let wind_direction_10m: Double?
        }
        struct Hourly: Decodable {
            let time: [Double]
            let temperature_2m: [Double?]
            let weather_code: [Int?]
            let is_day: [Int?]
        }
        let current: Current
        let hourly: Hourly
    }

    static func search(_ query: String) async throws -> [City] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "6"),
            URLQueryItem(name: "language", value: "es"),
            URLQueryItem(name: "format", value: "json"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let decoded = try JSONDecoder().decode(GeoResponse.self, from: data)
        return (decoded.results ?? []).map { result in
            let region = [result.admin1, result.country].compactMap { $0 }.joined(separator: ", ")
            // Coordenadas redondeadas: basta para el clima y no revela la ubicación exacta.
            return City(name: result.name, region: region,
                        latitude: (result.latitude * 100).rounded() / 100,
                        longitude: (result.longitude * 100).rounded() / 100)
        }
    }

    static func forecast(for city: City) async throws -> ForecastResponse {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(city.latitude)),
            URLQueryItem(name: "longitude", value: String(city.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day,wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "forecast_hours", value: "24"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ForecastResponse.self, from: data)
    }
}
