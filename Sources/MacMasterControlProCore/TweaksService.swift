import Foundation

/// O locatie (volum extern sau folder ales manual) gestionata de Spotlight
/// Shield — vezi "Manager de Discuri & Foldere Multi-Select", regula
/// globala de multi-selectie (2026-08-30).
public struct SpotlightTarget: Identifiable, Hashable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let isVolume: Bool
}

/// Mapeaza 1:1 pe menu_system_tweaks din Mac_Master_Control.sh.
public final class TweaksService: ObservableObject {
    /// [2026-09-03] Singleton — vezi comentariul din RenderModeService.
    public static let shared = TweaksService()
    @Published public var spotlightTargets: [SpotlightTarget] = []
    /// Bifa = protejat (fisier `.metadata_never_index` prezent) - citita
    /// direct de pe disc la fiecare scanare, nu presupusa din persistenta.
    @Published public var protectedPaths: Set<String> = []

    private static let customFoldersKey = "mmc.spotlightShield.customFolders"

    public init() {}

    /// Toate 4 sunt scrieri in domeniul utilizatorului sau fisiere pe SSD-uri
    /// proprii - fara sudo, cu exceptia Touch ID (fisier sub /etc).
    public func enableFinderAdvancedView() {
        Shell.run("defaults write com.apple.finder AppleShowAllExtensions -bool true")
        Shell.run("chflags nohidden ~/Library")
        Shell.run("defaults write com.apple.finder ShowPathbar -bool true")
        Shell.run("defaults write com.apple.finder ShowStatusBar -bool true")
        Shell.run("defaults write com.apple.finder FXPreferredViewStyle -string Nlsv")
        Shell.run("killall Finder")
    }

    public func blockDSStoreOnExternalVolumes() {
        Shell.run("defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true")
        Shell.run("defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true")
    }

    /// [2026-09-03] FIX REAL, raportat de Cristi: "nu funcționa tot timpul,
    /// tot îmi cerea parola" — DOUĂ probleme reale găsite în implementarea
    /// veche, nu una singură:
    /// 1. **Rezultatul era ARUNCAT complet** — dacă promptul de admin era
    ///    respins, sau `sed` nu găsea nimic de înlocuit, userul nu vedea
    ///    NICIUN semnal — credea că a activat Touch ID, dar de fapt nimic
    ///    nu se schimbase.
    /// 2. **`sed` cerea o potrivire EXACTĂ de spații** pe linia comentată
    ///    (`'#auth       sufficient     pam_tid.so'`) — șablonul
    ///    `/etc/pam.d/sudo_local.template` al Apple diferă vizibil ca
    ///    formatare de spații/tab-uri între versiuni de macOS; pe orice
    ///    Mac unde formatarea nu se potrivea EXACT, `sed` rula cu succes
    ///    (exit 0) dar înlocuia ZERO linii — Touch ID rămânea dezactivat,
    ///    fără nicio eroare vizibilă. Exact tiparul "merge pe un Mac, nu pe
    ///    altul" raportat.
    /// Fix: regex tolerant la spații (`[[:space:]]+`) pentru linia deja
    /// comentată; dacă TOT nu găsește nimic (șablon complet diferit sau
    /// lipsă), adaugă linia direct la ÎNCEPUTUL fișierului (metoda oficială
    /// documentată de Apple, funcționează indiferent de conținutul
    /// existent) — și verifică REAL, la final, că linia activă chiar
    /// există în fișier, înainte să raporteze succes.
    private static let touchIDPattern = "^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_tid\\.so"

    /// [2026-09-03] `onOutput`, daca dat, primeste comanda exacta si FIECARE
    /// linie de output/eroare de la `osascript` — cerut explicit de Cristi
    /// dupa ce eroarea genereca ("Promptul a fost respins") a ramas
    /// identica intre doua fix-uri diferite, fara nicio informatie reala
    /// de diagnostic vizibila lui. Panoul „Terminal Live" (Regula 26) e
    /// acum cablat si aici, nu doar la instalare/stergere de fisiere.
    public func enableTouchIDForSudo(onOutput: ((String) -> Void)? = nil, completion: @escaping (Bool, String) -> Void) {
        let check = "grep -qE '\(Self.touchIDPattern)' /etc/pam.d/sudo_local"
        let script = """
        test -f /etc/pam.d/sudo_local || cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local; \
        \(check) || sed -E -i '' 's/^#[[:space:]]*(auth[[:space:]]+sufficient[[:space:]]+pam_tid\\.so)/\\1/' /etc/pam.d/sudo_local; \
        \(check) || (printf '%s\\n' 'auth       sufficient     pam_tid.so' | cat - /etc/pam.d/sudo_local > /etc/pam.d/sudo_local.mmcpnew && mv /etc/pam.d/sudo_local.mmcpnew /etc/pam.d/sudo_local); \
        \(check) && echo MMCP_TID_OK || echo MMCP_TID_FAIL
        """
        DispatchQueue.global(qos: .userInitiated).async {
            let result = PrivilegedRunner.run(script, onOutput: { line in
                DispatchQueue.main.async { onOutput?(line) }
            })
            DispatchQueue.main.async {
                let ok = result.success && result.output.contains("MMCP_TID_OK")
                if ok {
                    completion(true, "✔ Touch ID activat pentru comenzi sudo. Repornește Terminal-ul ca să vezi promptul nou.")
                } else if !result.success {
                    completion(false, "✘ Promptul de administrator a fost respins, sau comanda a eșuat — vezi detaliile exacte mai sus, în panoul negru.")
                } else {
                    completion(false, "✘ Nu am putut confirma activarea — verifică manual: sudo cat /etc/pam.d/sudo_local")
                }
            }
        }
    }

    // MARK: - Spotlight Shield (Manager Multi-Select)

    /// Rescaneaza `/Volumes/*` (discuri externe conectate acum, exclus
    /// volumul de boot) + folderele custom adaugate manual (persistate),
    /// si recitesc starea reala de protectie de pe disc pentru fiecare.
    public func scanSpotlightTargets() {
        var targets: [SpotlightTarget] = []

        if let volumes = try? FileManager.default.contentsOfDirectory(atPath: "/Volumes") {
            for name in volumes.sorted() {
                let path = "/Volumes/\(name)"
                // Volumul de boot apare in /Volumes ca legatura catre "/" -
                // il excludem, Spotlight Shield vizeaza doar discuri externe.
                if (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString
                    == (try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeUUIDStringKey]))?.volumeUUIDString {
                    continue
                }
                targets.append(SpotlightTarget(name: name, path: path, isVolume: true))
            }
        }

        for path in customFolders() {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
            targets.append(SpotlightTarget(name: URL(fileURLWithPath: path).lastPathComponent, path: path, isVolume: false))
        }

        spotlightTargets = targets
        protectedPaths = Set(targets.filter { isProtected($0.path) }.map(\.path))
    }

    /// Adauga mai multe foldere deodata (Multi-Select NSOpenPanel in UI).
    public func addCustomFolders(_ paths: [String]) {
        var stored = customFolders()
        for path in paths where !stored.contains(path) { stored.append(path) }
        UserDefaults.standard.set(stored, forKey: Self.customFoldersKey)
        scanSpotlightTargets()
    }

    public func removeCustomFolder(_ path: String) {
        var stored = customFolders()
        stored.removeAll { $0 == path }
        UserDefaults.standard.set(stored, forKey: Self.customFoldersKey)
        setProtected(path, false)
        scanSpotlightTargets()
    }

    private func customFolders() -> [String] {
        UserDefaults.standard.stringArray(forKey: Self.customFoldersKey) ?? []
    }

    public func isProtected(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path + "/.metadata_never_index")
    }

    @discardableResult
    public func setProtected(_ path: String, _ protect: Bool) -> Bool {
        let markerPath = path + "/.metadata_never_index"
        let ok: Bool
        if protect {
            ok = FileManager.default.createFile(atPath: markerPath, contents: nil)
        } else {
            ok = (try? FileManager.default.removeItem(atPath: markerPath)) != nil || !FileManager.default.fileExists(atPath: markerPath)
        }
        if ok {
            if protect { protectedPaths.insert(path) } else { protectedPaths.remove(path) }
        }
        return ok
    }

    /// Aplica protectia pe exact setul bifat (Bara de Actiune in Masa) -
    /// dezactiveaza restul, la fel ca modulele Curatare/Rosetta.
    public func applyProtection(selected: Set<String>) {
        for target in spotlightTargets {
            setProtected(target.path, selected.contains(target.path))
        }
    }
}
