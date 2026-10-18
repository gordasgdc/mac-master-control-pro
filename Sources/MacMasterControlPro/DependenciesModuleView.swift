import SwiftUI
import MacMasterControlProCore

private let installableIds: Set<String> = ["rclone", "macfuse"]

struct DependenciesModuleView: View {
    @ObservedObject var checker: DependencyChecker
    /// Pop-up de onboarding — vezi DependencyOnboardingSheet (Regula 26:
    /// un buton, DAR cu lista afișată înainte și instalare secvențială
    /// vizibilă, nu „în masă și silențios").
    @State private var showOnboarding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label(L.x("Dependențe & Cerințe Sistem", "Dependencies & System Requirements", "Dependencias y requisitos del sistema"), systemImage: "puzzlepiece.extension").font(.title2).bold()
                Spacer()
                Button(L.x("Rescanează", "Rescan", "Volver a analizar")) { checker.checkAll() }
            }

            if !checker.allInstalled {
                Label(L.x("Unele dependențe lipsesc — modulele Cloud/Rețea pot fi limitate.", "Some dependencies are missing — the Cloud/Network modules may be limited.", "Faltan algunas dependencias; los módulos Cloud y Red pueden estar limitados."), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            Text(L.x("Fiecare componentă are propriul buton de instalare — roșu (neinstalat) devine verde (instalat) după ce comanda reușește. Fără instalare în masă, ca să nu blocheze sistemul.", "Each component has its own install button — red (not installed) turns green (installed) once the command succeeds. No bulk install, so the system does not get blocked.", "Cada componente tiene su propio botón de instalación: rojo (no instalado) pasa a verde (instalado) cuando el comando termina bien. Sin instalación masiva, para no bloquear el sistema."))
                .font(.caption).foregroundStyle(.secondary)

            // Scurtătura „un singur buton", pentru cine nu vrea să le apese pe
            // rând. Apare DOAR dacă chiar lipsește ceva instalabil automat.
            if !DependencyInstaller.plan(from: checker.items).isEmpty {
                Button {
                    showOnboarding = true
                } label: {
                    Label(L.x("Instalează dependențele necesare", "Install required dependencies", "Instalar las dependencias necesarias"), systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .help(L.x("Instalează automat tot ce lipsește, fără să deschizi Terminalul.", "Installs everything that is missing automatically, without opening Terminal.", "Instala automáticamente todo lo que falta, sin abrir el Terminal."))
            }

            GroupBox("Status pachete") {
                VStack(spacing: 0) {
                    ForEach(checker.items) { item in
                        HStack {
                            Circle()
                                .fill(item.isInstalled ? Color.green : Color.red)
                                .frame(width: 9, height: 9)
                            Text(item.name).bold()
                            Spacer()
                            Text(item.isInstalled ? (item.version ?? "Instalat") : "Neinstalat")
                                .foregroundStyle(.secondary).font(.caption)

                            if installableIds.contains(item.id) {
                                Button(item.isInstalled ? "Instalat ✔" : L.x("Instalează", "Install", "Instalar")) {
                                    checker.installOne(id: item.id) {}
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(item.isInstalled ? .green : .red)
                                .disabled(item.isInstalled || checker.isInstalling)
                            } else if item.id == "homebrew" && !item.isInstalled {
                                Button(L.x("Instalează (Terminal)", "Install (Terminal)", "Instalar (Terminal)")) { checker.installHomebrewInTerminal() }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                            }
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
                .padding(6)
            }

            Button(checker.isInstalling ? L.x("Se verifică…", "Checking…", "Comprobando…") : "Check & Update All") {
                checker.checkAndUpdateAll {}
            }
            .disabled(checker.isInstalling)

            if !checker.logLines.isEmpty {
                TerminalLogView(lines: checker.logLines)
            }
            Spacer()
        }
        .padding(24)
        .onAppear { if checker.items.isEmpty { checker.checkAll() } }
        .sheet(isPresented: $showOnboarding) {
            DependencyOnboardingSheet(
                checker: checker,
                plan: DependencyInstaller.plan(from: checker.items),
                isPresented: $showOnboarding
            )
        }
    }
}
