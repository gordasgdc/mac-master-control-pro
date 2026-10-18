import SwiftUI
import MacMasterControlProCore

/// "Mod Randare" (2026-08-31, Nivel 1 #1) — un singur comutator care
/// elimină cele mai frecvente surse de încetinire în timpul unui export
/// lung (indexare Spotlight, Time Machine, prioritate proces). Vezi
/// RenderModeService.swift pentru mecanismul exact.
struct RenderModeView: View {
    @State private var previewLines: [String] = []
    @StateObject private var service = RenderModeService.shared
    @ObservedObject private var license = AccessCoordinator.shared
    @State private var showGate = false
    @State private var logLines: [String] = []
    /// Reîmprospătare periodică (nu doar la deschiderea paginii) — userul
    /// poate porni Premiere/Final Cut chiar cât se uită la acest ecran.
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Mod Randare", systemImage: "bolt.circle").font(.title2).bold()

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L.x("Pentru export-uri/randări lungi din orice aplicație — DaVinci Resolve, Final Cut Pro, Premiere Pro, Media Encoder, After Effects, Logic Pro, HandBrake și altele: pune pe pauză indexarea Spotlight și Time Machine (ambele pot concura pentru discul de proiect chiar în timpul randării), și ridică prioritatea aplicațiilor de mai sus care rulează acum.", "For long exports/renders from any app — DaVinci Resolve, Final Cut Pro, Premiere Pro, Media Encoder, After Effects, Logic Pro, HandBrake and others: pauses Spotlight indexing and Time Machine (both can compete for the project drive during the render) and raises the priority of the apps above that are running now.", "Para exportaciones o renders largos de cualquier app (DaVinci Resolve, Final Cut Pro, Premiere Pro, Media Encoder, After Effects, Logic Pro, HandBrake y otras): pausa la indexación de Spotlight y Time Machine (ambos pueden competir por el disco del proyecto durante el render) y sube la prioridad de las apps anteriores que se estén ejecutando."))
                        .font(.caption).foregroundStyle(.secondary)

                    HStack(spacing: 14) {
                        Circle()
                            .fill(service.isActive ? Color.green : Color.secondary.opacity(0.3))
                            .frame(width: 12, height: 12)
                        Text(service.isActive ? L.x("Mod Randare ACTIV", "Render Mode ON", "Modo de renderizado ACTIVO") : L.x("Mod Randare inactiv", "Render Mode off", "Modo de renderizado inactivo"))
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { service.isActive },
                            set: { newValue in
                                runGated {
                                    if newValue {
                                        logLines = []
                                        service.activate { logLines.append($0) }
                                    } else {
                                        service.deactivate { logLines.append($0) }
                                    }
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    if service.recoveredFromPreviousSession {
                        Label(L.x("Modul Randare era activ când aplicația s-a închis. Time Machine și Spotlight pot fi încă oprite de el. Dezactivează comutatorul pentru a restaura exact starea de dinainte.", "Render Mode was active when the app closed. Time Machine and Spotlight may still be paused by it. Turn the switch off to restore the exact previous state.", "El modo de renderizado estaba activo al cerrarse la app. Time Machine y Spotlight pueden seguir pausados por él. Desactiva el interruptor para restaurar exactamente el estado anterior."), systemImage: "arrow.counterclockwise.circle.fill")
                            .font(.callout).foregroundStyle(.orange)
                    }

                    if !service.isActive {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ce va schimba activarea acum").font(.caption.bold())
                            ForEach(previewLines, id: \.self) { Text("• " + $0).font(.caption).foregroundStyle(.secondary) }
                        }
                        .onAppear { previewLines = service.previewChanges() }
                    }

                    if service.isActive {
                        Label(L.x("Nu uita să dezactivezi Modul Randare după export — Time Machine și Spotlight rămân oprite cât timp comutatorul e ON.", "Remember to turn Render Mode off after the export — Time Machine and Spotlight stay paused while the switch is ON.", "No olvides desactivar el modo de renderizado tras exportar: Time Machine y Spotlight siguen pausados mientras el interruptor esté en ON."), systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                .padding(6)
            }

            detectedAppsSection

            if !logLines.isEmpty {
                TerminalLogView(lines: logLines)
            }
            Spacer()
        }
        .padding(24)
        .onAppear { service.refreshDetectedApps() }
        .onReceive(refreshTimer) { _ in service.refreshDetectedApps() }
        .sheet(isPresented: $showGate) { AccessGateSheet() }
    }

    /// [2026-09-03] Cerut explicit de Cristi: "iconița oficială de la
    /// Final Cut, iconița de la Premiere" — vizibil TOT timpul, nu doar în
    /// jurnalul de activare, ca userul să vadă dintr-o privire ce anume ar
    /// optimiza Modul Randare dacă l-ar porni chiar acum.
    @ViewBuilder
    private var detectedAppsSection: some View {
        GroupBox(L.x("Aplicații detectate acum", "Apps detected now", "Apps detectadas ahora")) {
            if service.detectedApps.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
                    Text(L.x("Nicio aplicație de randare cunoscută nu rulează — Modul Randare tot ajută la orice export/copiere masivă, prin Time Machine/Spotlight.", "No known render app is running — Render Mode still helps with any export or bulk copy, via Time Machine/Spotlight.", "No se está ejecutando ninguna app de render conocida; el modo de renderizado sigue ayudando en cualquier exportación o copia masiva, a través de Time Machine y Spotlight."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(6)
            } else {
                HStack(spacing: 16) {
                    ForEach(service.detectedApps) { app in
                        VStack(spacing: 4) {
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 32, height: 32)
                            Text(app.name)
                                .font(.caption2)
                                .lineLimit(1)
                                .frame(maxWidth: 84)
                        }
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.allowsFeatures { action() } else { showGate = true }
    }
}
