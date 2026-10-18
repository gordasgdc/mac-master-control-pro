import Foundation

/// Stări de siguranță ale unui element din analiza discului. Nu sunt culori: UI le afișează cu text + pictogramă.
public enum SpaceFlag: String, CaseIterable, Codable, Sendable {
    /// Regulă verificată: aplicația o recreează singură (cache). Poate intra în „recuperabil verificat”.
    case regenerable
    /// Copie în plus, confirmată identică prin sumă de control (rămâne mereu o copie).
    case duplicate
    /// Nu poate fi selectat: backup de dispozitiv, bibliotecă foto, poștă, date de sistem, aplicații.
    case protected
}

/// Reguli de clasificare, toate explicite și explicabile. Nimic nu e „regenerabil” fără o regulă din această listă.
public enum SpaceClassifier {
    public struct Rule: Sendable { public let id: String; public let reason: String }

    /// Nume de foldere (insensibil la majuscule) pe care aplicațiile le recreează singure.
    static let regenerableNames: [String: Rule] = [
        "cacheclip": Rule(id: "resolve-cacheclip", reason: "DaVinci Resolve recreează CacheClip la nevoie."),
        "cache clip": Rule(id: "resolve-cacheclip", reason: "DaVinci Resolve recreează CacheClip la nevoie."),
        "optimized media": Rule(id: "resolve-optimized", reason: "Media optimizată se regenerează din originale."),
        "optimizedmedia": Rule(id: "resolve-optimized", reason: "Media optimizată se regenerează din originale."),
        "adobe media cache": Rule(id: "adobe-media-cache", reason: "Adobe recreează cache-ul media la nevoie."),
        "media cache files": Rule(id: "adobe-media-cache", reason: "Adobe recreează cache-ul media la nevoie."),
        "peak files": Rule(id: "adobe-peak", reason: "Fișierele de formă de undă se regenerează."),
        "deriveddata": Rule(id: "xcode-derived", reason: "Xcode recreează DerivedData la build."),
    ]

    static let protectedFragments: [(String, Rule)] = [
        ("/MobileSync/Backup", Rule(id: "ios-backup", reason: "Backup de dispozitiv iOS: nu se șterge de aici.")),
        (".photoslibrary", Rule(id: "photos", reason: "Bibliotecă Foto: se gestionează din aplicația Foto.")),
        ("/Library/Mail", Rule(id: "mail", reason: "Date Mail.")),
        ("/Library/Messages", Rule(id: "messages", reason: "Date Mesaje.")),
        ("/Library/Mobile Documents", Rule(id: "icloud", reason: "iCloud Drive: se gestionează din iCloud.")),
        ("/Library/Keychains", Rule(id: "keychains", reason: "Chei și parole.")),
        ("Backups.backupdb", Rule(id: "time-machine", reason: "Time Machine.")),
        ("/Resolve Disk Database", Rule(id: "resolve-db", reason: "Baza de date DaVinci Resolve: conține proiectele.")),
        ("/System/", Rule(id: "system", reason: "Sistem.")),
        ("/private/var/db", Rule(id: "system", reason: "Sistem.")),
    ]

    /// Foldere de utilizator care nu se selectează întregi (conținutul lor da).
    static let protectedExactSuffixes = ["/Documents", "/Desktop", "/Pictures", "/Music", "/Movies", "/Downloads", "/Library"]

    public static func flags(path: String, isDirectory: Bool, isAggregate: Bool = false, duplicateSurplus: Set<String> = []) -> Set<SpaceFlag> {
        if isAggregate { return [.protected] }   // „Alte fișiere mici”: nu are cale reală
        var f = Set<SpaceFlag>()
        if let r = protectedReason(path: path, isDirectory: isDirectory) { _ = r; f.insert(.protected) }
        if isDirectory, regenerableRule(path: path) != nil { f.insert(.regenerable) }
        if duplicateSurplus.contains(path) { f.insert(.duplicate) }
        if f.contains(.protected) { f.remove(.regenerable); f.remove(.duplicate) }
        return f
    }

    public static func regenerableRule(path: String) -> Rule? {
        let name = (path as NSString).lastPathComponent.lowercased()
        if let r = regenerableNames[name] { return r }
        if path.hasSuffix("/Library/Caches") || path.contains("/Library/Caches/") && (path as NSString).deletingLastPathComponent.hasSuffix("/Library/Caches") {
            return Rule(id: "library-caches", reason: "Cache de aplicații: se recreează la nevoie.")
        }
        return nil
    }

    public static func protectedReason(path: String, isDirectory: Bool) -> Rule? {
        for (frag, rule) in protectedFragments where path.contains(frag) { return rule }
        if path.hasSuffix(".app") { return Rule(id: "app-bundle", reason: "Aplicație: se dezinstalează din Dezinstalator, cu toate urmele.") }
        for s in protectedExactSuffixes where path.hasSuffix(s) && path.hasPrefix("/Users/") && path.split(separator: "/").count <= 3 { return Rule(id: "user-folder", reason: "Folder personal: selectează conținutul, nu folderul întreg.") }
        return nil
    }

    /// Traduceri RO→EN/ES ale explicațiilor (cheia = textul românesc din reguli). Necunoscut ⇒ textul românesc.
    static let translations: [String: (en: String, es: String)] = [
        "Adobe recreează cache-ul media la nevoie.": ("Adobe recreates its media cache when needed.", "Adobe recrea su caché de medios cuando hace falta."),
        "Aplicație.": ("Application.", "Aplicación."),
        "Aplicație: se dezinstalează din Dezinstalator, cu toate urmele.": ("Application: remove it with the Uninstaller, leftovers included.", "Aplicación: se desinstala con el Desinstalador, con todos sus restos."),
        "Aplicații instalate: se dezinstalează din Dezinstalator.": ("Installed applications: remove them with the Uninstaller.", "Aplicaciones instaladas: se desinstalan con el Desinstalador."),
        "Backup de dispozitiv iOS: nu se șterge de aici.": ("iOS device backup: do not delete it from here.", "Copia de seguridad de un dispositivo iOS: no se borra desde aquí."),
        "Baza de date DaVinci Resolve: conține proiectele.": ("DaVinci Resolve database: it holds your projects.", "Base de datos de DaVinci Resolve: contiene tus proyectos."),
        "Bibliotecă Foto: se gestionează din aplicația Foto.": ("Photos library: manage it from the Photos app.", "Fototeca: se gestiona desde la app Fotos."),
        "Cache de aplicații: se recreează la nevoie.": ("App caches: recreated when needed.", "Cachés de apps: se recrean cuando hace falta."),
        "Chei de protecție.": ("Protection keys.", "Claves de protección."),
        "Chei și parole.": ("Keys and passwords.", "Claves y contraseñas."),
        "Coșul de reciclare se golește din Windows.": ("The Recycle Bin is emptied from Windows.", "La Papelera de reciclaje se vacía desde Windows."),
        "Credențiale.": ("Credentials.", "Credenciales."),
        "DaVinci Resolve recreează CacheClip la nevoie.": ("DaVinci Resolve recreates CacheClip when needed.", "DaVinci Resolve recrea CacheClip cuando hace falta."),
        "Date Mail.": ("Mail data.", "Datos de Mail."),
        "Date Mesaje.": ("Messages data.", "Datos de Mensajes."),
        "Date de sistem.": ("System data.", "Datos del sistema."),
        "Datele derivate ale build-ului se recreează.": ("Build-derived data is recreated.", "Los datos derivados de la compilación se recrean."),
        "Fișiere temporare: aplicațiile le recreează.": ("Temporary files: apps recreate them.", "Archivos temporales: las apps los recrean."),
        "Fișierele de formă de undă se regenerează.": ("Waveform files are regenerated.", "Los archivos de forma de onda se regeneran."),
        "Folder personal: selectează conținutul, nu folderul întreg.": ("Personal folder: select its contents, not the whole folder.", "Carpeta personal: selecciona su contenido, no la carpeta entera."),
        "Folder sincronizat în cloud: ștergerea se propagă; se gestionează din OneDrive.": ("Cloud-synced folder: deleting propagates; manage it from OneDrive.", "Carpeta sincronizada en la nube: el borrado se propaga; se gestiona desde OneDrive."),
        "Media optimizată se regenerează din originale.": ("Optimized media is regenerated from the originals.", "Los medios optimizados se regeneran a partir de los originales."),
        "Sistem.": ("System.", "Sistema."),
        "Time Machine.": ("Time Machine.", "Time Machine."),
        "Xcode recreează DerivedData la build.": ("Xcode recreates DerivedData on build.", "Xcode recrea DerivedData al compilar."),
        "iCloud Drive: se gestionează din iCloud.": ("iCloud Drive: manage it from iCloud.", "iCloud Drive: se gestiona desde iCloud."),
        "Element fără cale reală pe disc (grup de fișiere mici).": ("Item with no real path on disk (group of small files).", "Elemento sin ruta real en el disco (grupo de archivos pequeños)."),
        "Conținut identic cu o altă copie (sumă de control confirmată). Se păstrează o copie.": ("Content identical to another copy (checksum confirmed). One copy is kept.", "Contenido idéntico a otra copia (suma de control confirmada). Se conserva una copia."),
        "Nicio regulă verificată nu se aplică: nu știm dacă există o copie de rezervă. Nu intră în totalul recuperabil; îl poți muta în Coș doar cu confirmare.": ("No verified rule applies: we do not know whether a backup exists. It does not count toward the recoverable total; you can move it to the Trash only with confirmation.", "No se aplica ninguna regla verificada: no sabemos si existe una copia de seguridad. No cuenta en el total recuperable; solo puedes moverlo a la Papelera con confirmación."),
    ]
    public static func localized(_ reason: String, lang: String) -> String {
        guard let t = translations[reason] else { return reason }
        switch lang { case "en": return t.en; case "es": return t.es; default: return reason }
    }

    /// Explicația afișată la cerere: de ce are elementul această stare.
    public static func explanation(path: String, isDirectory: Bool, flags: Set<SpaceFlag>, lang: String = "ro") -> String {
        localized(explanationRO(path: path, isDirectory: isDirectory, flags: flags), lang: lang)
    }

    static func explanationRO(path: String, isDirectory: Bool, flags: Set<SpaceFlag>) -> String {
        if flags.contains(.protected) { return protectedReason(path: path, isDirectory: isDirectory)?.reason ?? "Element fără cale reală pe disc (grup de fișiere mici)." }
        if flags.contains(.regenerable), let r = regenerableRule(path: path) { return r.reason }
        if flags.contains(.duplicate) { return "Conținut identic cu o altă copie (sumă de control confirmată). Se păstrează o copie." }
        return "Nicio regulă verificată nu se aplică: nu știm dacă există o copie de rezervă. Nu intră în totalul recuperabil; îl poți muta în Coș doar cu confirmare."
    }

    /// Din grupurile de duplicate verificate: ce rămâne de păstrat = cea mai veche copie (apoi calea cea mai scurtă); restul e surplus.
    public static func duplicateSurplus(groups: [DuplicateGroup]) -> Set<String> {
        var out = Set<String>()
        for g in groups where g.files.count > 1 {
            let keep = g.files.min { a, b in
                switch (a.modifiedDate, b.modifiedDate) {
                case let (x?, y?) where x != y: return x < y
                default: return a.path.count == b.path.count ? a.path < b.path : a.path.count < b.path.count
                }
            }
            for f in g.files where f.path != keep?.path { out.insert(f.path) }
        }
        return out
    }
}

/// Selecția și totalurile, fără dublă numărare: un părinte selectat înlocuiește copiii selectați; un duplicat din interiorul unui
/// element regenerabil deja numărat nu se adaugă a doua oară.
public struct SpaceSelectionSummary: Equatable {
    public var recoverableBytes: Int64 = 0       // verificat: regenerabil + surplus duplicate
    public var unverifiedBytes: Int64 = 0         // fără regulă verificată: nu intră în total
    public var recoverable: [String] = []         // căi
    public var unverified: [String] = []
    public var blocked: [String] = []             // protejate (nu ar trebui să ajungă aici)
    public var moveBytes: Int64 { recoverableBytes + unverifiedBytes }
}

public enum SpaceMath {
    public static func summarize(nodes: [DiskTreeNode], duplicateSurplus: Set<String> = []) -> SpaceSelectionSummary {
        let paths = Set(nodes.map(\.path))
        func hasSelectedAncestor(_ p: String) -> Bool {
            var cur = (p as NSString).deletingLastPathComponent
            while cur.count > 1 { if paths.contains(cur) { return true }; cur = (cur as NSString).deletingLastPathComponent }
            return false
        }
        var s = SpaceSelectionSummary()
        for n in nodes where !n.isAggregate && !hasSelectedAncestor(n.path) {
            let f = SpaceClassifier.flags(path: n.path, isDirectory: n.isDirectory, duplicateSurplus: duplicateSurplus)
            if f.contains(.protected) { s.blocked.append(n.path); continue }
            if f.contains(.regenerable) || f.contains(.duplicate) { s.recoverableBytes += n.usedBytes; s.recoverable.append(n.path) }
            else { s.unverifiedBytes += n.usedBytes; s.unverified.append(n.path) }
        }
        return s
    }

    /// Total „recuperabil verificat” pe un arbore: elemente regenerabile (fără cele din interiorul altor regenerabile)
    /// plus surplus de duplicate din afara lor. Returnează și suprapunerea evitată.
    public static func volumeTotals(root: DiskTreeNode, duplicateSurplus: Set<String>) -> (regenerable: Int64, duplicateSurplus: Int64, overlap: Int64, recoverable: Int64) {
        var reg: Int64 = 0, dup: Int64 = 0, overlap: Int64 = 0
        func walk(_ n: DiskTreeNode, insideReg: Bool) {
            if n.isAggregate { return }
            let f = SpaceClassifier.flags(path: n.path, isDirectory: n.isDirectory, duplicateSurplus: duplicateSurplus)
            if f.contains(.protected) { return }
            var inReg = insideReg
            if f.contains(.regenerable) && !insideReg { reg += n.usedBytes; inReg = true }
            if f.contains(.duplicate) { if insideReg { overlap += n.usedBytes } else { dup += n.usedBytes } }
            for c in n.children.values { walk(c, insideReg: inReg) }
        }
        walk(root, insideReg: false)
        return (reg, dup, overlap, reg + dup)
    }
}
