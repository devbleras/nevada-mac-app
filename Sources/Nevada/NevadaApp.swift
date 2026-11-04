import SwiftUI
import AppKit
import ApplicationServices

@main
struct NevadaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = SnowSettings.shared

    var body: some Scene {
        MenuBarExtra {
            ControlPanel()
                .environmentObject(settings)
        } label: {
            Image(systemName: settings.isSnowing ? "snowflake" : "snowflake.slash")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlay: OverlayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        WindowTracker.shared.start()
        let controller = OverlayController()
        controller.start()
        overlay = controller
    }
}

// MARK: - Panel de control

struct ControlPanel: View {
    @EnvironmentObject private var settings: SnowSettings
    @State private var dockAllowed = AXIsProcessTrusted()
    @State private var launchAtLogin = SnowSettings.shared.launchAtLogin

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nevada").font(.headline)
                    Text(settings.isSnowing ? "Está nevando" : "Sin nieve")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $settings.isSnowing)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider()

            LabeledSlider(title: "Cantidad de copos", value: $settings.intensity, range: 0.1...1,
                          minLabel: "Poca", maxLabel: "Ventisca")
            LabeledSlider(title: "Viento", value: $settings.wind, range: -1...1,
                          minLabel: "Izquierda", maxLabel: "Derecha")
            LabeledSlider(title: "Tamaño de los copos", value: $settings.flakeSize, range: 0.6...1.8,
                          minLabel: "Finos", maxLabel: "Grandes")

            Divider()

            Toggle("Acumular nieve", isOn: $settings.accumulate)
            LabeledSlider(title: "Velocidad de acumulación", value: $settings.accumulationSpeed, range: 0.25...3,
                          minLabel: "Lenta", maxLabel: "Rápida")
                .disabled(!settings.accumulate)
                .opacity(settings.accumulate ? 1 : 0.5)
            Toggle("Nieve en la barra de menús", isOn: $settings.menuBarSnow)
                .disabled(!settings.accumulate)
            Toggle("Los copos esquivan el cursor", isOn: $settings.cursorInteraction)

            if !dockAllowed {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Para que la nieve se pose sobre el Dock, Nevada necesita permiso de Accesibilidad.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Dar permiso…") {
                        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                        dockAllowed = AXIsProcessTrustedWithOptions(options)
                    }
                    .controlSize(.small)
                }
            }

            Divider()

            Toggle("Abrir al iniciar sesión", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    settings.setLaunchAtLogin(newValue)
                    launchAtLogin = settings.launchAtLogin
                }
            ))

            HStack {
                Button("Barrer la nieve") { settings.sweep() }
                Spacer()
                Button("Salir") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 290)
        .onAppear {
            dockAllowed = AXIsProcessTrusted()
            launchAtLogin = settings.launchAtLogin
        }
    }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let minLabel: String
    let maxLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline)
            Slider(value: $value, in: range)
                .controlSize(.small)
            HStack {
                Text(minLabel)
                Spacer()
                Text(maxLabel)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}
