import SwiftUI
import MacMasterControlProCore

/// Profile de layout multi-monitor (2026-08-31, Nivel 3 #8) - salvează și
/// restaurează pozițiile ferestrelor unei aplicații (DaVinci Resolve sau
/// oricare alta) - necesită permisiunea de Accesibilitate (o singură dată).
struct WindowLayoutsView: View {
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false

    @State private var isTrusted = WindowLayoutService.isAccessibilityTrusted
    @State private var apps: [(name: String, bundleID: String, pid: pid_t)] = []
    @State private var selectedAppIndex: Int?
    @State private var profiles: [WindowLayoutProfile] = []
    @State private var newProfileName = ""
    @State private var status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("🪟 Layout Ferestre").font(.title2).bold()
            Text("Salvează pozițiile ferestrelor unei aplicații (ex. DaVinci Resolve) ca profil — util când schimbi frecvent între configurații de monitoare.")
                .font(.caption).foregroundStyle(.secondary)

            if !isTrusted {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Necesită permisiunea de Accesibilitate", systemImage: "lock.shield")
                            .font(.headline)
                        Text("macOS cere această permisiune o singură dată, ca aplicația să poată citi/muta ferestrele altor aplicații.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Acordă permisiunea…") {
                            WindowLayoutService.requestAccessibilityIfNeeded()
                        }
                        Button("Am acordat-o — reverifică") { isTrusted = WindowLayoutService.isAccessibilityTrusted }
                            .font(.caption)
                    }
                    .padding(6)
                }
            }

            GroupBox("Salvează layout-ul curent") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Aplicație", selection: $selectedAppIndex) {
                        Text("Alege…").tag(Int?.none)
                        ForEach(apps.indices, id: \.self) { i in
                            Text(apps[i].name).tag(Int?.some(i))
                        }
                    }
                    HStack {
                        TextField("Nume profil (ex: „Grading — 2 monitoare”)", text: $newProfileName)
                            .textFieldStyle(.roundedBorder)
                        Button("Salvează") { save() }
                            .disabled(!isTrusted || selectedAppIndex == nil || newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(6)
            }

            GroupBox("Profile salvate") {
                if profiles.isEmpty {
                    Text("Niciun profil salvat încă.").foregroundStyle(.secondary).padding(20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(profiles) { profile in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(profile.name).font(.headline)
                                    Text("\(profile.frames.count) ferestre · \(profile.savedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Restaurează") { runGated { restore(profile) } }
                                Button(role: .destructive) { WindowLayoutService.deleteProfile(named: profile.name); refresh() } label: {
                                    Image(systemName: "trash")
                                }
                            }
                            .padding(.vertical, 6)
                            Divider()
                        }
                    }
                    .padding(8)
                }
            }

            if let status {
                StatusBanner(text: status)
            }
            Spacer()
        }
        .padding(24)
        .onAppear { refresh() }
        .sheet(isPresented: $showGate) { TrialGateModal() }
    }

    private func refresh() {
        isTrusted = WindowLayoutService.isAccessibilityTrusted
        apps = WindowLayoutService.runningApps()
        profiles = WindowLayoutService.allProfiles()
    }

    private func save() {
        guard let i = selectedAppIndex else { return }
        let app = apps[i]
        let name = newProfileName.trimmingCharacters(in: .whitespaces)
        let ok = WindowLayoutService.saveLayout(name: name, appBundleID: app.bundleID, pid: app.pid)
        status = ok ? "✔ Profil „\(name)” salvat." : "✘ Nu s-au putut citi ferestrele — aplicația are ferestre deschise?"
        newProfileName = ""
        refresh()
    }

    private func restore(_ profile: WindowLayoutProfile) {
        guard let app = apps.first(where: { $0.bundleID == profile.appBundleID }) else {
            status = "✘ Aplicația „\(profile.appBundleID)” nu rulează acum."
            return
        }
        let count = WindowLayoutService.restoreLayout(profile, pid: app.pid)
        status = "✔ \(count) ferestre repoziționate din profilul „\(profile.name)”."
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.isActivated { action() } else { showGate = true }
    }
}
