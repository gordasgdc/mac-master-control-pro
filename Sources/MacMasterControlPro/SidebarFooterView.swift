import SwiftUI
import AppKit
import MacMasterControlProCore

/// Sidebar Footer (Regula 12) — Nume/Email, Machine ID (copy), versiune,
/// Caută Actualizări. Frati cu List-ul intr-un VStack, NICIODATA
/// .safeAreaInset direct pe List (Regula 24 — bug de suprapunere la resize).
struct SidebarFooterView: View {
    @ObservedObject private var profile = UserProfileStore.shared
    @ObservedObject private var license = LicenseStore.shared
    @State private var copiedFeedback = false
    @State private var isCheckingUpdate = false

    private var machineID: String { MachineID.current() }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()

            HStack {
                Image(systemName: "person.crop.circle")
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.displayName).font(.caption).bold()
                    if !profile.email.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(profile.email).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(license.isActivated ? "Pro" : "Trial")
                    .font(.caption2).bold()
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(license.isActivated ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .foregroundStyle(license.isActivated ? .green : .orange)
                    .clipShape(Capsule())
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(machineID, forType: .string)
                copiedFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copiedFeedback = false }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                    Text(copiedFeedback ? "Copiat" : "Machine ID: \(String(machineID.prefix(13)))…")
                        .font(.caption2).font(.system(.caption2, design: .monospaced))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            HStack {
                Text("v\(UpdateChecker.currentVersion) Pro")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button(isCheckingUpdate ? "Se verifică…" : "Caută actualizări") {
                    isCheckingUpdate = true
                    UpdateChecker.checkAndShowAlert()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { isCheckingUpdate = false }
                }
                .font(.caption2)
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .disabled(isCheckingUpdate)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
