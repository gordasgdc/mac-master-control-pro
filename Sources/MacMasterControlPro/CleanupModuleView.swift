import SwiftUI
import MacMasterControlProCore

struct CleanupModuleView: View {
    @StateObject private var service = CleanupService()
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false
    @State private var report = "Apasă „Analizează” pentru a vedea spațiul recuperabil."

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("🧹 Curățare & RAM").font(.title2).bold()

            GroupBox("Analiză spațiu recuperabil") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(report).font(.system(.body, design: .monospaced))
                    Button("Analizează") { report = service.scanReclaimable() }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Acțiuni") {
                VStack(alignment: .leading, spacing: 10) {
                    Button("Curățare COMPLETĂ (Dev, Media, TM Snapshots, RAM)") {
                        runGated { service.fullClean() }
                    }.buttonStyle(.borderedProminent)
                    Button("Doar cache Media (DaVinci / Adobe)") { runGated { service.cleanMediaCaches() } }
                    Button("Șterge Snapshots Time Machine locale") { runGated { service.deleteTimeMachineSnapshots() } }
                    Button("Purjare RAM + Flush DNS") { runGated { service.purgeRAMAndFlushDNS() } }
                }
                .padding(6)
            }
            Spacer()
        }
        .padding(24)
        .sheet(isPresented: $showGate) { TrialGateModal() }
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.isActivated { action() } else { showGate = true }
    }
}
