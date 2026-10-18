import SwiftUI
import AppKit
import MacMasterControlProCore

/// Unelte DaVinci Resolve (2026-08-31, Nivel 2 #6 + #7) - EXCLUSIV prin
/// Scripting API-ul oficial, niciodată scriere directă în baza de date
/// internă a proiectelor (vezi comentariul din ResolveMediaAuditService).
struct ResolveToolsView: View {
    @ObservedObject private var license = AccessCoordinator.shared
    @State private var showGate = false

    @State private var isScanning = false
    @State private var scanError: String?
    @State private var lastResult: ResolveMediaAuditResult?
    @State private var selectedForDeletion: Set<String> = []
    @State private var logLines: [String] = []

    @StateObject private var notifier = RenderNotificationService()

    @StateObject private var cloud = CloudManagerService.shared
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

            GroupBox(L.x("Notificare la final de randare", "Notification when a render finishes", "Aviso al terminar un render")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.x("Primești o notificare macOS nativă când o randare din coada Resolve se termină (Terminat/Eșuat/Anulat) — util când randarea durează ore.", "You get a native macOS notification when a render in the Resolve queue ends (Finished/Failed/Cancelled) — handy when a render takes hours.", "Recibes una notificación nativa de macOS cuando termina un render de la cola de Resolve (Terminado/Fallido/Cancelado); útil cuando el render dura horas."))
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Circle().fill(notifier.isWatching ? Color.green : Color.secondary.opacity(0.3)).frame(width: 10, height: 10)
                        Text(notifier.isWatching ? L.x("Activă — verifică la 5 secunde", "Active — checks every 5 seconds", "Activo: comprueba cada 5 segundos") : L.x("Inactivă", "Inactive", "Inactivo"))
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
                    Toggle(L.x("Trimite și pe email (ajunge pe telefon)", "Also send by email (reaches your phone)", "Enviar también por correo (llega al teléfono)"), isOn: $emailSettings.enabled)
                        .onChange(of: emailSettings.enabled) { _, _ in EmailNotifierService.settings = emailSettings }
                    if emailSettings.enabled {
                        HStack(spacing: 8) {
                            Text(L.x("Recomandat: folosește o „parolă de aplicație” (App Password) Gmail/Outlook, NU parola reală a contului — se salvează local, în clar, pe acest Mac.", "Recommended: use a Gmail/Outlook “app password”, NOT your real account password — it is stored in the macOS Keychain on this Mac.", "Recomendado: usa una «contraseña de aplicación» de Gmail/Outlook, NO la contraseña real de tu cuenta; se guarda en el llavero de macOS de este Mac."))
                                .font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Button(L.x("Generează parolă Gmail", "Generate Gmail password", "Generar contraseña de Gmail")) {
                                NSWorkspace.shared.open(URL(string: "https://myaccount.google.com/apppasswords")!)
                            }
                            .controlSize(.small)
                            Button(L.x("Generează parolă Outlook", "Generate Outlook password", "Generar contraseña de Outlook")) {
                                NSWorkspace.shared.open(URL(string: "https://account.live.com/proofs/AppPassword")!)
                            }
                            .controlSize(.small)
                        }
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
                                Text(L.x("Parolă aplicație", "App password", "Contraseña de aplicación")).font(.caption)
                                SecureField("••••••••••••••••", text: $emailSettings.appPassword)
                            }
                            GridRow {
                                Text("Destinatar").font(.caption)
                                TextField("telefonul-tau@gmail.com", text: $emailSettings.recipient)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        HStack {
                            Button(L.x("Salvează", "Save", "Guardar")) { EmailNotifierService.settings = emailSettings }
                            Button(isSendingTest ? L.x("Se trimite…", "Sending…", "Enviando…") : L.x("Trimite email de test", "Send test email", "Enviar correo de prueba")) { sendTestEmail() }
                                .disabled(isSendingTest)
                        }
                        if let emailTestStatus {
                            StatusBanner(text: emailTestStatus)
                        }
                    }
                }
                .padding(6)
            }

            GroupBox("Auditor Media Pool — media offline & clipuri duplicate") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.x("Citește proiectul curent deschis în Resolve (doar citire) și semnalează clipuri ale căror fișiere sursă nu mai există pe disc, sau apar de mai multe ori în Media Pool.", "Reads the project currently open in Resolve (read-only) and flags clips whose source files no longer exist on disk, or that appear more than once in the Media Pool.", "Lee el proyecto abierto en Resolve (solo lectura) y señala clips cuyos archivos de origen ya no existen en el disco o que aparecen varias veces en el Media Pool."))
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(isScanning ? L.x("Se scanează…", "Scanning…", "Analizando…") : L.x("Scanează proiectul curent", "Scan current project", "Analizar el proyecto actual")) { scan() }
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

                        Button(L.x("Șterge selecția din Media Pool (\(selectedForDeletion.count))", "Delete selection from Media Pool (\(selectedForDeletion.count))", "Eliminar la selección del Media Pool (\(selectedForDeletion.count))")) {
                            runGated { deleteSelected() }
                        }
                        .disabled(selectedForDeletion.isEmpty)
                        .tint(.red)
                    }
                }
                .padding(6)
            }

            GroupBox(L.x("Sincronizare LUT-uri & Fusion între stații", "LUT & Fusion sync between workstations", "Sincronización de LUT y Fusion entre equipos")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.x("Urcă/descarcă LUT-urile și macro-urile/șabloanele Fusion printr-un cont Cloud deja configurat (Cloud Manager) — util pentru mai multe stații de lucru cu aceleași preferințe. PowerGrade-urile NU sunt incluse aici (trăiesc în baza de date internă a proiectelor, nu ca fișiere) — TODO separat.", "Upload/download LUTs and Fusion macros/templates through an already configured cloud account (Cloud Manager) — useful for several workstations with the same preferences. PowerGrades are NOT included (they live in the projects’ internal database, not as files).", "Sube/descarga LUT y macros/plantillas de Fusion mediante una cuenta en la nube ya configurada (Cloud Manager); útil para varios equipos con las mismas preferencias. Los PowerGrade NO se incluyen (viven en la base de datos interna de los proyectos, no como archivos)."))
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
                        Text(L.x("Niciun cont Cloud configurat — adaugă unul din „Cloud Manager”.", "No cloud account configured — add one from “Cloud Manager”.", "No hay ninguna cuenta en la nube configurada; añade una desde «Cloud Manager»."))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Picker("Cont Cloud", selection: $selectedRemote) {
                            ForEach(cloud.remotes) { remote in Text(remote.name).tag(remote.name) }
                        }
                        Picker(L.x("Direcție", "Direction", "Dirección"), selection: $syncDirection) {
                            Text(L.x("Urcă în Cloud", "Upload to cloud", "Subir a la nube")).tag(SyncDirection.upload)
                            Text(L.x("Descarcă din Cloud", "Download from cloud", "Descargar de la nube")).tag(SyncDirection.download)
                        }
                        .pickerStyle(.segmented)
                        Button(isSyncing ? L.x("Se sincronizează…", "Syncing…", "Sincronizando…") : L.x("Sincronizează", "Sync", "Sincronizar")) {
                            runGated { syncConfig() }
                        }
                        .disabled(selectedRemote.isEmpty || isSyncing)
                    }
                }
                .padding(6)
            }

            GroupBox(L.x("Backup bază de date proiecte", "Project database backup", "Copia de la base de datos de proyectos")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle().fill(ResolveDatabaseBackupService.databaseExists() ? Color.green : Color.red).frame(width: 8, height: 8)
                        Text(ResolveDatabaseBackupService.databaseExists()
                             ? L.x("Bază de date găsită — \(ByteCountFormatter.string(fromByteCount: dbSizeBytes, countStyle: .file))", "Database found — \(ByteCountFormatter.string(fromByteCount: dbSizeBytes, countStyle: .file))", "Base de datos encontrada: \(ByteCountFormatter.string(fromByteCount: dbSizeBytes, countStyle: .file))")
                             : L.x("Nicio bază de date locală găsită pe acest Mac", "No local database found on this Mac", "No se encontró ninguna base de datos local en este Mac"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(L.x("Închide Resolve înainte de backup — o copiere „la cald” poate corupe arhiva.", "Quit Resolve before backing up — a “hot” copy can corrupt the archive.", "Cierra Resolve antes de la copia: una copia «en caliente» puede dañar el archivo."))
                        .font(.caption2).foregroundStyle(.orange)
                    HStack {
                        if isBackingUp { ProgressView().controlSize(.small) }
                        Button("Backup acum") { runGated { performBackup() } }
                            .disabled(isBackingUp || !ResolveDatabaseBackupService.databaseExists())
                    }
                    if let backupStatus {
                        StatusBanner(text: backupStatus)
                    }
                    if !backups.isEmpty {
                        Divider()
                        Text("Backup-uri existente").font(.caption).bold()
                        ForEach(backups.prefix(5)) { entry in
                            HStack {
                                Text(entry.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: entry.sizeBytes, countStyle: .file)).font(.caption2).foregroundStyle(.secondary)
                                Button(L.x("Arată în Finder", "Show in Finder", "Mostrar en el Finder")) { ResolveDatabaseBackupService.revealInFinder(entry.path) }
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
                         ? L.x("Proces DaVinci Resolve activ, dar fără fereastră vizibilă — probabil blocat.", "DaVinci Resolve process is running but has no visible window — probably stuck.", "Proceso de DaVinci Resolve activo pero sin ventana visible; probablemente bloqueado.")
                         : L.x("Fără proces Resolve blocat detectat.", "No stuck Resolve process detected.", "No se detectó ningún proceso de Resolve bloqueado."))
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if isResolveZombie {
                        Button(L.x("Închide forțat", "Force quit", "Forzar cierre"), role: .destructive) {
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
        .sheet(isPresented: $showGate) { AccessGateSheet() }
    }

    private func syncConfig() {
        isSyncing = true
        let existingFolders = ResolveConfigSyncService.folders.filter { $0.exists }
        guard !existingFolders.isEmpty else {
            logLines.append(L.x("ℹ Niciun folder de configurare Resolve găsit local.", "ℹ No Resolve configuration folder found locally.", "ℹ No se encontró ninguna carpeta de configuración de Resolve."))
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
        logLines.append(L.x("$ Ștergere \(paths.count) clip(uri) din Media Pool…", "$ Deleting \(paths.count) clip(s) from the Media Pool…", "$ Eliminando \(paths.count) clip(s) del Media Pool…"))
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ResolveMediaAuditService.deleteClips(filePaths: paths)
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    logLines.append(L.x("✔ \(count) clip(uri) șterse din Media Pool.", "✔ \(count) clip(s) removed from the Media Pool.", "✔ \(count) clip(s) eliminados del Media Pool."))
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
            let result = EmailNotifierService.send(subject: "Test — Master Control Studio Pro", body: L.x("Dacă vezi acest email, notificarea funcționează.", "If you see this email, the notification works.", "Si ves este correo, la notificación funciona."))
            DispatchQueue.main.async {
                isSendingTest = false
                emailTestStatus = result.ok ? L.x("✔ Trimis — verifică inboxul.", "✔ Sent — check your inbox.", "✔ Enviado: revisa tu bandeja de entrada.") : "✘ \(result.error ?? "Eroare necunoscută")"
            }
        }
    }

    private func describe(_ error: ResolveMediaAuditError) -> String {
        switch error {
        case .resolveNotRunning: return L.x("DaVinci Resolve nu rulează sau scripting-ul nu e activat (Preferences → General → External scripting using = Local).", "DaVinci Resolve is not running or scripting is not enabled (Preferences → General → External scripting using = Local).", "DaVinci Resolve no se está ejecutando o el scripting no está activado (Preferences → General → External scripting using = Local).")
        case .noProjectOpen: return L.x("Niciun proiect deschis în Resolve.", "No project open in Resolve.", "No hay ningún proyecto abierto en Resolve.")
        case .scriptingUnavailable: return L.x("Scripting API Resolve indisponibil (python3/modulele nu au fost găsite).", "Resolve scripting API unavailable (python3/modules not found).", "API de scripting de Resolve no disponible (no se encontraron python3 ni los módulos).")
        case .scriptFailed(let message): return message
        }
    }

    private func runGated(_ action: @escaping () -> Void) {
        if license.allowsFeatures { action() } else { showGate = true }
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
