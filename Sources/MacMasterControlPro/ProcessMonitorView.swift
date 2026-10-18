import SwiftUI
import MacMasterControlProCore

/// Modul "Procese" — vezi ce consumă CPU/RAM acum, închide ce e blocat.
/// Auto-actualizare la 3s cât timp ecranul e deschis.
private enum ProcessSortKey: String, CaseIterable {
    case cpu = "CPU", memory = "RAM"
}

struct ProcessMonitorView: View {
    @State private var processes: [RunningProcess] = []
    @State private var timer: Timer?
    @State private var sortKey: ProcessSortKey = .cpu
    @State private var largestFirst = true

    private var sortedProcesses: [RunningProcess] {
        let sorted: [RunningProcess]
        switch sortKey {
        case .cpu: sorted = processes.sorted { $0.cpuPercent > $1.cpuPercent }
        case .memory: sorted = processes.sorted { $0.memoryMB > $1.memoryMB }
        }
        return largestFirst ? sorted : sorted.reversed()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(L.x("Procese active", "Active processes", "Procesos activos"), systemImage: "speedometer").font(.title2).bold()
                Spacer()
                Picker(L.x("Sortează", "Sort", "Ordenar"), selection: $sortKey) {
                    ForEach(ProcessSortKey.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                Button(largestFirst ? L.x("Cel mai mare întâi", "Largest first", "El mayor primero") : L.x("Cel mai mic întâi", "Smallest first", "El menor primero")) { largestFirst.toggle() }
                    .controlSize(.small)
                Button(L.x("Actualizează", "Refresh", "Actualizar")) { refresh() }
            }
            Text(L.x("Top 20, actualizat automat la 3 secunde — sortabil după CPU sau RAM, crescător sau descrescător.", "Top 20, refreshed automatically every 3 seconds — sortable by CPU or RAM, ascending or descending.", "Top 20, actualizado cada 3 segundos; ordenable por CPU o RAM, de forma ascendente o descendente."))
                .font(.caption).foregroundStyle(.secondary)

            List(sortedProcesses) { process in
                HStack {
                    Text(process.name).lineLimit(1)
                    Spacer()
                    Text(String(format: "%.1f%% CPU", process.cpuPercent))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(process.cpuPercent > 80 ? .red : .secondary)
                    Text(String(format: "%.0f MB", process.memoryMB))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .trailing)
                    Button(L.x("Închide", "Close", "Cerrar")) { terminate(process, force: false) }
                        .help(L.x("Cere procesului să se închidă normal — dacă nu răspunde în o secundă, insistă automat cu o închidere forțată.", "Asks the process to quit normally — if it does not respond within a second, it automatically escalates to a force quit.", "Pide al proceso que se cierre con normalidad; si no responde en un segundo, insiste automáticamente con un cierre forzado."))
                        .controlSize(.small)
                }
            }
        }
        .padding(24)
        .onAppear {
            refresh()
            timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in refresh() }
        }
        .onDisappear { timer?.invalidate() }
    }

    private func refresh() {
        DispatchQueue.global(qos: .utility).async {
            let result = ProcessMonitorService.topProcesses()
            DispatchQueue.main.async { processes = result }
        }
    }

    private func terminate(_ process: RunningProcess, force: Bool) {
        ProcessMonitorService.terminate(pid: process.id, force: force)
        // Daca mai apare dupa 1s, insista cu SIGKILL — un proces cu adevarat
        // blocat nu raspunde la SIGTERM.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if processes.contains(where: { $0.id == process.id }) {
                ProcessMonitorService.terminate(pid: process.id, force: true)
            }
            refresh()
        }
    }
}
