import SwiftUI
import MacMasterControlProCore

/// Sănătate discuri de scratch/cache (2026-08-31, Nivel 1 #3) - testul de
/// viteză e manual, per disc (buton explicit), NU automat pentru toate -
/// ar scrie fișiere de test peste tot fără să fie cerut.
struct DiskHealthView: View {
    @State private var disks: [DiskHealth] = []
    @State private var testingPath: String?
    @State private var errors: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("💽 Sănătate Discuri").font(.title2).bold()
                Spacer()
                Button("Rescanează") { refresh() }
            }
            Text("Spațiu liber, status SMART și test opțional de viteză de scriere — un disc de scratch/cache aproape plin sau pe moarte e cauza cea mai frecventă a randărilor care se blochează la mijloc.")
                .font(.caption).foregroundStyle(.secondary)

            ForEach(disks) { disk in
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: disk.isInternal ? "internaldrive" : "externaldrive")
                            Text(disk.name).font(.headline)
                            if disk.isLowSpace {
                                Label("Spațiu redus", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                            if disk.isFailing {
                                Label("SMART: posibilă defecțiune", systemImage: "xmark.octagon.fill")
                                    .font(.caption).foregroundStyle(.red)
                            }
                            Spacer()
                            Button(testingPath == disk.mountPath ? "Se testează…" : "Testează viteza") {
                                runSpeedTest(disk)
                            }
                            .disabled(testingPath != nil)
                            .controlSize(.small)
                            .help("Scrie temporar 256 MB pe acest disc și măsoară cât durează — un test real de viteză, nu o valoare din specificațiile producătorului.")
                        }

                        ProgressView(value: 100 - disk.freePercent, total: 100)
                            .tint(disk.isLowSpace ? .orange : .accentColor)
                        HStack {
                            Text(String(format: "%.1f GB liberi din %.1f GB (%.0f%% liber)",
                                        Double(disk.availableBytes) / 1_073_741_824,
                                        Double(disk.totalBytes) / 1_073_741_824,
                                        disk.freePercent))
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            if let smart = disk.smartStatus {
                                Text("SMART: \(smart)").font(.caption).foregroundStyle(.secondary)
                            }
                            if let speed = disk.writeSpeedMBps {
                                Text(String(format: "Scriere: %.0f MB/s", speed))
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        if let error = errors[disk.mountPath] {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(.red)
                        }
                    }
                    .padding(6)
                }
            }
            Spacer()
        }
        .padding(24)
        .onAppear { refresh() }
    }

    private func refresh() {
        disks = DiskHealthService.scanVolumes()
    }

    private func runSpeedTest(_ disk: DiskHealth) {
        testingPath = disk.mountPath
        errors[disk.mountPath] = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = DiskHealthService.measureWriteSpeed(mountPath: disk.mountPath)
            DispatchQueue.main.async {
                switch result {
                case .success(let speed):
                    if let index = disks.firstIndex(where: { $0.mountPath == disk.mountPath }) {
                        disks[index].writeSpeedMBps = speed
                    }
                case .failure(let error):
                    errors[disk.mountPath] = error.message
                }
                testingPath = nil
            }
        }
    }
}
