import SwiftUI
import AppKit
import MacMasterControlProCore

/// Legătura dintre interfață și `AccessProviding` (ediția comunitară sau cea oficială). Măsoară „utilizarea activă”:
/// aplicația în prim-plan ȘI (interacțiune în ultimele 5 s SAU o operație lungă în curs). Aplicația lăsată deschisă, fără
/// interacțiune, nu consumă sesiunea de probă.
@MainActor
final class AccessCoordinator: ObservableObject {
    static let shared = AccessCoordinator()
    @Published private(set) var mode: AccessMode
    @Published private(set) var offers: [OfferSummary] = []
    private let provider: AccessProviding
    private var lastInteraction = Date.distantPast
    private var timer: Timer?
    private var monitor: Any?
    private var wasLocked = false

    var allowsFeatures: Bool { mode.allowsFeatures }
    var editionLabel: String { provider.isOfficialEdition ? L.x("Ediție oficială GDC","Official GDC edition","Edición oficial de GDC") : L.x("Ediție comunitară (cod sursă MIT)","Community edition (MIT source code)","Edición comunitaria (código fuente MIT)") }

    private init() {
        provider = AccessFactory.make()
        mode = provider.mode
        wasLocked = !mode.allowsFeatures
        // În Demo, aplicația pornește de la zero: fără setări și cache-uri păstrate.
        if !mode.isFull { DemoProfile.wipe() }
        provider.onChange = { [weak self] in DispatchQueue.main.async { self?.sync() } }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]) { [weak self] e in
            Task { @MainActor in self?.lastInteraction = Date() }
            return e
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
        Task { await provider.refresh(); sync() }
    }

    private var busy: Bool {
        DiskAnalyzerViewModel.shared.isIndexing || DiskAnalyzerViewModel.shared.isRescanning || DuplicateFinderViewModel.shared.isScanning
    }

    private func tick() {
        let active = NSApp.isActive && (Date().timeIntervalSince(lastInteraction) < 5 || busy)
        provider.tick(active: active)
        sync()
    }

    private func sync() {
        let m = provider.mode
        if m != mode { mode = m }
        offers = provider.offers
        let locked = !m.allowsFeatures
        if wasLocked && !locked && !m.isFull { DemoProfile.wipe() }     // sesiune nouă după cooldown: de la zero
        if !wasLocked && locked { DemoProfile.wipe() }                  // sesiunea s-a încheiat: nu rămân setări/cache
        wasLocked = locked
    }

    func activationRequestText() -> String { provider.activationRequestText() }
    func submitLicense(_ text: String) async -> String? { let r = await provider.submitLicense(text); sync(); return r }
}

/// Panou de acces: stare, oferte (dacă ediția le are), cerere de licență, câmp pentru licență.
struct AccessPanel: View {
    @ObservedObject var access = AccessCoordinator.shared
    @State private var license = ""
    @State private var message: String?
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch access.mode {
            case .demoLocked(let next):
                Label(L.x("Sesiunea de probă s-a încheiat", "The trial session has ended", "La sesión de prueba ha terminado"), systemImage: "hourglass").font(.title2.bold())
                Text(String(format: L.x("Proba durează 10 minute de utilizare activă. Următoarea sesiune este disponibilă pe %@. Setările tale nu se șterg: în probă nu se modifică nimic din configurația ta.","The trial lasts 10 minutes of active use. The next session is available on %@. Your settings are not erased: the trial never changes your configuration.","La prueba dura 10 minutos de uso activo. La próxima sesión estará disponible el %@. Tus ajustes no se borran: la prueba nunca modifica tu configuración."), Self.fmt.string(from: next)))
                    .foregroundStyle(Studio.textMuted)
            case .demoAvailable(let s):
                Label(String(format: L.x("Sesiune de probă: %d:%02d rămase","Trial session: %d:%02d left","Sesión de prueba: %d:%02d restantes"), s / 60, s % 60), systemImage: "timer").font(.title3.bold())
            case .full(let src):
                Label(String(format: L.x("Acces complet (%@)","Full access (%@)","Acceso completo (%@)"), src), systemImage: "checkmark.seal").font(.title3.bold())
            }
            if !access.offers.isEmpty {
                Text(L.x("Susține proiectul printr-o donație și primești licență:", "Support the project with a donation and receive a licence:", "Apoya el proyecto con una donación y recibe una licencia:")).fontWeight(.semibold)
                ForEach(access.offers) { o in
                    HStack { Text(o.title); Spacer(); Text(o.amountText).fontWeight(.semibold) }
                        .padding(10).background(Studio.card, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Studio.line))
                }
            }
            if !access.mode.isFull {
                WrapLayout(spacing: 8) {
                    Button { NSWorkspace.shared.open(WhatsAppLink.url(text: access.activationRequestText())) } label: { Label(L.x("Cere o licență", "Request a licence", "Solicitar una licencia"), systemImage: "message") }
                        .buttonStyle(.borderedProminent).tint(Studio.accent)
                    Button(L.x("Deschide pagina produsului", "Open the product page", "Abrir la página del producto")) { NSWorkspace.shared.open(URL(string: "https://gordas.dev/mac-master-control-pro/")!) }
                    Button(L.x("Copiază Machine ID", "Copy Machine ID", "Copiar Machine ID")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(DemoHooks.machineID ?? MachineID.display, forType: .string) }
                    Button(L.x("Copiază cererea", "Copy request", "Copiar solicitud")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(access.activationRequestText(), forType: .string) }
                }
                HStack {
                    TextField(L.x("Lipește licența primită", "Paste the licence you received", "Pega la licencia recibida"), text: $license).textFieldStyle(.roundedBorder)
                    Button(L.x("Aplică", "Apply", "Aplicar")) { Task { message = await access.submitLicense(license) ?? L.x("Licență aplicată.", "Licence applied.", "Licencia aplicada.") } }.disabled(license.isEmpty)
                }
                if let m = message { Text(m).font(.callout).foregroundStyle(Studio.textMuted) }
                Text(access.editionLabel).font(.caption).foregroundStyle(Studio.textMuted)
            }
        }
        .padding(compact ? 0 : 28)
        .frame(maxWidth: 560, alignment: .leading)
    }

    static var fmt: DateFormatter { let f = DateFormatter(); f.dateFormat = "d MMMM yyyy, HH:mm"; f.locale = L.locale; return f }
}

struct AccessLockedOverlay: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial).ignoresSafeArea()
            AccessPanel().background(Studio.canvasTop, in: RoundedRectangle(cornerRadius: 18)).shadow(color: .black.opacity(0.2), radius: 30, y: 10)
        }
    }
}

struct AccessGateSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { VStack(alignment: .trailing) { AccessPanel(); Button(L.x("Închide", "Close", "Cerrar")) { dismiss() }.padding([.horizontal, .bottom], 28) } }
}

struct AccessStatusPill: View {
    @ObservedObject var access = AccessCoordinator.shared
    var body: some View {
        HStack(spacing: 6) {
            switch access.mode {
            case .full: Image(systemName: "checkmark.seal.fill").foregroundStyle(Studio.good); Text(L.x("Acces complet", "Full access", "Acceso completo"))
            case .demoAvailable(let s): Image(systemName: "timer"); Text(String(format: L.x("Probă: %d:%02d","Trial: %d:%02d","Prueba: %d:%02d"), s / 60, s % 60))
            case .demoLocked: Image(systemName: "hourglass"); Text(L.x("Probă încheiată", "Trial ended", "Prueba finalizada"))
            }
            Spacer()
        }
        .font(.caption).foregroundStyle(Studio.textMuted).padding(.horizontal, 12).padding(.vertical, 6)
    }
}
