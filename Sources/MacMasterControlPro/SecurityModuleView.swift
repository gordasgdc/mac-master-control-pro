import SwiftUI
import AppKit
import MacMasterControlProCore

/// Modul "Securitate & Confidențialitate" — verificări 🔴/🟢 pe baza
/// recomandărilor din drduh/macOS-Security-and-Privacy-Guide, plus
/// acțiuni SIGURE (fără risc de blocare a Mac-ului sau necesitatea unui
/// recovery key manual) cu un singur click.
struct SecurityModuleView: View {
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false
    @State private var checks: [SecurityCheck] = []
    @State private var isBusy = false
    @State private var lastActionMessage: String?
    @State private var guideCheck: SecurityCheck?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Securitate & Confidențialitate", systemImage: "checkmark.shield").font(.title2).bold()
                Spacer()
                if isBusy { ProgressView().controlSize(.small) }
                Button("Rescanează") { refresh() }
            }

            GroupBox("Verificări sistem") {
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
                                Button("Cum rezolv?") { guideCheck = check }
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

            GroupBox("Acțiuni rapide") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button("Activează Firewall + Stealth Mode") {
                            runGated {
                                SecurityService.enableFirewallWithStealth()
                                refresh(message: "Firewall activat (stealth mode + fără excepții automate pentru aplicații semnate).")
                            }
                        }
                    }
                    HStack {
                        Button("Cere parolă imediat la screensaver") {
                            runGated {
                                SecurityService.requirePasswordImmediatelyAtScreensaver()
                                refresh(message: "Parola va fi cerută imediat la ieșirea din screensaver.")
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

            GroupBox("Ce NU se face automat, și de ce") {
                Text("FileVault (cere cheie de recuperare confirmată manual), dezactivarea System Integrity Protection (necesită Recovery Mode), și configurarea DNS/VPN/Tor (alegere personală) rămân decizii luate direct din System Settings, niciodată dintr-un buton — riscul de a bloca sau expune Mac-ul fără să-ți dai seama e prea mare.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(6)
            }

            Spacer()
        }
        .padding(24)
        .onAppear { refresh() }
        .sheet(isPresented: $showGate) { TrialGateModal() }
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
        if license.isActivated {
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
                Button("Închide", action: onClose)
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
                Button("Deschide System Settings") {
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
