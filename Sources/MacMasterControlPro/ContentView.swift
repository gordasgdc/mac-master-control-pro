import SwiftUI
import AppKit
import MacMasterControlProCore

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard, renderMode, loginItems, processMonitor, diskHealth, diskAnalyzer, resolveTools, windowLayouts, network, cloud, cleanup, duplicates, uninstaller, security, tweaks, rosetta, dependencies, settings
    var id: String { rawValue }
    var labelKey: String {
        switch self {
        case .dashboard: return "sidebar.dashboard"
        case .renderMode: return "sidebar.renderMode"
        case .loginItems: return "sidebar.loginItems"
        case .processMonitor: return "sidebar.processMonitor"
        case .diskHealth: return "sidebar.diskHealth"
        case .diskAnalyzer: return "sidebar.diskAnalyzer"
        case .resolveTools: return "sidebar.resolveTools"
        case .windowLayouts: return "sidebar.windowLayouts"
        case .network: return "sidebar.network"
        case .cloud: return "sidebar.cloud"
        case .cleanup: return "sidebar.cleanup"
        case .duplicates: return "sidebar.duplicates"
        case .uninstaller: return "sidebar.uninstaller"
        case .security: return "sidebar.security"
        case .tweaks: return "sidebar.tweaks"
        case .rosetta: return "sidebar.rosetta"
        case .dependencies: return "sidebar.dependencies"
        case .settings: return "sidebar.settings"
        }
    }
    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .renderMode: return "bolt.circle"
        case .loginItems: return "power.circle"
        case .processMonitor: return "speedometer"
        case .diskHealth: return "internaldrive"
        case .diskAnalyzer: return "chart.pie"
        case .resolveTools: return "film"
        case .windowLayouts: return "macwindow.on.rectangle"
        case .network: return "network"
        case .cloud: return "cloud"
        case .cleanup: return "trash.circle"
        case .duplicates: return "doc.on.doc"
        case .uninstaller: return "trash.slash"
        case .security: return "checkmark.shield"
        case .tweaks: return "wrench.and.screwdriver"
        case .rosetta: return "cpu"
        case .dependencies: return "puzzlepiece.extension"
        case .settings: return "gearshape"
        }
    }

    /// Descriere scurtă, afișată la hover pe rândul din sidebar — cerință
    /// directă (2026-09-01): "cand te duci cu mouse-ul peste un buton,
    /// sa-ti apara o descriere de ce face".
    var tooltip: String {
        switch self {
        case .dashboard: return L.x("Privire de ansamblu — starea generală a Mac-ului dintr-o privire.", "Overview — the general state of your Mac at a glance.", "Resumen: el estado general del Mac de un vistazo.")
        case .renderMode: return L.x("Oprește temporar Spotlight/Time Machine/alte procese de fundal cât randezi în DaVinci Resolve.", "Temporarily pauses Spotlight/Time Machine/other background processes while you render in DaVinci Resolve.", "Pausa temporalmente Spotlight/Time Machine y otros procesos en segundo plano mientras renderizas en DaVinci Resolve.")
        case .loginItems: return L.x("Vezi și oprești aplicațiile care pornesc automat odată cu Mac-ul.", "See and stop apps that start automatically with your Mac.", "Consulta y detén las apps que se inician con el Mac.")
        case .processMonitor: return L.x("Procesele active acum, sortabile după CPU sau RAM — închide ce consumă prea mult.", "Running processes, sortable by CPU or RAM — close what uses too much.", "Procesos activos, ordenables por CPU o RAM: cierra lo que consume demasiado.")
        case .diskHealth: return L.x("Spațiu liber, status SMART și test de viteză pentru discurile montate.", "Free space, SMART status and speed test for mounted drives.", "Espacio libre, estado SMART y prueba de velocidad de las unidades montadas.")
        case .diskAnalyzer: return L.x("Vezi ce ocupă spațiul pe disc, folder cu folder, ca în DaisyDisk.", "See what uses disk space, folder by folder, as in DaisyDisk.", "Mira qué ocupa espacio en el disco, carpeta por carpeta, como en DaisyDisk.")
        case .resolveTools: return L.x("Notificare la final de randare, verificare Media Pool, sincronizare LUT-uri, backup bază de date.", "Render-finished notification, Media Pool check, LUT sync, database backup.", "Aviso al terminar el render, revisión del Media Pool, sincronización de LUT y copia de la base de datos.")
        case .windowLayouts: return L.x("Salvează și restaurează aranjamentul ferestrelor pe ecran.", "Save and restore your window arrangement.", "Guarda y restaura la disposición de las ventanas.")
        case .network: return L.x("Configurare și optimizare rețea, persistentă la repornire.", "Network setup and tuning that persists across restarts.", "Configuración y optimización de red que persiste tras reiniciar.")
        case .cloud: return L.x("Conectează și gestionează conturi Cloud (Drive, Dropbox, S3 și altele).", "Connect and manage cloud accounts (Drive, Dropbox, S3 and more).", "Conecta y gestiona cuentas en la nube (Drive, Dropbox, S3 y más).")
        case .cleanup: return L.x("Șterge cache-uri recuperabile, fișiere mari uitate, eliberează RAM.", "Clear recoverable caches and forgotten large files, free RAM.", "Elimina cachés recuperables y archivos grandes olvidados, libera RAM.")
        case .duplicates: return L.x("Găsește fișiere identice ca și conținut și te lasă să alegi ce ștergi.", "Find files with identical content and choose what to remove.", "Encuentra archivos con contenido idéntico y elige qué eliminar.")
        case .uninstaller: return L.x("Dezinstalează complet una sau mai multe aplicații, cu toate urmele lor.", "Fully uninstall one or more apps, leftovers included.", "Desinstala por completo una o varias apps, con todos sus restos.")
        case .security: return L.x("Verifică setările de securitate ale Mac-ului, cu ghid pas-cu-pas pentru ce lipsește.", "Check your Mac’s security settings, with step-by-step guidance for what is missing.", "Revisa los ajustes de seguridad del Mac, con una guía paso a paso de lo que falta.")
        case .tweaks: return L.x("Ajustări rapide de sistem și accesibilitate.", "Quick system and accessibility tweaks.", "Ajustes rápidos del sistema y de accesibilidad.")
        case .rosetta: return L.x("Verifică ce aplicații rulează prin Rosetta (emulare Intel) pe un Mac Apple Silicon.", "Check which apps run through Rosetta (Intel emulation) on an Apple silicon Mac.", "Comprueba qué apps se ejecutan con Rosetta (emulación Intel) en un Mac con Apple silicon.")
        case .dependencies: return L.x("Componentele externe de care aplicația are nevoie — instalare cu un click.", "External components the app needs — one-click install.", "Componentes externos que necesita la app: instalación con un clic.")
        case .settings: return L.x("Temă, limbă, licență și alte preferințe ale aplicației.", "Theme, language, licence and other app preferences.", "Tema, idioma, licencia y otras preferencias de la app.")
        }
    }

    /// Cuvinte-cheie suplimentare de căutare, dincolo de nume/descriere —
    /// cerință directă (Cristi, 2026-09-01): "sa pot cauta ... reglare,
    /// duplicate, dezinstalare ... prin toata aplicatia". Sinonime uzuale
    /// care altfel n-ar da match pe numele oficial al modulului.
    var searchKeywords: String {
        switch self {
        case .tweaks: return "reglare setari sistem accesibilitate"
        case .uninstaller: return "dezinstalare sterge aplicatii dezinstalare"
        case .duplicates: return "duplicate copii identice fisiere"
        case .cleanup: return "curatare ram cache fisiere mari"
        case .diskHealth: return "disc viteza smart"
        case .diskAnalyzer: return "disc analiza spatiu foldere mari daisydisk"
        case .security: return "securitate filevault sip gatekeeper firewall"
        case .cloud: return "cloud drive dropbox onedrive rclone"
        case .network: return "retea wifi dns"
        case .resolveTools: return "davinci resolve randare email"
        case .processMonitor: return "procese cpu ram inchide"
        default: return ""
        }
    }
}

/// Grupuri de navigare: toate modulele rămân accesibile, grupate după ce vrea utilizatorul să facă.
enum SidebarGroup: CaseIterable {
    case home, space, system, media, app
    var title: String {
        switch self {
        case .home: return L.x("Acasă", "Home", "Inicio")
        case .space: return L.x("Spațiu", "Space", "Espacio")
        case .system: return L.x("Sistem și activitate", "System and activity", "Sistema y actividad")
        case .media: return L.x("Media și Resolve", "Media and Resolve", "Media y Resolve")
        case .app: return L.x("Aplicație", "App", "Aplicación")
        }
    }
    var items: [SidebarItem] {
        switch self {
        case .home: return [.dashboard]
        case .space: return [.diskAnalyzer, .cleanup, .duplicates, .uninstaller]
        case .system: return [.processMonitor, .loginItems, .diskHealth, .renderMode, .network, .security, .tweaks, .rosetta, .windowLayouts]
        case .media: return [.resolveTools, .cloud]
        case .app: return [.dependencies, .settings]
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem? = .dashboard
    @ObservedObject private var language = LanguageStore.shared
    @ObservedObject private var access = AccessCoordinator.shared
    @StateObject private var dependencyChecker = DependencyChecker()
    @State private var searchText = ""

    /// Cerință directă (Cristi, 2026-09-01): "un cautator ... sa pot cauta
    /// prin toata aplicatia" — filtrare simplă pe nume + descriere +
    /// sinonime, diacritice ignorate (userul scrie fără diacritice des).
    private var filteredItems: [SidebarItem] {
        guard !searchText.isEmpty else { return SidebarItem.allCases }
        let query = searchText.folding(options: .diacriticInsensitive, locale: nil).lowercased()
        return SidebarItem.allCases.filter { item in
            let haystack = [L.t(item.labelKey), item.tooltip, item.searchKeywords]
                .joined(separator: " ")
                .folding(options: .diacriticInsensitive, locale: nil)
                .lowercased()
            return haystack.contains(query)
        }
    }

    var body: some View {
        NavigationSplitView {
            // Frati intr-un VStack, NICIODATA .safeAreaInset direct pe List
            // (Regula 24 — bug de suprapunere la resize rapid al ferestrei).
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(L.x("Caută (ex: duplicate, dezinstalare, reglare)…","Search (e.g. duplicates, uninstall, tweaks)…","Buscar (p. ej. duplicados, desinstalar, ajustes)…"), text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.15)))
                .padding(.horizontal, 10)
                .padding(.top, 8)

                if filteredItems.isEmpty {
                    Text("Niciun rezultat.").font(.caption).foregroundStyle(.secondary).padding()
                }
                List(selection: $selection) {
                    ForEach(SidebarGroup.allCases, id: \.self) { group in
                        let items = group.items.filter { filteredItems.contains($0) }
                        if !items.isEmpty {
                            Section(group.title) {
                                ForEach(items) { item in
                                    HStack {
                                        Label(L.t(item.labelKey), systemImage: item.icon)
                                        if item == .dependencies, !dependencyChecker.allInstalled, !dependencyChecker.items.isEmpty {
                                            Spacer()
                                            Circle().fill(Color.red).frame(width: 8, height: 8)
                                        }
                                    }
                                    .tag(item)
                                    .help(item.tooltip)
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                AccessStatusPill()
                SidebarFooterView()
            }
            .navigationSplitViewColumnWidth(min: 215, ideal: 240, max: 320)
            .navigationTitle("Master Control Studio Pro")
        } detail: {
            switch selection {
            case .renderMode: RenderModeView()
            case .loginItems: LoginItemsView()
            case .processMonitor: ProcessMonitorView()
            case .diskHealth: DiskHealthView()
            case .diskAnalyzer: DiskAnalyzerView()
            case .resolveTools: ResolveToolsView()
            case .windowLayouts: WindowLayoutsView()
            case .network: NetworkModuleView()
            case .cloud: CloudManagerView()
            case .cleanup: CleanupModuleView()
            case .duplicates: DuplicateFinderView()
            case .uninstaller: UninstallerModuleView()
            case .security: SecurityModuleView()
            case .tweaks: TweaksModuleView()
            case .rosetta: RosettaModuleView()
            case .dependencies: DependenciesModuleView(checker: dependencyChecker)
            case .settings: SettingsView()
            default: HomeView(checker: dependencyChecker, navigate: { selection = $0 })
            }
        }
        .overlay { if !access.allowsFeatures { AccessLockedOverlay() } }
        .id(language.current) // forteaza refresh la schimbarea limbii
        .frame(minWidth: 900, minHeight: 600)
        .onReceive(NotificationCenter.default.publisher(for: .mmcpOpenSettings)) { _ in
            selection = .settings
        }
        .onAppear {
            dependencyChecker.checkAll()
            UpdateChecker.checkSilentlyOnLaunch { version, pkgURL in
                let alert = NSAlert()
                alert.messageText = L.x("Este disponibilă o versiune nouă", "A new version is available", "Hay una versión nueva disponible")
                alert.informativeText = L.x("Master Control Studio Pro \(version) este disponibil (tu ai \(UpdateChecker.currentVersion)).", "Master Control Studio Pro \(version) is available (you have \(UpdateChecker.currentVersion)).", "Master Control Studio Pro \(version) está disponible (tienes \(UpdateChecker.currentVersion)).")
                alert.addButton(withTitle: L.x("Actualizează acum", "Update now", "Actualizar ahora"))
                alert.addButton(withTitle: L.x("Mai târziu", "Later", "Más tarde"))
                let response = alert.runModal()
                UpdateChecker.markDismissed(version)
                if response == .alertFirstButtonReturn {
                    Task { await SelfUpdater.downloadAndInstall(pkgURL: pkgURL, version: version) }
                }
            }
        }
    }
}

/// Un modul + starea lui reala (verde/rosu), fara sa intri in el —
/// cerinta directa (2026-08-31): "sa apara verde/rosu la orice tip de
/// configurare, direct pe dashboard".
struct SettingsView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var textScale = TextScaleManager.shared
    @ObservedObject private var profile = UserProfileStore.shared
    @ObservedObject private var language = LanguageStore.shared
    @State private var confirmUninstall = false
    @State private var showDiagnostic = false
    @State private var confirmReset = false
    @State private var resetMessage: String?

    var body: some View {
        Form {
            Section(L.t("settings.appearance")) {
                Picker(L.t("settings.theme"), selection: $theme.current) {
                    ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker(L.t("settings.textSize"), selection: $textScale.current) {
                    ForEach(TextScalePreference.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker(L.t("settings.language"), selection: $language.current) {
                    ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section(L.t("settings.profile")) {
                TextField(L.t("settings.name"), text: $profile.name)
                TextField(L.t("settings.email"), text: $profile.email)
            }

            Section("Diagnostic") {
                Text(String(format: L.x("Sesiune: %@","Session: %@","Sesión: %@"), DiagnosticLog.sessionID)).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                HStack {
                    Button(L.x("Deschide folderul de loguri", L.x("Open logs folder", L.x("Open logs folder", "Open logs folder", "Abrir la carpeta de registros"), "Abrir la carpeta de registros"), "Abrir carpeta de registros")) {
                        try? FileManager.default.createDirectory(at: DiagnosticLog.directory, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(DiagnosticLog.directory)
                    }
                    Button(L.x("Copiază ID-ul sesiunii", "Copy session ID", "Copiar ID de sesión")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(DiagnosticLog.sessionID, forType: .string)
                    }
                    Button(L.x("Exportă diagnosticul...", "Export diagnostics…", "Exportar diagnóstico…")) { showDiagnostic = true }
                }
                Text(L.x("Pachetul se creează local, redactat; nu se trimite nimic automat.", "The package is created locally and redacted; nothing is sent automatically.", "El paquete se crea localmente y redactado; no se envía nada automáticamente.")).font(.caption).foregroundStyle(.secondary)
            }

            Section(L.x("Configurație", "Configuration", "Configuración")) {
                Text(L.x("Setările, folderele alese și cache-urile aplicației. Resetarea este o acțiune separată: nu se întâmplă automat la expirarea probei și face mai întâi o copie de siguranță.", "The app’s settings, chosen folders and caches. Resetting is a separate action: it never happens automatically when the trial ends and it makes a backup first.", "Los ajustes, carpetas elegidas y cachés de la app. Restablecer es una acción aparte: nunca ocurre automáticamente al terminar la prueba y antes hace una copia de seguridad."))
                    .font(.caption).foregroundStyle(.secondary)
                Button(L.x("Resetează configurația aplicației…", "Reset app configuration…", "Restablecer la configuración de la app…"), role: .destructive) { confirmReset = true }
                if let resetMessage { Text(resetMessage).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
            }

            Section("Dezinstalare") {
                Button(L.x("Dezinstalează complet aplicația...", "Uninstall the app completely…", "Desinstalar la app por completo…"), role: .destructive) {
                    confirmUninstall = true
                }
            }
        }
        .padding(32)
        .sheet(isPresented: $showDiagnostic) { DiagnosticExportSheet() }
        .alert(L.x("Resetezi configurația aplicației?", "Reset the app configuration?", "¿Restablecer la configuración de la app?"), isPresented: $confirmReset) {
            Button(L.x("Anulează", "Cancel", "Cancelar"), role: .cancel) {}
            Button(L.x("Fă copie și resetează", "Back up and reset", "Copiar y restablecer"), role: .destructive) {
                do { let b = try AppProfile.resetUserConfiguration(); resetMessage = String(format: L.x("Copie de siguranță: %@","Backup: %@",L.x("Copia de seguridad: %@", "Safety copy: %@", L.x("Copia de seguridad: %@", "Safety copy: %@", "Copia de seguridad: %@"))), b.path) }
                catch { resetMessage = String(format: L.x("Resetarea a eșuat: %@","Reset failed: %@","Falló el restablecimiento: %@"), error.localizedDescription) }
            }
        } message: { Text(AppProfile.resetPreview().joined(separator: "\n")) }
        .alert(L.x("Ești sigur că vrei să ștergi aplicația și toate datele/licențele locale?", "Are you sure you want to delete the app and all local data/licences?", "¿Seguro que quieres eliminar la app y todos los datos y licencias locales?"),
               isPresented: $confirmUninstall) {
            Button(L.x("Anulează", "Cancel", "Cancelar"), role: .cancel) {}
            Button(L.x("Dezinstalează", "Uninstall", "Desinstalar"), role: .destructive) {
                SelfUninstaller.removeUserData()
                SelfUninstaller.trashAppAndQuit()
            }
        } message: {
            Text(L.x("Se șterg datele, preferințele, cache-ul și jurnalele, apoi aplicația e mutată la Coș. Acțiunea nu poate fi anulată.", "Data, preferences, caches and logs are deleted, then the app is moved to the Trash. This cannot be undone.", "Se borran los datos, las preferencias, la caché y los registros, y la app pasa a la Papelera. No se puede deshacer."))
        }
    }
}
