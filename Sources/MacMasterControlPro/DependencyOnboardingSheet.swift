import SwiftUI
import MacMasterControlProCore

/// Pop-up de onboarding pentru dependințele lipsă (2026-09-11).
///
/// ATENȚIE — ACEST ECRAN A FOST PROIECTAT SĂ NU ÎNCALCE REGULA 26.
/// Cerința nouă („un pop-up simplu cu un singur buton") intră în tensiune cu
/// Regula 26, stabilită tot de Cristi după un incident real: *„o instalare în
/// masă, silențioasă, a mai multor pachete deodată poate bloca sistemul
/// clientului — pas cu pas, userul vede exact ce se instalează și când"*.
///
/// Împăcarea celor două, fără să se piardă niciuna:
///   - **un singur buton**, cum s-a cerut acum — userul nu mai trebuie să
///     apese câte unul pentru fiecare componentă, și nu vede Terminalul;
///   - dar **lista exactă a ce urmează să se instaleze e afișată ÎNAINTE**,
///     pe nume, deci nimic nu se întâmplă pe nevăzute;
///   - instalarea rulează **secvențial**, nu în paralel, cu fiecare linie
///     reală vizibilă în `TerminalLogView` (Regula 26, partea a doua);
///   - butoanele individuale din panoul Dependențe **rămân** — cine vrea
///     control fin îl are mai departe.
/// Deci: comod ca un buton, transparent ca înainte. Nu „în masă și silențios".
struct DependencyOnboardingSheet: View {
    @ObservedObject var checker: DependencyChecker
    let plan: DependencyInstaller.Plan
    @Binding var isPresented: Bool

    @State private var isInstalling = false
    @State private var logLines: [String] = []
    @State private var finished: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Componente necesare lipsă", systemImage: "shippingbox")
                .font(.title3).bold()

            if let finished {
                Label(
                    finished ? "Totul e instalat. Poți continua." : "Unele componente nu s-au putut instala — vezi detaliile de mai jos.",
                    systemImage: finished ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(finished ? .green : .orange)
            } else {
                Text("Aplicația are nevoie de \(plan.summary) ca să funcționeze complet.")
                Text("Se instalează automat, una după alta. Vei fi întrebat o dată parola de Mac — instalarea rulează în fundal, nu trebuie să deschizi Terminalul.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Panoul apare de cum începe instalarea: o instalare care durează
            // minute nu trebuie să arate ca o aplicație înghețată.
            if isInstalling || !logLines.isEmpty {
                TerminalLogView(lines: logLines)
                    .frame(height: 200)
            }

            HStack {
                if isInstalling { ProgressView().controlSize(.small) }
                Spacer()
                if finished == nil {
                    Button("Mai târziu") { isPresented = false }
                        .disabled(isInstalling)
                    Button("Instalează componentele") { install() }
                        .buttonStyle(.borderedProminent)
                        .disabled(isInstalling)
                } else {
                    Button("Închide") { isPresented = false }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
        .frame(width: 540)
    }

    private func install() {
        isInstalling = true
        logLines = []
        DependencyInstaller.install(plan, log: { line in
            DispatchQueue.main.async { logLines.append(line) }
        }, completion: { ok in
            isInstalling = false
            finished = ok
            checker.checkAll()   // reîmprospătează bulinele roșu/verde
        })
    }
}
