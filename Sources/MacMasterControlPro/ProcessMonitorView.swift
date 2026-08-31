import SwiftUI
import MacMasterControlProCore

/// Modul "Procese" — vezi ce consumă CPU/RAM acum, închide ce e blocat.
/// Auto-actualizare la 3s cât timp ecranul e deschis.
struct ProcessMonitorView: View {
    @State private var processes: [RunningProcess] = []
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("⚙️ Procese active").font(.title2).bold()
                Spacer()
                Button("Actualizează") { refresh() }
            }
            Text("Top 20 după consum CPU, actualizat automat la 3 secunde.")
                .font(.caption).foregroundStyle(.secondary)

            List(processes) { process in
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
