import SwiftUI
import MacMasterControlProCore

/// Faza 3 - explorare rapida a unui remote FARA sa-l montezi, prin
/// `rclone lsjson`. Util cand vrei doar sa vezi ce e acolo, fara sa
/// creezi un mount/disc virtual pentru o verificare de 5 secunde.
struct RemoteBrowserSheet: View {
    let service: CloudManagerService
    let remoteName: String
    @Environment(\.dismiss) private var dismiss

    @State private var path = ""
    @State private var entries: [RemoteEntry] = []
    @State private var isLoading = false

    private var breadcrumb: String { path.isEmpty ? "\(remoteName):" : "\(remoteName):/\(path)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Explorare — \(remoteName)").font(.title3).bold()
                Spacer()
                Button("Închide") { dismiss() }
            }

            HStack {
                if !path.isEmpty {
                    Button("⬅︎ Înapoi") { goUp() }
                }
                Text(breadcrumb).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                if isLoading { ProgressView().controlSize(.small) }
            }

            List(entries) { entry in
                HStack {
                    Image(systemName: entry.isDir ? "folder.fill" : "doc")
                        .foregroundStyle(entry.isDir ? .yellow : .secondary)
                    Text(entry.name)
                    Spacer()
                    if !entry.isDir {
                        Text(formattedSize(entry.size)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { if entry.isDir { open(entry) } }
            }
            .frame(minWidth: 420, minHeight: 320)
        }
        .padding(20)
        .onAppear { reload() }
    }

    private func open(_ entry: RemoteEntry) {
        path = entry.path
        reload()
    }

    private func goUp() {
        var parts = path.split(separator: "/").map(String.init)
        if !parts.isEmpty { parts.removeLast() }
        path = parts.joined(separator: "/")
        reload()
    }

    private func reload() {
        isLoading = true
        let currentPath = path
        DispatchQueue.global(qos: .userInitiated).async {
            let result = service.listRemoteFolder(remoteName: remoteName, path: currentPath)
            DispatchQueue.main.async {
                entries = result
                isLoading = false
            }
        }
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
