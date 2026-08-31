import SwiftUI
import MacMasterControlProCore

/// Unelte DaVinci Resolve (2026-08-31, Nivel 2 #6 + #7) - EXCLUSIV prin
/// Scripting API-ul oficial, niciodată scriere directă în baza de date
/// internă a proiectelor (vezi comentariul din ResolveMediaAuditService).
struct ResolveToolsView: View {
    @ObservedObject private var license = LicenseStore.shared
    @State private var showGate = false

    @State private var isScanning = false
    @State private var scanError: String?
    @State private var lastResult: ResolveMediaAuditResult?
    @State private var selectedForDeletion: Set<String> = []
    @State private var logLines: [String] = []

    @StateObject private var notifier = RenderNotificationService()

    @StateObject private var cloud = CloudManagerService()
    @State private var selectedRemote: String = ""
    @State private var syncDirection: SyncDirection = .upload
    @State private var isSyncing = false

    @State private var emailSettings = EmailNotifierService.settings
    @State private var emailTestStatus: String?
    @State private var isSendingTest = false

    @State private var dbSizeBytes: Int64 = 0
    @State private var backups: [ResolveDatabaseBackupService.BackupEntry] = []
    @State private var backupStatus: String?
    @State private var isBackingUp = false
    @State private var isResolveZombie = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("🎬 DaVinci Resolve").font(.title2).bold()

            GroupBox("Notificare la final de randare") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Primești o notificare macOS nativă când o randare din coada Resolve se termină (Terminat/Eșuat/Anulat) — util când randarea durează ore.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Circle().fill(notifier.isWatching ? Color.green : Color.secondary.opacity(0.3)).frame(width: 10, height: 10)
                        Text(notifier.isWatching ? "Activă — verifică la 5 secunde" : "Inactivă")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { notifier.isWatching },
                            set: { newValue in
                                runGated { newValue ? notifier.start() : notifier.stop() }
                            }
                        )).toggleStyle(.switch).labelsHidden()
                    }
                    if let error = notifier.lastError {
                        Text("⚠ \(error)").font(.caption2).foregroundStyle(.orange)
                    }

                    Divider()
                    Toggle("Trimite și pe email (ajunge pe telefon)", isOn: $emailSettings.enabled)
                        .onChange(of: emailSettings.enabled) { _, _ in EmailNotifierService.settings = emailSettings }
                    if emailSettings.enabled {
                        Text("Recomandat: folosește o „parolă de aplicație” (App Password) Gmail/Outlook, NU parola reală a contului — se salvează local, în clar, pe acest Mac.")
                            .font(.caption2).foregroundStyle(.secondary)
                        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                            GridRow {
                                Text("Server SMTP").font(.caption)
                                TextField("smtp.gmail.com", text: $emailSettings.smtpHost)
                            }
                            GridRow {
                                Text("Port").font(.caption)
                                TextField("587", value: $emailSettings.smtpPort, format: .number)
                            }
                            GridRow {
                                Text("Email expeditor").font(.caption)
                                TextField("tu@gmail.com", text: $emailSettings.username)
                            }
                            GridRow {
                                Text("Parolă aplicație").font(.caption)
                                SecureField("••••••••••••••••", text: $emailSettings.appPassword)
                            }
                            GridRow {
                                Text("Destinatar").font(.caption)
                                TextField("telefonul-tau@gmail.com", text: $emailSettings.recipient)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        HStack {
                            Button("Salvează") { EmailNotifierService.settings = emailSettings }
                            Button(isSendingTest ? "Se trimite…" : "Trimite email de test") { sendTestEmail() }
                                .disabled(isSendingTest)
                        }
                        if let emailTestStatus {
                            Text(emailTestStatus).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(6)
            }

            GroupBox("Auditor Media Pool — media offline & clipuri duplicate") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Citește proiectul curent deschis în Resolve (doar citire) și semnalează clipuri ale căror fișiere sursă nu mai există pe disc, sau apar de mai multe ori în Media Pool.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(isScanning ? "Se scanează…" : "Scanează proiectul curent") { scan() }
                            .disabled(isScanning)
                        if let result = lastResult {
                            Text("„\(result.projectName)” — \(result.totalClips) clipuri, \(result.flags.count) semnalate")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let scanError {
                        Text("⚠ \(scanError)").font(.caption).foregroundStyle(.orange)
                    }

                    if let result = lastResult, !result.flags.isEmpty {
                        List(result.flags) { flag in
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { selectedForDeletion.contains(flag.filePath) },
                                    set: { checked in
                                        if checked { selectedForDeletion.insert(flag.filePath) }
                                        else { selectedForDeletion.remove(flag.filePath) }
                                    }
                                )) {
                                    VStack(alignment: .leading) {
                                        Text(flag.clipName).font(.system(.body, design: .monospaced))
                                        Text(flag.filePath).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                                Text(flag.reason.rawValue)
                                    .font(.caption2).foregroundStyle(flag.reason == .offline ? .red : .orange)
                            }
                        }
                        .frame(minHeight: 160, maxHeight: 260)

                        Button("Șterge selecția din Media Pool (\(selectedForDeletion.count))") {
                            runGated { deleteSelected() }
                        }
                        .disabled(selectedForDeletion.isEmpty)
                        .tint(.red)
                    }
                }
                .padding(6)
            }

            GroupBox("Sincronizare LUT-uri & Fusion între stații") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Urcă/descarcă LUT-urile și macro-urile/șabloanele Fusion printr-un cont Cloud deja configurat (Cloud Manager) — util pentru mai multe stații de lucru cu aceleași preferințe. PowerGrade-urile NU sunt incluse aici (trăiesc în baza de date internă a proiectelor, nu ca fișiere) — TODO separat.")
                        .font(.caption).foregroundStyle(.secondary)

                    ForEach(ResolveConfigSyncService.folders) { folder in
                        HStack {
                            Image(systemName: folder.exists ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(folder.exists ? .green : .secondary)
                            Text(folder.label).font(.caption)
                            Spacer()
                        }
                    }

                    if cloud.remotes.isEmpty {
                        Text("Niciun cont Cloud configurat — adaugă unul din „Cloud Manager”.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Picker("Cont Cloud", selection: $selectedRemote) {
                            ForEach(cloud.remotes) { remote in Text(remote.name).tag(remote.name) }
                        }
                        Picker("Direcție", selection: $syncDirection) {
                            Text("Urcă în Cloud").tag(SyncDirection.upload)
                            Text("Descarcă din Cloud").tag(SyncDirection.download)
                        }
                        .pickerStyle(.segmented)
                        Button(isSyncing ? "Se sincronizează…" : "Sincronizează") {
                            runGated { syncConfig() }
                        }
                        .disabled(selectedRemote.isEmpty || isSyncing)
                    }
                }
                .padding(6)
            }

            GroupBox("Backup bază de date proiecte") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle().fill(ResolveDatabaseBackupService.databaseExists() ? Color.green : Color.red).frame(width: 8, height: 8)
                        Text(ResolveDatabaseBackupService.databaseExists()
                             ? "Bază de date găsită — \(ByteCountFormatter.string(fromByteCount: dbSizeBytes, countStyle: .file))"
                             : "Nicio bază de date locală găsită pe acest Mac")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Închide Resolve înainte de backup — o copiere „la cald” poate corupe arhiva.")
                        .font(.caption2).foregroundStyle(.orange)
                    HStack {
                        if isBackingUp { ProgressView().controlSize(.small) }
                        Button("Backup acum") { runGated { performBackup() } }
                            .disabled(isBackingUp || !ResolveDatabaseBackupService.databaseExists())
                    }
                    if let backupStatus {
                        Text(backupStatus).font(.caption).foregroundStyle(backupStatus.hasPrefix("✔") ? .green : .red)
                    }
                    if !backups.isEmpty {
                        Divider()
                        Text("Backup-uri existente").font(.caption).bold()
                        ForEach(backups.prefix(5)) { entry in
                            HStack {
                                Text(entry.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: entry.sizeBytes, countStyle: .file)).font(.caption2).foregroundStyle(.secondary)
                                Button("Arată în Finder") { ResolveDatabaseBackupService.revealInFinder(entry.path) }
                                    .font(.caption2).buttonStyle(.plain).foregroundStyle(.blue)
                            }
                        }
                    }
                }
                .padding(6)
            }

            GroupBox("Resolve blocat (zombie)") {
                HStack {
                    Circle().fill(isResolveZombie ? Color.red : Color.green).frame(width: 8, height: 8)
                    Text(isResolveZombie
                         ? "Proces DaVinci Resolve activ, dar fără fereastră vizibilă — probabil blocat."
                         : "Fără proces Resolve blocat detectat.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if isResolveZombie {
                        Button("Închide forțat", role: .destructive) {
                            runGated { ResolveDatabaseBackupService.forceQuitResolve(); refreshResolveHealth() }
                        }
                    }
                }
                .padding(6)
            }

            if !logLines.isEmpty {
                TerminalLogView(lines: logLines)
            }
            Spacer()
        }
        .padding(24)
        .onAppear {
            cloud.refreshRemotes()
            if selectedRemote.isEmpty { selectedRemote = cloud.remotes.first?.name ?? "" }
            refreshResolveHealth()
            backups = ResolveDatabaseBackupService.listBackups()
        }
        .sheet(isPresented: $showGate) { TrialGateModal() }
    }

    private func syncConfig() {
        isSyncing = true
        let existingFolders = ResolveConfigSyncService.folders.filter { $0.exists }
        guard !existingFolders.isEmpty else {
            logLines.append("ℹ Niciun folder de configurare Resolve găsit local.")
            isSyncing = false
            return
        }
        let group = DispatchGroup()
        for folder in existingFolders {
            group.enter()
            let remotePath = "MacMasterControlPro-ResolveConfig/" + (folder.path as NSString).lastPathComponent
            cloud.syncFolder(localFolder: folder.path, remoteName: selectedRemote, remotePath: remotePath,
                              direction: syncDirection, mirror: false,
                              log: { logLines.append($0) },
                              completion: { _ in group.leave() })
        }
        group.notify(queue: .main) { isSyncing = false }
    }

    private func scan() {
        isScanning = true
        scanError = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ResolveMediaAuditService.scanCurrentProject()
            DispatchQueue.main.async {
                isScanning = false
                switch result {
                case .success(let value):
                    lastResult = value
                    selectedForDeletion = []
                case .failure(let error):
                    scanError = describe(error)
                    lastResult = nil
                }
            }
        }
    }

    private func deleteSelected() {
        let paths = Array(selectedForDeletion)
        logLines.append("$ Ștergere \(paths.count) clip(uri) din Media Pool…")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ResolveMediaAuditService.deleteClips(filePaths: paths)
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    logLines.append("✔ \(count) clip(uri) șterse din Media Pool.")
                    scan()
                case .failure(let error):
                    logLines.append("✘ \(describe(error))")
                }
            }
        }
    }

    private func sendTestEmail() {
        EmailNotifierService.settings = emailSettings
        isSendingTest = true
        emailTestStatus = nil
        DispatchQueue.global(qos: .utility).async {
            let result = EmailNotifierService.send(subject: "Test — Master Control Studio Pro", body: "Dacă vezi acest email, notificarea funcționează.")
            DispatchQueue.main.async {
                isSendingTest = false
                emailTestStatus = result.ok ? "✔ Trimis — verifică inboxul." : "✘ \(result.error ?? "Eroare necunoscută")"
            }
        }
    }

    private func describe(_ error: ResolveMediaAuditError) -> String {
        switch error {
        case .resolveNotRunning: return "DaVinci Resolve nu rulează sau scripting-ul nu e activat (Preferences → General → External scripting using = Local)."
        case .noProjectOpen: return "Niciun proiect deschis în Resolve."
        case .scriptingUnavailable: return "Scripting API Resolve indisponibil (python3/modulele nu au fost găsite)."
        case .scriptFailed(let message): return message
        }
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.isActivated { action() } else { showGate = true }
    }

    private func refreshResolveHealth() {
        dbSizeBytes = ResolveDatabaseBackupService.databaseSizeBytes()
        isResolveZombie = ResolveDatabaseBackupService.isResolveZombie()
    }

    private func performBackup() {
        isBackingUp = true
        backupStatus = nil
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = try ResolveDatabaseBackupService.createBackup()
                DispatchQueue.main.async {
                    backupStatus = "✔ Backup creat: \(url.lastPathComponent)"
                    backups = ResolveDatabaseBackupService.listBackups()
                    isBackingUp = false
                }
            } catch {
                DispatchQueue.main.async {
                    backupStatus = "✘ \(error.localizedDescription)"
                    isBackingUp = false
                }
            }
        }
    }
}
