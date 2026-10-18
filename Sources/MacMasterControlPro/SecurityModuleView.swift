import SwiftUI
import AppKit
import MacMasterControlProCore

/// Modul L.x("Securitate & Confidențialitate", "Security & Privacy", "Seguridad y privacidad") — verificări 🔴/🟢 pe baza
/// recomandărilor din drduh/macOS-Security-and-Privacy-Guide, plus
/// acțiuni SIGURE (fără risc de blocare a Mac-ului sau necesitatea unui
/// recovery key manual) cu un singur click.
struct SecurityModuleView: View {
    @ObservedObject private var license = AccessCoordinator.shared
    @State private var showGate = false
    @State private var checks: [SecurityCheck] = []
    @State private var isBusy = false
    @State private var lastActionMessage: String?
    @State private var guideCheck: SecurityCheck?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(L.x("Securitate & Confidențialitate", "Security & Privacy", "Seguridad y privacidad"), systemImage: "checkmark.shield").font(.title2).bold()
                Spacer()
                if isBusy { ProgressView().controlSize(.small) }
                Button(L.x("Rescanează", "Rescan", "Volver a analizar")) { refresh() }
            }

            GroupBox(L.x("Verificări sistem", "System checks", "Comprobaciones del sistema")) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(checks) { check in
                        HStack {
                            Circle()
                                .fill(check.isGood ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(check.title)
                            Spacer()
                            Text(check.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if !check.isGood, !check.manualSteps.isEmpty {
                                Button(L.x("Cum rezolv?", "How do I fix it?", "¿Cómo lo arreglo?")) { guideCheck = check }
                                    .controlSize(.small)
                            }
                        }
                    }
                    if checks.isEmpty {
                        Text("Se scanează…").foregroundStyle(.secondary)
                    }
                }
                .padding(6)
            }

            GroupBox(L.x("Acțiuni rapide", "Quick actions", "Acciones rápidas")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button(L.x("Activează Firewall + Stealth Mode", "Enable Firewall + Stealth Mode", "Activar el cortafuegos + modo sigilo")) {
                            runGated {
                                SecurityService.enableFirewallWithStealth()
                                refresh(message: L.x("Firewall activat (stealth mode + fără excepții automate pentru aplicații semnate).", "Firewall enabled (stealth mode + no automatic exceptions for signed apps).", "Cortafuegos activado (modo sigilo y sin excepciones automáticas para apps firmadas)."))
                            }
                        }
                    }
                    HStack {
                        Button(L.x("Cere parolă imediat la screensaver", "Require password immediately after screensaver", "Pedir contraseña inmediatamente tras el salvapantallas")) {
                            runGated {
                                SecurityService.requirePasswordImmediatelyAtScreensaver()
                                refresh(message: L.x("Parola va fi cerută imediat la ieșirea din screensaver.", "The password will be required immediately when leaving the screensaver.", "Se pedirá la contraseña inmediatamente al salir del salvapantallas."))
                            }
                        }
                    }
                    if let lastActionMessage {
                        Label(lastActionMessage, systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(.green)
                    }
                }
                .padding(6)
            }

            GroupBox(L.x("Ce NU se face automat, și de ce", "What is NOT done automatically, and why", "Lo que NO se hace automáticamente, y por qué")) {
                Text(L.x("FileVault (cere cheie de recuperare confirmată manual), dezactivarea System Integrity Protection (necesită Recovery Mode), și configurarea DNS/VPN/Tor (alegere personală) rămân decizii luate direct din System Settings, niciodată dintr-un buton — riscul de a bloca sau expune Mac-ul fără să-ți dai seama e prea mare.", "FileVault (needs a manually confirmed recovery key), disabling System Integrity Protection (needs Recovery Mode) and configuring DNS/VPN/Tor (a personal choice) remain decisions made directly in System Settings, never from a button — the risk of locking or exposing your Mac without noticing is too high.", "FileVault (requiere una clave de recuperación confirmada a mano), desactivar System Integrity Protection (requiere el modo de recuperación) y configurar DNS/VPN/Tor (una decisión personal) siguen siendo decisiones que se toman directamente en Ajustes del Sistema, nunca desde un botón: el riesgo de bloquear o exponer el Mac sin darte cuenta es demasiado alto."))
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(6)
            }

            Spacer()
        }
        .padding(24)
        .onAppear { refresh() }
        .sheet(isPresented: $showGate) { AccessGateSheet() }
        .sheet(item: $guideCheck) { check in
            SecurityGuideSheet(check: check) { guideCheck = nil }
        }
    }

    private func refresh(message: String? = nil) {
        isBusy = true
        lastActionMessage = message
        DispatchQueue.global(qos: .userInitiated).async {
            let result = SecurityService.runAllChecks()
            DispatchQueue.main.async {
                checks = result
                isBusy = false
            }
        }
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.allowsFeatures {
            action()
        } else {
            showGate = true
        }
    }
}

/// Ghid pas-cu-pas pentru o verificare de securitate care nu se poate
/// rezolva automat (2026-08-31, raportat de Cristi: "arată doar roșu/
/// verde, nu ajută cu nimic să rezolv, pare ca aplicația nu funcționează").
private struct SecurityGuideSheet: View {
    let check: SecurityCheck
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Cum activez: \(check.title)").font(.title3).bold()
                Spacer()
                Button(L.x("Închide", "Close", "Cerrar"), action: onClose)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(check.manualSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).").bold().frame(width: 18, alignment: .trailing)
                        Text(step)
                    }
                }
            }
            if let pane = check.settingsPane {
                Button(L.x("Deschide System Settings", "Open System Settings", "Abrir Ajustes del Sistema")) {
                    if let url = URL(string: "x-apple.systempreferences:\(pane)") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}
