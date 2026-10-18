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
            Text(L.x("Exportă diagnosticul", "Export diagnostics", "Exportar diagnóstico")).font(.title3.bold())
            Text(L.x("Pachetul conține doar fișierele de mai jos, redactate (parole, emailuri, nume de utilizator din căi). Nu include conținutul fișierelor tale și nu se încarcă nicăieri.", "The package contains only the files below, redacted (passwords, emails, user names in paths). It does not include the contents of your files and is never uploaded.", "El paquete contiene solo los archivos de abajo, redactados (contraseñas, correos, nombres de usuario en rutas). No incluye el contenido de tus archivos y no se sube a ningún sitio."))
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
                Button(L.x("Închide", "Close", "Cerrar")) { dismiss() }
                Button(L.x("Salvează ZIP...", "Save ZIP…", "Guardar ZIP…")) { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 360)
        .onAppear { items = DiagnosticExport.preview() }
    }

    private func save() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.prompt = L.x("Alege folderul", "Choose folder", "Elegir carpeta")
        guard panel.runModal() == .OK, let dir = panel.url else { return }
        do {
            let zip = try DiagnosticExport.export(to: dir)
            status = String(format: L.x("Salvat: %@","Saved: %@","Guardado: %@"), zip.path)
            NSWorkspace.shared.activateFileViewerSelecting([zip])
        } catch {
            status = String(format: L.x("Export eșuat: %@","Export failed: %@","Exportación fallida: %@"), error.localizedDescription)
        }
    }
}
