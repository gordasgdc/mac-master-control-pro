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
    /// `nil` la succes; altfel un mesaj de eroare gata de afisat in log.
    public static func delete(_ path: String) -> String? {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)

        if fm.isDeletableFile(atPath: path) {
            do {
                try fm.trashItem(at: url, resultingItemURL: nil)
                Thread.sleep(forTimeInterval: 0.3)
                if !fm.fileExists(atPath: path) { return nil }
                // "succes" fara eroare dar fisierul tot exista - cade pe
                // calea privilegiata mai jos, ca la orice alt esec.
            } catch {
                // cade pe calea privilegiata mai jos.
            }
        }

        let result = PrivilegedRunner.run("rm -rf \"\(path)\"")
        if !result.success {
            return "acces refuzat, chiar și cu parolă de administrator: \(result.output)"
        }
        Thread.sleep(forTimeInterval: 0.3)
        return fm.fileExists(atPath: path) ? "tot există după ștergerea privilegiată" : nil
    }
}
