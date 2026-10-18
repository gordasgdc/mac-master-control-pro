import Foundation

/// Starea accesului la funcții. Singura sursă pentru ce poate face aplicația acum.
public enum AccessMode: Equatable, Sendable {
    /// Licență sau lease valid. `source` e un text scurt pentru utilizator (ex. „licență”, „lease”).
    case full(source: String)
    /// Sesiune de probă în curs: funcțiile merg cât timp există secunde de utilizare activă.
    case demoAvailable(remainingSeconds: Int)
    /// Sesiunea s-a consumat; următoarea e disponibilă la `next`. Aplicația rămâne deschisă.
    case demoLocked(next: Date)

    public var allowsFeatures: Bool { if case .demoLocked = self { return false } else { return true } }
    public var isFull: Bool { if case .full = self { return true } else { return false } }
}

/// O ofertă de donație afișată utilizatorului. Valorile vin din lista semnată de oferte (ediția oficială);
/// ediția comunitară nu inventează sume și nu afișează niciuna.
public struct OfferSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let amountText: String
    /// Versiunea ofertei din lista semnată: selecția rămâne valabilă doar pentru perechea (id, versiune).
    public let version: Int
    /// Cheie de ordonare naturală (durata ofertei, din lista semnată): o lună, trei luni, un an.
    public let sortKey: Int
    public init(id: String, title: String, amountText: String, version: Int = 0, sortKey: Int = 0) {
        self.id = id; self.title = title; self.amountText = amountText; self.version = version; self.sortKey = sortKey
    }
}

/// Granița dintre aplicația publică (MIT) și componentele comerciale GDC. Ediția oficială furnizează o implementare
/// legată la core-ul privat în momentul build-ului; fără ea, aplicația rulează cu `CommunityAccess`.
public protocol AccessProviding: AnyObject {
    var mode: AccessMode { get }
    var offers: [OfferSummary] { get }
    /// Ediția oficială distribuită de GDC (true) sau cea comunitară din codul sursă (false). Textul îl alege interfața, în limba utilizatorului.
    var isOfficialEdition: Bool { get }
    /// Text de trimis proprietarului pentru a cere o licență (cerere de activare), fără date personale. `offerID` = oferta aleasă de utilizator.
    func activationRequestText(offerID: String?) -> String
    /// Aplică o licență lipită de utilizator. Întoarce mesajul de eroare sau nil la succes.
    func submitLicense(_ text: String) async -> String?
    /// Chemat la ~1 Hz; `active` = utilizatorul folosește efectiv o funcție.
    func tick(active: Bool)
    /// Reîncarcă oferte/lease (rețea), fără a bloca interfața.
    func refresh() async
    var onChange: (() -> Void)? { get set }
}

/// Fabrica de acces: ediția oficială înlocuiește `make` printr-un modul adăugat doar în build-ul oficial.
public enum AccessFactory {
    nonisolated(unsafe) public static var make: () -> AccessProviding = { CommunityAccess() }
}
