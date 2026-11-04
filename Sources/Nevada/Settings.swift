import Foundation
import Combine
import ServiceManagement

/// Ajustes de la nevada, persistidos en UserDefaults.
@MainActor
final class SnowSettings: ObservableObject {
    static let shared = SnowSettings()

    private let defaults = UserDefaults.standard

    /// Si está nevando (si se apaga, los copos que quedan terminan de caer y la nieve se derrite).
    @Published var isSnowing: Bool { didSet { defaults.set(isSnowing, forKey: Keys.isSnowing) } }
    /// Cantidad de copos, 0.1 … 1.
    @Published var intensity: Double { didSet { defaults.set(intensity, forKey: Keys.intensity) } }
    /// Viento, -1 (izquierda) … 1 (derecha).
    @Published var wind: Double { didSet { defaults.set(wind, forKey: Keys.wind) } }
    /// Multiplicador del tamaño de los copos, 0.6 … 1.8.
    @Published var flakeSize: Double { didSet { defaults.set(flakeSize, forKey: Keys.flakeSize) } }
    /// Si la nieve se amontona sobre ventanas, widgets, menú, Dock y suelo.
    @Published var accumulate: Bool { didSet { defaults.set(accumulate, forKey: Keys.accumulate) } }
    /// Si se acumula escarcha colgando de la barra de menús.
    @Published var menuBarSnow: Bool { didSet { defaults.set(menuBarSnow, forKey: Keys.menuBarSnow) } }
    /// Velocidad a la que crece la nieve acumulada, 0.25 … 3.
    @Published var accumulationSpeed: Double { didSet { defaults.set(accumulationSpeed, forKey: Keys.accumulationSpeed) } }
    /// Los copos se apartan del cursor.
    @Published var cursorInteraction: Bool { didSet { defaults.set(cursorInteraction, forKey: Keys.cursorInteraction) } }

    /// Se dispara al pulsar "Barrer la nieve".
    let sweepRequests = PassthroughSubject<Void, Never>()

    private enum Keys {
        static let isSnowing = "isSnowing"
        static let intensity = "intensity"
        static let wind = "wind"
        static let flakeSize = "flakeSize"
        static let accumulate = "accumulate"
        static let accumulationSpeed = "accumulationSpeed"
        static let menuBarSnow = "menuBarSnow"
        static let cursorInteraction = "cursorInteraction"
    }

    private init() {
        defaults.register(defaults: [
            Keys.isSnowing: true,
            Keys.intensity: 0.55,
            Keys.wind: 0.1,
            Keys.flakeSize: 1.0,
            Keys.accumulate: true,
            Keys.accumulationSpeed: 1.0,
            Keys.cursorInteraction: true,
            Keys.menuBarSnow: true,
        ])
        menuBarSnow = defaults.bool(forKey: Keys.menuBarSnow)
        isSnowing = defaults.bool(forKey: Keys.isSnowing)
        intensity = defaults.double(forKey: Keys.intensity)
        wind = defaults.double(forKey: Keys.wind)
        flakeSize = defaults.double(forKey: Keys.flakeSize)
        accumulate = defaults.bool(forKey: Keys.accumulate)
        accumulationSpeed = defaults.double(forKey: Keys.accumulationSpeed)
        cursorInteraction = defaults.bool(forKey: Keys.cursorInteraction)
    }

    func sweep() { sweepRequests.send() }

    // MARK: Abrir al iniciar sesión

    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Nevada: no se pudo cambiar el inicio de sesión: \(error)")
        }
        objectWillChange.send()
    }
}
