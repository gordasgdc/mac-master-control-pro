import SwiftUI
import AppKit
import MacMasterControlProCore

/// Modal de conversie afisat cand utilizatorul in Trial apasa o actiune
/// care scrie pe disc/sistem. Analiza (scanarile) ramane libera.
struct TrialGateModal: View {
    @ObservedObject var license = LicenseStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var key: String = ""
    @State private var showError = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
            Text(L.t("trial.title"))
                .font(.title2).bold()
            Text(L.t("trial.body"))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            TextField(L.t("trial.key"), text: $key)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            if showError, let error = license.lastError {
                Text(error).foregroundStyle(.red).font(.caption)
            }
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(MachineID.display, forType: .string)
            } label: {
                Text("Machine ID: \(MachineID.display) (copiază)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            HStack {
                Button(L.t("trial.donate")) {
                    NSWorkspace.shared.open(URL(string: "https://gordas.dev/mac-master-control-pro")!)
                }
                Button(L.t("trial.activate")) {
                    if license.activate(withKey: key) { dismiss() } else { showError = true }
                }
                .buttonStyle(.borderedProminent)
            }
            Button {
                let message = "Salut! Doresc să achiziționez / activez licența Lifetime (9 EUR) pentru Mac-ul meu — Master Control Studio Pro. Machine ID: \(MachineID.display)"
                NSWorkspace.shared.open(WhatsAppLink.url(text: message))
            } label: {
                Label(L.t("trial.whatsapp"), systemImage: "message.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.green)
            Button(L.t("trial.cancel")) { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 380)
    }
}
