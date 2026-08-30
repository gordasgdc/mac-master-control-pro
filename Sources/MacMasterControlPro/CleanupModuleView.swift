import SwiftUI
import MacMasterControlProCore

struct CleanupModuleView: View {
    @StateObject private var service = CleanupService()
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false
    @State private var selectedItems: Set<CleanableItem> = []
    @State private var selectedSnapshots: Set<String> = []
    @State private var status = ""

    private var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.sizeBytes } }
    private var totalBytes: Int64 { service.items.reduce(0) { $0 + $1.sizeBytes } }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("🧹 Curățare & RAM").font(.title2).bold()

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Cache-uri recuperabile").font(.headline)
                        Spacer()
                        Button(selectedItems.count == service.items.count ? "Deselectează tot" : "Selectează tot") {
                            selectedItems = selectedItems.count == service.items.count ? [] : Set(service.items)
                        }
                        .font(.caption)
                        Button("Rescanează") { service.scanReclaimable() }
                    }

                    ForEach(service.items) { item in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { selectedItems.contains(item) },
                                set: { checked in
                                    if checked { selectedItems.insert(item) } else { selectedItems.remove(item) }
                                }
                            )) {
                                Text(item.name)
                            }
                            Spacer()
                            Text(String(format: "%.2f GB", item.sizeGB))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()
                    Text(String(format: "Selectat %.2f GB din %.2f GB", Double(selectedBytes) / 1_073_741_824, Double(totalBytes) / 1_073_741_824))
                        .font(.caption).foregroundStyle(.secondary)

                    Button("Șterge cache-urile selectate") {
                        runGated { service.deleteSelected(selectedItems); selectedItems = []; status = "✔ Cache-uri șterse." }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedItems.isEmpty)
                }
                .padding(6)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Time Machine — Snapshots locale").font(.headline)
                        Spacer()
                        Button(selectedSnapshots.count == service.snapshotDates.count && !service.snapshotDates.isEmpty ? "Deselectează tot" : "Selectează tot") {
                            selectedSnapshots = selectedSnapshots.count == service.snapshotDates.count ? [] : Set(service.snapshotDates)
                        }
                        .font(.caption)
                        Button("Rescanează") { service.scanSnapshots() }
                    }
                    if service.snapshotDates.isEmpty {
                        Text("Niciun snapshot local găsit.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(service.snapshotDates, id: \.self) { date in
                            Toggle(isOn: Binding(
                                get: { selectedSnapshots.contains(date) },
                                set: { checked in
                                    if checked { selectedSnapshots.insert(date) } else { selectedSnapshots.remove(date) }
                                }
                            )) {
                                Text(date).font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                    Text("Selectat \(selectedSnapshots.count) din \(service.snapshotDates.count) snapshots")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Șterge snapshot-urile selectate") {
                        runGated { service.deleteSelectedSnapshots(selectedSnapshots); selectedSnapshots = []; status = "✔ Snapshots șterse." }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedSnapshots.isEmpty)
                }
                .padding(6)
            }

            GroupBox("RAM & DNS") {
                Button("Purjare RAM + Flush DNS") {
                    runGated { service.purgeRAMAndFlushDNS(); status = "✔ RAM eliberat, DNS golit." }
                }
                .padding(6)
            }

            if !status.isEmpty {
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(24)
        .onAppear { service.scanReclaimable(); service.scanSnapshots() }
        .sheet(isPresented: $showGate) { TrialGateModal() }
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.isActivated { action() } else { showGate = true }
    }
}
