import SwiftUI
import MacMasterControlProCore

/// Profile de layout multi-monitor (2026-08-31, Nivel 3 #8) - salvează și
/// restaurează pozițiile ferestrelor unei aplicații (DaVinci Resolve sau
/// oricare alta) - necesită permisiunea de Accesibilitate (o singură dată).
struct WindowLayoutsView: View {
    @ObservedObject private var license = AccessCoordinator.shared
    @State private var showGate = false

    @State private var isTrusted = WindowLayoutService.isAccessibilityTrusted
    @State private var apps: [(name: String, bundleID: String, pid: pid_t)] = []
    @State private var selectedAppIndex: Int?
    @State private var profiles: [WindowLayoutProfile] = []
    @State private var newProfileName = ""
    @State private var status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Layout Ferestre", systemImage: "macwindow.on.rectangle").font(.title2).bold()
            Text(L.x("Salvează pozițiile ferestrelor unei aplicații (ex. DaVinci Resolve) ca profil — util când schimbi frecvent între configurații de monitoare.", "Save an app’s window positions (e.g. DaVinci Resolve) as a profile — useful when you often switch between monitor setups.", "Guarda las posiciones de las ventanas de una app (p. ej. DaVinci Resolve) como perfil; útil si cambias a menudo de configuración de monitores."))
                .font(.caption).foregroundStyle(.secondary)

            if !isTrusted {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L.x("Necesită permisiunea de Accesibilitate", "Accessibility permission required", "Se necesita el permiso de Accesibilidad"), systemImage: "lock.shield")
                            .font(.headline)
                        Text(L.x("macOS cere această permisiune o singură dată, ca aplicația să poată citi/muta ferestrele altor aplicații.", "macOS asks for this permission once, so the app can read/move other apps’ windows.", "macOS pide este permiso una sola vez para que la app pueda leer y mover las ventanas de otras apps."))
                            .font(.caption).foregroundStyle(.secondary)
                        Button(L.x("Acordă permisiunea…", "Grant permission…", "Conceder permiso…")) {
                            WindowLayoutService.requestAccessibilityIfNeeded()
                        }
                        Button(L.x("Am acordat-o — reverifică", "I granted it — check again", "Ya lo concedí: volver a comprobar")) { isTrusted = WindowLayoutService.isAccessibilityTrusted }
                            .font(.caption)
                    }
                    .padding(6)
                }
            }

            GroupBox(L.x("Salvează layout-ul curent", "Save current layout", "Guardar la disposición actual")) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker(L.x("Aplicație", "App", "Aplicación"), selection: $selectedAppIndex) {
                        Text(L.x("Alege…", "Choose…", "Elegir…")).tag(Int?.none)
                        ForEach(apps.indices, id: \.self) { i in
                            Text(apps[i].name).tag(Int?.some(i))
                        }
                    }
                    HStack {
                        TextField(L.x("Nume profil (ex: „Grading — 2 monitoare”)", "Profile name (e.g. “Grading — 2 monitors”)", "Nombre del perfil (p. ej. «Grading — 2 monitores»)"), text: $newProfileName)
                            .textFieldStyle(.roundedBorder)
                        Button(L.x("Salvează", "Save", "Guardar")) { save() }
                            .disabled(!isTrusted || selectedAppIndex == nil || newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(6)
            }

            GroupBox("Profile salvate") {
                if profiles.isEmpty {
                    Text(L.x("Niciun profil salvat încă.", "No profile saved yet.", "Aún no hay ningún perfil guardado.")).foregroundStyle(.secondary).padding(20)
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
                                Button(L.x("Restaurează", "Restore", "Restaurar")) { runGated { restore(profile) } }
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
        .sheet(isPresented: $showGate) { AccessGateSheet() }
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
        status = ok ? "✔ Profil „\(name)” salvat." : L.x("✘ Nu s-au putut citi ferestrele — aplicația are ferestre deschise?", "✘ Could not read the windows — does the app have open windows?", "✘ No se pudieron leer las ventanas; ¿la app tiene ventanas abiertas?")
        newProfileName = ""
        refresh()
    }

    private func restore(_ profile: WindowLayoutProfile) {
        guard let app = apps.first(where: { $0.bundleID == profile.appBundleID }) else {
            status = L.x("✘ Aplicația „\(profile.appBundleID)” nu rulează acum.", "✘ The app “\(profile.appBundleID)” is not running now.", "✘ La app «\(profile.appBundleID)» no se está ejecutando ahora.")
            return
        }
        let count = WindowLayoutService.restoreLayout(profile, pid: app.pid)
        status = L.x("✔ \(count) ferestre repoziționate din profilul „\(profile.name)”.", "✔ \(count) windows repositioned from profile “\(profile.name)”.", "✔ \(count) ventanas reposicionadas desde el perfil «\(profile.name)».")
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.allowsFeatures { action() } else { showGate = true }
    }
}
