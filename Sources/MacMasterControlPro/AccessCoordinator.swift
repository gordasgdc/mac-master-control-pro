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
    /// Oferta aleasă de utilizator (id + versiune din lista semnată). Niciodată aleasă implicit; dacă lista se schimbă și perechea nu mai e validă, se cere o nouă alegere.
    @Published private(set) var selectedOffer: OfferSummary?
    @Published private(set) var selectionNotice: String?
    private let provider: AccessProviding
    private var lastInteraction = Date.distantPast
    private var timer: Timer?
    private var monitor: Any?
    private var wasLocked = false

    var allowsFeatures: Bool { mode.allowsFeatures }
    var isOfficial: Bool { provider.isOfficialEdition }
    /// Ediția oficială cere o ofertă aleasă pentru a genera cererea; ediția comunitară nu are oferte.
    var canRequestLicense: Bool { !provider.isOfficialEdition || selectedOffer != nil }
    func select(_ offer: OfferSummary) { selectedOffer = offers.first { $0.id == offer.id && $0.version == offer.version }; selectionNotice = nil }
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
        offers = provider.offers.sorted { ($0.sortKey, $0.id) < ($1.sortKey, $1.id) }
        if let sel = selectedOffer, !offers.contains(where: { $0.id == sel.id && $0.version == sel.version }) {
            selectedOffer = nil
            selectionNotice = L.x("Lista de oferte s-a actualizat. Alege din nou oferta.", "The offer list has been updated. Please choose your offer again.", "La lista de ofertas se ha actualizado. Elige de nuevo tu oferta.")
        }
        let locked = !m.allowsFeatures
        if wasLocked && !locked && !m.isFull { DemoProfile.wipe() }     // sesiune nouă după cooldown: de la zero
        if !wasLocked && locked { DemoProfile.wipe() }                  // sesiunea s-a încheiat: nu rămân setări/cache
        wasLocked = locked
    }

    private var cachedRequest: (key: String, text: String)?
    /// Același text pentru „Cere o licență” și „Copiază cererea”: generat o dată per ofertă aleasă și limbă (identificatorul cererii și nonce-ul nu se schimbă între cele două acțiuni).
    func activationRequestText() -> String {
        let key = "\(selectedOffer?.id ?? "-")|\(selectedOffer?.version ?? 0)|\(CoreL.code)"
        if let c = cachedRequest, c.key == key { return c.text }
        let t = provider.activationRequestText(offerID: selectedOffer?.id); cachedRequest = (key, t); return t
    }
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
                VStack(spacing: 8) {
                    ForEach(access.offers) { o in OfferRadioRow(offer: o, selected: access.selectedOffer?.id == o.id && access.selectedOffer?.version == o.version) { access.select(o) } }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(L.x("Oferte de donație", "Donation offers", "Ofertas de donación"))
                if let n = access.selectionNotice { Text(n).font(.callout).foregroundStyle(.orange) }
                else if access.selectedOffer == nil { Text(L.x("Alege o ofertă", "Choose an offer", "Elige una oferta")).font(.callout).foregroundStyle(Studio.textMuted) }
            } else if access.isOfficial, !access.mode.isFull {
                Text(L.x("Ofertele nu sunt disponibile acum. Verifică conexiunea la internet și încearcă din nou.", "Offers are not available right now. Check your internet connection and try again.", "Las ofertas no están disponibles ahora. Comprueba tu conexión a internet e inténtalo de nuevo.")).font(.callout).foregroundStyle(Studio.textMuted)
            }
            if !access.mode.isFull {
                WrapLayout(spacing: 8) {
                    Button { requestViaWhatsApp() } label: { Label(L.x("Cere o licență", "Request a licence", "Solicitar una licencia"), systemImage: "message") }
                        .buttonStyle(.borderedProminent).tint(Studio.accent).disabled(!access.canRequestLicense)
                    Button(L.x("Deschide pagina produsului", "Open the product page", "Abrir la página del producto")) { NSWorkspace.shared.open(URL(string: "https://gordas.dev/mac-master-control-pro/")!) }
                    Button(L.x("Copiază Machine ID", "Copy Machine ID", "Copiar Machine ID")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(DemoHooks.machineID ?? MachineID.display, forType: .string) }
                    Button(L.x("Copiază cererea", "Copy request", "Copiar solicitud")) { copyRequest() }.disabled(!access.canRequestLicense)
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

    private func copyRequest() {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(access.activationRequestText(), forType: .string)
        message = L.x("Cererea a fost copiată.", "The request was copied.", "La solicitud se ha copiado.")
    }

    /// Deschide conversația WhatsApp cu mesajul pregătit; utilizatorul decide trimiterea. Dacă nu se poate deschide, cererea se copiază.
    private func requestViaWhatsApp() {
        let url = WhatsAppLink.url(text: access.activationRequestText())
        if let sink = DemoHooks.whatsAppSink { try? url.absoluteString.write(toFile: sink, atomically: true, encoding: .utf8); return }
        if !NSWorkspace.shared.open(url) {
            copyRequest()
            message = L.x("WhatsApp nu a putut fi deschis. Cererea a fost copiată: o poți trimite manual.", "WhatsApp could not be opened. The request was copied: you can send it manually.", "No se pudo abrir WhatsApp. La solicitud se ha copiado: puedes enviarla manualmente.")
        }
    }

    static var fmt: DateFormatter { let f = DateFormatter(); f.dateFormat = "d MMMM yyyy, HH:mm"; f.locale = L.locale; return f }
}

/// Rând de ofertă cu comportament de buton radio: tot rândul e clicabil, cerc bifat + fundal evidențiat, accesibil (rol buton + stare selectată).
struct OfferRadioRow: View {
    let offer: OfferSummary
    let selected: Bool
    let onSelect: () -> Void
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle").foregroundStyle(selected ? Studio.accent : Studio.textMuted).imageScale(.large)
                Text(offer.title)
                Spacer()
                Text(offer.amountText).fontWeight(.semibold)
            }
            .contentShape(Rectangle())
            .padding(10)
            .background(selected ? Studio.accent.opacity(0.14) : Studio.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Studio.accent : Studio.line, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(offer.title), \(offer.amountText)")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(.default) { onSelect() }
        .accessibilityValue(selected ? L.x("selectat", "selected", "seleccionada") : "")
    }
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
