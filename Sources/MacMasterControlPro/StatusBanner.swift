import SwiftUI

/// [2026-09-03] Cerință explicită de la Cristi: "e foarte ambiguu... nu
/// știi ce face, a rulat, nu a rulat, se rulează... clientul trebuie
/// psihologic să înțeleagă, să zică ok, l-am rulat, e bine." Un text
/// simplu, gri, de tip `.foregroundStyle(.secondary)` (tiparul folosit
/// până acum peste tot, ~40 de locuri) nu se distinge vizual de restul
/// interfeței — un succes și un eșec arătau la fel, doar cuvintele
/// diferă. `StatusBanner` înlocuiește acel tipar cu un bloc COLORAT
/// (verde/roșu/albastru pentru "în curs"), cu iconiță — vizual imposibil
/// de ratat, indiferent dacă userul citește sau doar scanează ecranul.
///
/// Convenția existentă în tot codul (`"✔ ..."` / `"✘ ..."` la începutul
/// oricărui mesaj de status) e folosită direct ca sursă a stării — niciun
/// apelant nu trebuie să treacă un enum separat, doar textul deja scris.
struct StatusBanner: View {
    let text: String

    private enum Kind { case success, failure, inProgress, neutral }

    private var kind: Kind {
        if text.hasPrefix("✔") { return .success }
        if text.hasPrefix("✘") { return .failure }
        if text.hasSuffix("…") || text.contains("Se ") { return .inProgress }
        return .neutral
    }

    private var color: Color {
        switch kind {
        case .success: return .green
        case .failure: return .red
        case .inProgress: return .blue
        case .neutral: return .secondary
        }
    }

    private var icon: String {
        switch kind {
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .neutral: return "info.circle"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text.trimmingCharacters(in: CharacterSet(charactersIn: "✔✘ ")))
                .font(.callout.weight(kind == .neutral ? .regular : .medium))
                .foregroundStyle(kind == .neutral ? .secondary : .primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(kind == .neutral ? 0.08 : 0.15), in: RoundedRectangle(cornerRadius: 8))
    }
}
