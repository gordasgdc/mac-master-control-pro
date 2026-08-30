import SwiftUI
import MacMasterControlProCore

struct DependenciesModuleView: View {
    @ObservedObject var checker: DependencyChecker

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("🧩 Dependențe & Cerințe Sistem").font(.title2).bold()
                Spacer()
                Button("Rescanează") { checker.checkAll() }
            }

            if !checker.allInstalled {
                Label("Unele dependențe lipsesc — modulele Cloud/Rețea pot fi limitate.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
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
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
                .padding(6)
            }

            HStack {
                if checker.items.first(where: { $0.id == "homebrew" })?.isInstalled == false {
                    Button("Instalează Homebrew (Terminal)") { checker.installHomebrewInTerminal() }
                        .buttonStyle(.borderedProminent)
                } else if !checker.allInstalled {
                    Button(checker.isInstalling ? "Se instalează…" : "Instalează Dependențele Lipsă") {
                        checker.installMissingViaBrew {}
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(checker.isInstalling)
                }
                Button(checker.isInstalling ? "Se verifică…" : "Check & Update All") {
                    checker.checkAndUpdateAll {}
                }
                .disabled(checker.isInstalling)
            }

            if !checker.lastLog.isEmpty {
                ScrollView {
                    Text(checker.lastLog)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
            }
            Spacer()
        }
        .padding(24)
        .onAppear { if checker.items.isEmpty { checker.checkAll() } }
    }
}
