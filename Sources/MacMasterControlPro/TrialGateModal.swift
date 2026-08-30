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
            Text("Analiza este 100% completă")
                .font(.title2).bold()
            Text("Susține dezvoltarea cu o donație (9€, o singură dată) pentru a debloca aplicarea modificărilor.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            TextField("Cheie de licență", text: $key)
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
                Button("Donează din GDC Plugin Manager") {
                    NSWorkspace.shared.open(URL(string: "https://gordas.dev/mac-master-control-pro")!)
                }
                Button("Activează") {
                    if license.activate(withKey: key) { dismiss() } else { showError = true }
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Anulează") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 380)
    }
}
