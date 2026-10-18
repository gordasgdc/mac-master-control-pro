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
                Label(L.x("Sănătate Discuri", "Disk Health", "Salud de discos"), systemImage: "internaldrive").font(.title2).bold()
                Spacer()
                Button(L.x("Rescanează", "Rescan", "Volver a analizar")) { refresh() }
            }
            Text(L.x("Spațiu liber, status SMART și test opțional de viteză de scriere — un disc de scratch/cache aproape plin sau pe moarte e cauza cea mai frecventă a randărilor care se blochează la mijloc.", "Free space, SMART status and an optional write-speed test — a nearly full or failing scratch/cache drive is the most common cause of renders that stall midway.", "Espacio libre, estado SMART y una prueba opcional de velocidad de escritura: un disco de scratch/caché casi lleno o fallando es la causa más común de renders que se detienen a medias."))
                .font(.caption).foregroundStyle(.secondary)

            ForEach(disks) { disk in
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: disk.isInternal ? "internaldrive" : "externaldrive")
                            Text(disk.name).font(.headline)
                            if disk.isLowSpace {
                                Label(L.x("Spațiu redus", "Low space", "Poco espacio"), systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                            if disk.isFailing {
                                Label(L.x("SMART: posibilă defecțiune", "SMART: possible failure", "SMART: posible fallo"), systemImage: "xmark.octagon.fill")
                                    .font(.caption).foregroundStyle(.red)
                            }
                            Spacer()
                            Button(testingPath == disk.mountPath ? L.x("Se testează…", "Testing…", "Probando…") : L.x("Testează viteza", "Test speed", "Probar velocidad")) {
                                runSpeedTest(disk)
                            }
                            .disabled(testingPath != nil)
                            .controlSize(.small)
                            .help(L.x("Scrie temporar 256 MB pe acest disc și măsoară cât durează — un test real de viteză, nu o valoare din specificațiile producătorului.", "Temporarily writes 256 MB to this drive and measures how long it takes — a real speed test, not a manufacturer spec value.", "Escribe temporalmente 256 MB en este disco y mide cuánto tarda: una prueba real de velocidad, no un valor de las especificaciones del fabricante."))
                        }

                        ProgressView(value: 100 - disk.freePercent, total: 100)
                            .tint(disk.isLowSpace ? .orange : .accentColor)
                        HStack {
                            Text(String(format: L.x("%.1f GB liberi din %.1f GB (%.0f%% liber)", "%.1f GB free of %.1f GB (%.0f%% free)", "%.1f GB libres de %.1f GB (%.0f%% libre)"),
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
