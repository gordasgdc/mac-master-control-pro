import SwiftUI
import AppKit
import MacMasterControlProCore

/// Un rand din lista de conturi Cloud - extras separat ca sa poata avea
/// propriul timer de statistici live (Faza 2) fara sa reincarce toata
/// lista la fiecare tick.
struct CloudRemoteRow: View {
    @ObservedObject var service: CloudManagerService
    let remote: CloudRemote
    @Binding var selected: Set<String>
    @State private var showBrowser = false
    @State private var stats: CloudTransferStats?

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    private var mountedDrive: MountedDrive? { service.mounted.first(where: { $0.remoteName == remote.name }) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Toggle(isOn: Binding(
                    get: { selected.contains(remote.name) },
                    set: { checked in
                        if checked { selected.insert(remote.name) } else { selected.remove(remote.name) }
                    }
                )) {
                    VStack(alignment: .leading) {
                        Text(remote.name).bold()
                        Text(remote.type).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                // Standard vizual unic (2026-08-31): punct verde/rosu, ca in
                // restul aplicatiei — nu doar text, la fel de scanabil dintr-o
                // privire ca dashboard-ul si modulul de Securitate.
                Circle()
                    .fill(mountedDrive != nil ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                if let drive = mountedDrive {
                    Text("Montat").font(.caption).foregroundStyle(.secondary)
                    Button("Deschide") { NSWorkspace.shared.open(URL(fileURLWithPath: drive.mountPath)) }
                        .buttonStyle(.plain).foregroundStyle(.blue).font(.caption)
                } else {
                    Text("Demontat").font(.caption).foregroundStyle(.secondary)
                }
                Button("Explorează") { showBrowser = true }
                    .buttonStyle(.plain).foregroundStyle(.blue).font(.caption)
                Button(role: .destructive) { service.deleteRemote(remote.name) } label: { Image(systemName: "trash") }
                    .buttonStyle(.plain)
            }
            // Faza 2: statistici live, doar cat timp e montat cu RC activ.
            if let stats, mountedDrive != nil {
                Text("↕︎ \(formattedSpeed(stats.speedBytesPerSec)) · \(formattedBytes(stats.bytesTransferred)) transferați · \(stats.activeTransfers) active")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .onReceive(timer) { _ in
            guard mountedDrive != nil else { stats = nil; return }
            stats = service.fetchStats(remoteName: remote.name)
        }
        .sheet(isPresented: $showBrowser) {
            RemoteBrowserSheet(service: service, remoteName: remote.name)
        }
    }

    private func formattedSpeed(_ bytesPerSec: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytesPerSec), countStyle: .file) + "/s"
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
