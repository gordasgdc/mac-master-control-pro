import Foundation

/// [2026-09-03] Helper comun, extras din fix-ul de dezinstalare (Hedge for
/// Mac, deținut de `root`) — cerință generalizată explicit de Cristi:
/// "la toate aplicațiile [operațiile de fișiere] să aibă posibilitatea
/// să-i ceară să ruleze ca root" — nu doar Dezinstalatorul, ci orice modul
/// care șterge/mută fișiere găsite prin scanare (Fișiere mari, Duplicate,
/// Rosetta Inspector) trebuie să treacă automat pe execuție privilegiată
/// când Coșul de gunoi normal refuză, nu doar să raporteze eroare.
///
/// Reteta completa (vezi UninstallerService.deleteAppBundle pentru
/// varianta originala, cu diagnostic extins):
/// 1. Incearca `trashItem` (reversibil, Cos de gunoi).
/// 2. Daca esueaza SAU fisierul tot exista dupa - cade automat pe
///    `rm -rf` privilegiat (`PrivilegedRunner`, prompt nativ de parola).
/// 3. Verifica REAL, cu `fileExists`, ca a disparut - nu se multumeste
///    cu absenta unei erori aruncate.
public enum PrivilegedFileOps {
    public struct BatchResult {
        /// Calea → `nil` la succes, altfel mesajul de eroare.
        public let results: [String: String?]
        /// Planul privilegiat a fost refuzat/anulat: nimic privilegiat nu s-a executat și nu se mai cere autorizare.
        public let cancelled: Bool
    }

    /// `nil` la succes; altfel un mesaj de eroare gata de afisat in log. Pentru mai multe elemente folosește `deleteBatch` (o singură autorizare).
    public static func delete(_ path: String) -> String? {
        deleteBatch([path]).results[path] ?? nil
    }

    /// Ștergerea unei selecții: mai întâi tot ce merge cu drepturile utilizatorului (Coș, reversibil, FĂRĂ dialog); doar elementele rămase
    /// formează UN SINGUR plan privilegiat, prezentat și autorizat o singură dată. Refuz/anulare = planul se oprește, fără ferestre succesive.
    public static func deleteBatch(_ paths: [String], trashFirst: Bool = true) -> BatchResult {
        let fm = FileManager.default
        var results: [String: String?] = [:]
        var needPrivilege: [String] = []
        for path in paths {
            if trashFirst, fm.isDeletableFile(atPath: path) {
                do {
                    try fm.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                    Thread.sleep(forTimeInterval: 0.1)
                    if !fm.fileExists(atPath: path) { results[path] = .some(nil); continue }
                } catch {}
            }
            if !fm.fileExists(atPath: path) { results[path] = .some(nil); continue }
            if PrivilegedPlan.isSafeDeletePath(path) { needPrivilege.append(path) }
            else { results[path] = CoreL.x("cale protejată: ștergerea privilegiată este refuzată", "protected path: privileged deletion refused", "ruta protegida: se rechaza la eliminación con privilegios") }
        }
        var cancelled = false
        if !needPrivilege.isEmpty {
            let steps = needPrivilege.map { PrivilegedPlan.Step(label: $0, command: "rm -rf -- \(PrivilegedPlan.shellQuote($0))") }
            let outcome = PrivilegedPlan.execute(title: CoreL.x("Ștergere cu drepturi de administrator", "Deletion with administrator rights", "Eliminación con derechos de administrador"), steps: steps)
            cancelled = outcome.cancelled
            for p in needPrivilege {
                if outcome.cancelled { results[p] = CoreL.x("anulat: nu s-a modificat nimic", "cancelled: nothing was changed", "cancelado: no se modificó nada"); continue }
                if case .some(.some(let err)) = outcome.results[p] { results[p] = CoreL.x("acces refuzat, chiar și cu drepturi de administrator: \(err)", "access denied, even with administrator rights: \(err)", "acceso denegado, incluso con derechos de administrador: \(err)"); continue }
                results[p] = fm.fileExists(atPath: p) ? CoreL.x("tot există după ștergerea privilegiată", "still exists after the privileged deletion", "sigue existiendo tras la eliminación con privilegios") : .some(nil)
            }
        }
        return BatchResult(results: results, cancelled: cancelled)
    }
}
