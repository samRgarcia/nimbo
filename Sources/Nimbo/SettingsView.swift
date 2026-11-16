import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var query = ""
    @State private var results: [City] = []
    @State private var searching = false
    @State private var notFound = false
    @State private var launchAtLogin = LoginItem.isEnabled

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            citySearch
            if !state.hours.isEmpty { forecast }

            Divider()
            Toggle("Seguir el clima real de mi ciudad", isOn: $state.auto)
                .disabled(state.city == nil)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(SceneKind.allCases) { kind in
                    Button {
                        state.choose(kind)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: kind.symbol).font(.title3)
                            Text(kind.title).font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(state.scene == kind ? Color.accentColor : Color.secondary)
                }
            }
            HStack {
                Text("Intensidad")
                Slider(value: $state.intensity, in: 0.2...2)
                Text("\(Int((state.intensity * 100).rounded()))%")
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }

            Divider()
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Cabaña cuando nieva", isOn: $state.cabin)
                    Toggle("Ocultar en pantalla completa", isOn: $state.hideInFullscreen)
                    Toggle("Ahorro de energía", isOn: $state.eco)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Temperatura en la barra de menús", isOn: $state.showTemperature)
                    Toggle("Usar grados Fahrenheit", isOn: $state.fahrenheit)
                    Toggle("Abrir al iniciar sesión", isOn: Binding(
                        get: { launchAtLogin },
                        set: { value in
                            LoginItem.set(value)
                            launchAtLogin = LoginItem.isEnabled
                        }
                    ))
                }
            }
            Text("Consejo: mantén presionada la tecla Opción y mueve el cursor sobre la nieve para rodar una bola. Apila tres para armar un muñeco.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Link("Datos del clima: Open-Meteo (CC BY 4.0)", destination: URL(string: "https://open-meteo.com/")!)
                .font(.footnote)
        }
        .padding(20)
        .frame(width: 520)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: state.weatherCode.map { WMO.symbol($0, isDay: state.isDay) } ?? state.scene.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 34))
                .frame(width: 48)
            VStack(alignment: .leading, spacing: 2) {
                if let city = state.city {
                    Text(city.name).font(.title3.bold())
                    if let temp = state.temperature, let code = state.weatherCode {
                        Text("\(state.temperatureText(temp)) · \(WMO.text(code)) · viento \(Int(state.wind.rounded())) km/h")
                            .foregroundStyle(.secondary)
                    } else if let error = state.lastError {
                        Text(error).foregroundStyle(.secondary)
                    } else {
                        Text("Consultando el clima…").foregroundStyle(.secondary)
                    }
                } else {
                    Text("Elige tu ciudad").font(.title3.bold())
                    Text("Nimbo cambiará la escena según el clima real.").foregroundStyle(.secondary)
                }
            }
            Spacer()
            if state.city != nil {
                Button {
                    Task { await state.refreshWeather() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Actualizar el clima")
            }
        }
    }

    private var citySearch: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Buscar ciudad…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { search() }
                if searching {
                    ProgressView().controlSize(.small)
                }
                Button("Buscar") { search() }
                    .disabled(query.trimmingCharacters(in: .whitespaces).count < 2 || searching)
            }
            if notFound {
                Text("No encontré esa ciudad.").font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(results) { city in
                Button {
                    state.setCity(city)
                    results = []
                    query = ""
                } label: {
                    HStack {
                        Text(city.name)
                        Text(city.region).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var forecast: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(state.hours) { hour in
                    VStack(spacing: 4) {
                        Text(hour.date, format: .dateTime.hour())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Image(systemName: WMO.symbol(hour.code, isDay: hour.isDay))
                            .symbolRenderingMode(.multicolor)
                            .frame(height: 18)
                        Text(state.temperatureText(hour.temperature)).font(.caption)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func search() {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard text.count >= 2, !searching else { return }
        searching = true
        notFound = false
        Task {
            let found = (try? await WeatherService.search(text)) ?? []
            results = found
            notFound = found.isEmpty
            searching = false
        }
    }
}
