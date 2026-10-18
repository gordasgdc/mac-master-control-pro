import AppKit
import MacMasterControlProCore

/// Fereastra de confirmare a unui plan privilegiat: arată clar ce urmează și explică autorizarea ÎNAINTE de dialogul nativ macOS.
/// macOS cere parola o singură dată pentru întregul plan; nimic nu rămâne autorizat după el; anularea oprește tot.
enum PrivilegePlanUI {
    static func install() {
        PrivilegedPlan.approver = { labels, title in
            // Verificare automată (profil izolat cu MCSP_DEMO_ELEVATION): planul se aprobă fără fereastră; doar dialogul de sistem e înlocuit de stub.
            if AppProfile.isIsolated, ["ok", "cancel"].contains(ProcessInfo.processInfo.environment["MCSP_DEMO_ELEVATION"] ?? "") { return true }
            let ask = {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = title
                let shown = labels.prefix(10).map { "• " + $0 }
                let more = labels.count > 10 ? "\n" + String(format: L.x("… și încă %d", "… and %d more", "… y %d más"), labels.count - 10) : ""
                alert.informativeText = String(format: L.x("%d elemente cer drepturi de administrator:", "%d items need administrator rights:", "%d elementos requieren derechos de administrador:"), labels.count) + "\n\n" + shown.joined(separator: "\n") + more + "\n\n" +
                    L.x("macOS va cere parola (sau Touch ID) o SINGURĂ dată pentru acest plan. Nimic nu rămâne autorizat după el. Dacă anulezi, nu se modifică nimic.", "macOS will ask for your password (or Touch ID) ONCE for this plan. Nothing stays authorised afterwards. If you cancel, nothing is changed.", "macOS pedirá tu contraseña (o Touch ID) UNA sola vez para este plan. Nada queda autorizado después. Si cancelas, no se modifica nada.")
                alert.addButton(withTitle: L.x("Continuă", "Continue", "Continuar"))
                alert.addButton(withTitle: L.x("Anulează", "Cancel", "Cancelar"))
                return alert.runModal() == .alertFirstButtonReturn
            }
            return Thread.isMainThread ? ask() : DispatchQueue.main.sync(execute: ask)
        }
    }
}
