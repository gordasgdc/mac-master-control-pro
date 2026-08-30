import SwiftUI

/// Panou "terminal live" reutilizabil - port SwiftUI al
/// `Controls/TerminalLogView` (Windows). Orice modul cu operatii externe
/// (instalare, ștergere fișiere, montare cloud) afișează aici linie cu
/// linie ce se execută, ca userul să vadă CONCRET progresul, nu doar un
/// text static de tip "se instalează…" urmat de tăcere (bug real, gasit
/// 2026-08-30: ștergerea de cache pe Windows părea că nu face nimic).
struct TerminalLogView: View {
    let lines: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                    }
                }
                .padding(8)
            }
            .background(Color.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(maxHeight: 160)
            .onChange(of: lines.count) { _, _ in
                if let last = lines.indices.last {
                    proxy.scrollTo(last, anchor: .bottom)
                }
            }
        }
    }
}
