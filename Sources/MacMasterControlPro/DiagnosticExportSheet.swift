import SwiftUI
import AppKit
import MacMasterControlProCore

/// Previzualizare + export local al pachetului de diagnostic (nimic nu se trimite).
struct DiagnosticExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [DiagnosticExport.Item] = []
    @State private var status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exportă diagnosticul").font(.title3.bold())
            Text("Pachetul conține doar fișierele de mai jos, redactate (parole, emailuri, nume de utilizator din căi). Nu include conținutul fișierelor tale și nu se încarcă nicăieri.")
                .font(.callout).foregroundStyle(.secondary)
            List(items) { item in
                HStack {
                    Text(item.name).font(.system(.body, design: .monospaced))
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: Int64(item.bytes), countStyle: .file)).foregroundStyle(.secondary)
                }
                .help(item.note)
            }
            .frame(minHeight: 160)
            if let status { Text(status).font(.callout).textSelection(.enabled) }
            HStack {
                Spacer()
                Button("Închide") { dismiss() }
                Button("Salvează ZIP...") { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 360)
        .onAppear { items = DiagnosticExport.preview() }
    }

    private func save() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.prompt = "Alege folderul"
        guard panel.runModal() == .OK, let dir = panel.url else { return }
        do {
            let zip = try DiagnosticExport.export(to: dir)
            status = "Salvat: \(zip.path)"
            NSWorkspace.shared.activateFileViewerSelecting([zip])
        } catch {
            status = "Export eșuat: \(error.localizedDescription)"
        }
    }
}
