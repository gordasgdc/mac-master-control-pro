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
                Label("Procese active", systemImage: "speedometer").font(.title2).bold()
                Spacer()
                Picker("Sortează", selection: $sortKey) {
                    ForEach(ProcessSortKey.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                Button(largestFirst ? "Cel mai mare întâi" : "Cel mai mic întâi") { largestFirst.toggle() }
                    .controlSize(.small)
                Button("Actualizează") { refresh() }
            }
            Text("Top 20, actualizat automat la 3 secunde — sortabil după CPU sau RAM, crescător sau descrescător.")
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
                    Button("Închide") { terminate(process, force: false) }
                        .help("Cere procesului să se închidă normal — dacă nu răspunde în o secundă, insistă automat cu o închidere forțată.")
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
