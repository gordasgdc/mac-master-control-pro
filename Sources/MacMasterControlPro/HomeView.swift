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

    private var volumeColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: min(max(volumes.count, 2), 4))
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Studio.canvasTop, Studio.canvasBottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    LazyVGrid(columns: volumeColumns, alignment: .leading, spacing: 16) {
                        ForEach(volumes) { v in volumeCard(v) }
                    }
                    if volumes.isEmpty { ProgressView().controlSize(.small) }
                    HStack(alignment: .top, spacing: 20) {
                        checksCard.frame(maxWidth: .infinity, alignment: .topLeading)
                        AccessPanel(compact: true)
                            .padding(18).frame(width: 330, alignment: .topLeading)
                            .background(Studio.card, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Studio.line))
                    }
                }
                .padding(28).frame(maxWidth: 1180, alignment: .leading).frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .task { await loadVolumes(); await refreshStatuses() }
    }

    /// Titlu, rezumat, acțiunea principală și ilustrația, într-un singur panou: textul în stânga pe fundal neutru, imaginea în dreapta.
    private var hero: some View {
        let usedTotal = volumes.reduce(Int64(0)) { $0 + max(0, $1.total - $1.free) }
        let freeTotal = volumes.reduce(Int64(0)) { $0 + $1.free }
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Master Control Studio Pro").font(.system(size: 30, weight: .bold, design: .rounded))
                Text(L.x("Spațiu, curățenie și controlul sistemului pentru stațiile de montaj.", "Space, cleanup and system control for editing workstations.", "Espacio, limpieza y control del sistema para estaciones de montaje.")).foregroundStyle(Studio.textMuted)
                if !volumes.isEmpty {
                    Text(String(format: L.x("%d volume · %@ folosit · %@ liber", "%d volumes · %@ used · %@ free", "%d volúmenes · %@ usado · %@ libre"), volumes.count, Studio.gb(usedTotal), Studio.gb(freeTotal)))
                        .font(.callout.weight(.medium)).padding(.top, 4)
                }
                Spacer(minLength: 8)
                HStack {
                    Button { navigate(.diskAnalyzer) } label: { Label(L.x("Vezi ce ocupă spațiul", "See what takes up space", "Ver qué ocupa espacio"), systemImage: "chart.pie.fill").fontWeight(.semibold).padding(.horizontal, 6) }
                        .buttonStyle(.borderedProminent).tint(Studio.accent).controlSize(.large)
                    Button { navigate(.cleanup) } label: { Label(L.x("Curățare", "Cleanup", "Limpieza"), systemImage: "sparkles") }.controlSize(.large)
                }
            }
            .padding(28).frame(maxWidth: .infinity, alignment: .topLeading)
            StudioArtFill(name: "home-glass").frame(maxWidth: .infinity).frame(minWidth: 280)
        }
        .frame(height: 250)
        .background(Studio.card, in: RoundedRectangle(cornerRadius: 24))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Studio.line))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
    }

    private var checksCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L.x("Ce merită verificat", "Worth checking", "Conviene revisar")).font(.title3.weight(.semibold)).padding(.bottom, 8)
                check(L.x("Securitate", "Security", "Seguridad"), detail: L.x("FileVault, SIP, Gatekeeper, firewall", "FileVault, SIP, Gatekeeper, firewall", "FileVault, SIP, Gatekeeper, firewall"), good: securityGood, item: .security)
                check(L.x("Aplicații de fundal", "Background apps", "Apps en segundo plano"), detail: L.x("agenți terți care concurează pentru CPU/RAM", "third-party agents competing for CPU/RAM", "agentes de terceros que compiten por CPU/RAM"), good: loginItemsGood, item: .loginItems)
                check(L.x("Dependențe", "Dependencies", "Dependencias"), detail: L.x("rclone, macFUSE, Homebrew", "rclone, macFUSE, Homebrew", "rclone, macFUSE, Homebrew"), good: checker.items.isEmpty ? nil : checker.allInstalled, item: .dependencies)
                check(L.x("Tuning de rețea persistent", "Persistent network tuning", "Ajuste de red persistente"), detail: L.x("starea configurării aplicate", "state of the applied configuration", "estado de la configuración aplicada"), good: networkTuningActive, item: .network, neutralWhenOff: true)
        }
        .padding(18).background(Studio.card, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Studio.line))
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
                Text(String(format: L.x("%@ folosit · %@ liber", "%@ used · %@ free", "%@ usado · %@ libre"), Studio.gb(used), Studio.gb(v.free))).font(.caption).foregroundStyle(Studio.textMuted)
            }
            .padding(16).frame(maxWidth: .infinity)
            .background(Studio.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Studio.line))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: L.x("%@: %@ folosit din %@", "%@: %@ used of %@", "%@: %@ usado de %@"), v.entry.name, Studio.gb(used), Studio.gb(v.total)))
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
                Text(good == nil ? L.x("Se verifică…", "Checking…", "Comprobando…") : (good! ? L.x("În regulă", "All good", "Correcto") : (neutralWhenOff ? L.x("Neaplicat", "Not applied", "No aplicado") : L.x("De verificat", "Needs attention", "Revisar")))).font(.callout).foregroundStyle(Studio.textMuted)
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
