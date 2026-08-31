import SwiftUI
import MacMasterControlProCore

/// Auditor de aplicații la pornire (2026-08-31, Nivel 1 #4) - buton
/// roșu/verde per element (Regula 26), niciodată o dezactivare în masă.
struct LoginItemsView: View {
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false
    @State private var items: [LoginItem] = []
    @State private var disabledLabels: Set<String> = []
    @State private var logLines: [String] = []
    @State private var busyItem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("🔌 Aplicații de fundal la pornire").font(.title2).bold()
                Spacer()
                Button("Rescanează") { refresh() }
            }
            Text("Servicii de fundal instalate de alte aplicații (nu cele de sistem Apple) — multe concurează pentru CPU/RAM exact când editezi sau randezi. Dezactivarea e reversibilă oricând, din „Reactivează”.")
                .font(.caption).foregroundStyle(.secondary)

            GroupBox {
                if items.isEmpty {
                    Text("Niciun serviciu de fundal tert-parte găsit.").foregroundStyle(.secondary).padding(20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.label).font(.system(.body, design: .monospaced))
                                    Text(item.isUserLevel ? "Utilizator" : "Sistem (necesită admin)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                let isDisabled = disabledLabels.contains(item.label)
                                Button(isDisabled ? "Reactivează" : "Dezactivează") {
                                    runGated { toggle(item, enable: isDisabled) }
                                }
                                .tint(isDisabled ? .green : .red)
                                .disabled(busyItem == item.label)
                            }
                            .padding(.vertical, 6)
                            Divider()
                        }
                    }
                    .padding(8)
                }
            }

            if !logLines.isEmpty {
                TerminalLogView(lines: logLines)
            }
            Spacer()
        }
        .padding(24)
        .onAppear { refresh() }
        .sheet(isPresented: $showGate) { TrialGateModal() }
    }

    private func refresh() {
        items = LoginItemsService.scan()
        disabledLabels = Set(LoginItemsService.disabledItems())
    }

    private func toggle(_ item: LoginItem, enable: Bool) {
        busyItem = item.label
        DispatchQueue.global(qos: .userInitiated).async {
            let log: (String) -> Void = { line in DispatchQueue.main.async { logLines.append(line) } }
            if enable {
                LoginItemsService.enable(item, log: log)
            } else {
                LoginItemsService.disable(item, log: log)
            }
            DispatchQueue.main.async {
                busyItem = nil
                refresh()
            }
        }
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.isActivated { action() } else { showGate = true }
    }
}
