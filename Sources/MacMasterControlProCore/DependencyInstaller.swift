import Foundation

/// Instalare "out of the box" a dependintelor lipsa (2026-09-11).
///
/// Pana acum `DependencyChecker` DETECTA corect ce lipseste, dar userul primea
/// doar un `installHint` — un text pe care trebuia sa-l duca singur intr-un
/// Terminal. Cerinta lui Cristi: un singur buton, fara ca userul sa deschida
/// vreodata Terminalul.
///
/// Foloseste `PrivilegedRunner` (promptul NATIV de parola/Touch ID, Regula 20),
/// niciodata un Terminal vizibil, si raporteaza fiecare linie in
/// `TerminalLogView` (Regula 26) — o instalare care dureaza minute nu trebuie
/// sa arate ca o aplicatie inghetata.
public enum DependencyInstaller {

    public struct Plan {
        public let items: [DependencyItem]
        public var isEmpty: Bool { items.isEmpty }
        /// Textul din pop-up: exact ce urmeaza sa se instaleze, pe nume.
        public var summary: String {
            items.map(\.name).joined(separator: ", ")
        }
    }

    /// Ce lipseste si POATE fi instalat automat. Componentele optionale nu
    /// intra in plan — nu instalam nimic necerut pe masina userului.
    public static func plan(from items: [DependencyItem]) -> Plan {
        Plan(items: items.filter { !$0.isInstalled && !$0.isOptional && installCommand(for: $0.id) != nil })
    }

    /// Comanda reala per dependinta. `nil` = nu stim s-o instalam automat
    /// (atunci UI-ul ramane la hint-ul manual de dinainte — fail-open, nu
    /// pretindem ca putem rezolva ceva ce nu putem).
    static func installCommand(for id: String) -> String? {
        switch id {
        case "homebrew":
            // Scriptul OFICIAL Homebrew, neinteractiv. NONINTERACTIVE=1 e
            // obligatoriu: altfel scriptul asteapta un ENTER pe care userul
            // n-are unde sa-l dea, si instalarea ar atarna la infinit.
            return "NONINTERACTIVE=1 /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        case "rclone":
            return "\(brewPrefix())/bin/brew install rclone"
        case "ffmpeg":
            return "\(brewPrefix())/bin/brew install ffmpeg"
        case "macfuse":
            return "\(brewPrefix())/bin/brew install --cask macfuse"
        default:
            return nil
        }
    }

    /// Apple Silicon instaleaza in /opt/homebrew, Intel in /usr/local.
    private static func brewPrefix() -> String {
        FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") ? "/opt/homebrew" : "/usr/local"
    }

    /// Instaleaza tot din plan, in ordine. Homebrew intai (restul depind de el).
    /// `log` primeste fiecare linie reala, pentru panoul Terminal Live.
    public static func install(_ plan: Plan, log: @escaping (String) -> Void, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var allOK = true
            // Homebrew e prerechizita pentru celelalte — daca el pica, restul
            // n-au cum sa reuseasca, deci ne oprim in loc sa insiram erori.
            let ordered = plan.items.sorted { a, _ in a.id == "homebrew" }

            for item in ordered {
                guard let command = installCommand(for: item.id) else { continue }
                log("==> Instalez \(item.name)…")
                let result = PrivilegedRunner.run(command) { line in log(line) }
                if result.success {
                    log("==> \(item.name): gata.")
                } else {
                    allOK = false
                    log("==> \(item.name): EȘUAT. Vezi liniile de mai sus.")
                    if item.id == "homebrew" {
                        log("==> Mă opresc: restul componentelor au nevoie de Homebrew.")
                        break
                    }
                }
            }
            DispatchQueue.main.async { completion(allOK) }
        }
    }
}
