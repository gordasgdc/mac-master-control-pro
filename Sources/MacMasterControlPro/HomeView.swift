import SwiftUI
import AppKit
import MacMasterControlProCore

/// Acasă, direcția „Studio Glass”: volumele reale cu iconurile sistemului și gradul lor de ocupare, o acțiune principală, apoi ce merită verificat.
/// Stările necunoscute se afișează ca necunoscute (nu verde/roșu fără dovadă).
struct HomeView: View {
    @ObservedObject var checker: DependencyChecker
    let navigate: (SidebarItem) -> Void
    @ObservedObject private var access = AccessCoordinator.shared
    @State private var volumes: [Volume] = []
    @State private var securityGood: Bool?
    @State private var networkTuningActive: Bool?
    @State private var loginItemsGood: Bool?

    struct Volume: Identifiable { let id: String; let entry: DiskEntry; let total: Int64; let free: Int64 }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Studio.canvasTop, Studio.canvasBottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Master Control Studio Pro").font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("Spațiu, curățenie și controlul sistemului pentru stațiile de montaj.").foregroundStyle(Studio.textMuted)
                    }
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(volumes) { v in volumeCard(v) }
                        if volumes.isEmpty { ProgressView().controlSize(.small) }
                    }
                    HStack {
                        Button { navigate(.diskAnalyzer) } label: { Label("Vezi ce ocupă spațiul", systemImage: "chart.pie.fill").fontWeight(.semibold).padding(.horizontal, 6) }
                            .buttonStyle(.borderedProminent).tint(Studio.accent).controlSize(.large)
                        Button { navigate(.cleanup) } label: { Label("Curățare", systemImage: "sparkles") }.controlSize(.large)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Ce merită verificat").font(.title3.weight(.semibold)).padding(.bottom, 8)
                        check("Securitate", detail: "FileVault, SIP, Gatekeeper, firewall", good: securityGood, item: .security)
                        check("Aplicații de fundal", detail: "agenți terți care concurează pentru CPU/RAM", good: loginItemsGood, item: .loginItems)
                        check("Dependențe", detail: "rclone, macFUSE, Homebrew", good: checker.items.isEmpty ? nil : checker.allInstalled, item: .dependencies)
                        check("Tuning de rețea persistent", detail: "starea configurării aplicate", good: networkTuningActive, item: .network, neutralWhenOff: true)
                    }
                    .padding(18).background(Studio.card, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Studio.line))
                    AccessPanel(compact: true).padding(.top, 4)
                }
                .padding(32).frame(maxWidth: 980, alignment: .leading)
            }
        }
        .task { await loadVolumes(); await refreshStatuses() }
    }

    private func volumeCard(_ v: Volume) -> some View {
        let used = max(0, v.total - v.free)
        let frac = v.total > 0 ? Double(used) / Double(v.total) : 0
        return Button {
            DiskAnalyzerViewModel.shared.startIndexing(root: v.entry)
            navigate(.diskAnalyzer)
        } label: {
            VStack(spacing: 8) {
                SystemIconView(path: v.entry.path, size: 64)
                Text(v.entry.name.replacingOccurrences(of: " (volum principal)", with: "")).font(.headline).lineLimit(1)
                ProgressView(value: frac).tint(frac > 0.9 ? Studio.caution : Studio.accent)
                Text("\(Studio.gb(used)) folosit · \(Studio.gb(v.free)) liber").font(.caption).foregroundStyle(Studio.textMuted)
            }
            .padding(16).frame(width: 220)
            .background(Studio.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Studio.line))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(v.entry.name): \(Studio.gb(used)) folosit din \(Studio.gb(v.total))")
    }

    private func check(_ title: String, detail: String, good: Bool?, item: SidebarItem, neutralWhenOff: Bool = false) -> some View {
        VStack(spacing: 0) { Button { navigate(item) } label: {
            HStack(spacing: 12) {
                Image(systemName: good == nil ? "questionmark.circle" : (good! ? "checkmark.circle.fill" : (neutralWhenOff ? "circle.dashed" : "exclamationmark.triangle.fill")))
                    .foregroundStyle(good == nil ? Studio.textMuted : (good! ? Studio.good : (neutralWhenOff ? Studio.textMuted : Studio.caution)))
                    .font(.title3).frame(width: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).fontWeight(.semibold)
                    Text(detail).font(.caption).foregroundStyle(Studio.textMuted)
                }
                Spacer()
                Text(good == nil ? "Se verifică…" : (good! ? "În regulă" : (neutralWhenOff ? "Neaplicat" : "De verificat"))).font(.callout).foregroundStyle(Studio.textMuted)
                Image(systemName: "chevron.right").foregroundStyle(Studio.textMuted)
            }
            .padding(.vertical, 10).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        Divider().opacity(0.6) }
    }

    private func loadVolumes() async {
        let roots = DiskAnalyzerService.availableRoots()
        let result: [Volume] = await Task.detached(priority: .utility) {
            roots.map { r in
                let u = URL(fileURLWithPath: r.path)
                let v = try? u.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
                return Volume(id: r.id, entry: r, total: Int64(v?.volumeTotalCapacity ?? 0), free: v?.volumeAvailableCapacityForImportantUsage ?? 0)
            }
        }.value
        volumes = result
    }

    private func refreshStatuses() async {
        let net = NetworkService()
        net.refreshPersistentTuningStatus()
        let security = SecurityService.runAllChecks()
        let loginItemsLoaded = LoginItemsService.scan().contains { $0.isLoaded }
        await MainActor.run {
            networkTuningActive = net.persistentTuningActive
            securityGood = security.allSatisfy(\.isGood)
            loginItemsGood = !loginItemsLoaded
        }
    }
}
