import SwiftUI
import MacMasterControlProCore

private let installableIds: Set<String> = ["rclone", "macfuse"]

struct DependenciesModuleView: View {
    @ObservedObject var checker: DependencyChecker

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Dependențe & Cerințe Sistem", systemImage: "puzzlepiece.extension").font(.title2).bold()
                Spacer()
                Button("Rescanează") { checker.checkAll() }
            }

            if !checker.allInstalled {
                Label("Unele dependențe lipsesc — modulele Cloud/Rețea pot fi limitate.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            Text("Fiecare componentă are propriul buton de instalare — roșu (neinstalat) devine verde (instalat) după ce comanda reușește. Fără instalare în masă, ca să nu blocheze sistemul.")
                .font(.caption).foregroundStyle(.secondary)

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
                                Button(item.isInstalled ? "Instalat ✔" : "Instalează") {
                                    checker.installOne(id: item.id) {}
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(item.isInstalled ? .green : .red)
                                .disabled(item.isInstalled || checker.isInstalling)
                            } else if item.id == "homebrew" && !item.isInstalled {
                                Button("Instalează (Terminal)") { checker.installHomebrewInTerminal() }
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

            Button(checker.isInstalling ? "Se verifică…" : "Check & Update All") {
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
    }
}
