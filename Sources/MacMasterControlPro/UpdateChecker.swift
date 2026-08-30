import AppKit

/// "Caută Actualizări" — compară versiunea rulată cu ultimul tag GitHub și
/// descarcă+instalează automat, fără să treacă prin browser (Regula 20).
/// Port 1:1 al UpdateChecker din GDCVault/DataMover.
enum UpdateChecker {
    private static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/gordasgdc/mac-master-control-pro/releases/latest")!
    private static let releasesPageURL = URL(string: "https://github.com/gordasgdc/mac-master-control-pro/releases/latest")!

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    static func checkSilentlyOnLaunch(onNewVersion: @escaping (String, URL) -> Void) {
        Task {
            if case .newVersion(let version, let pkgURL) = await fetchLatestTag() {
                let dismissedKey = "mmc_dismissed_update_version"
                if UserDefaults.standard.string(forKey: dismissedKey) == version { return }
                await MainActor.run { onNewVersion(version, pkgURL) }
            }
        }
    }

    static func markDismissed(_ version: String) {
        UserDefaults.standard.set(version, forKey: "mmc_dismissed_update_version")
    }

    static func checkAndShowAlert() {
        Task {
            let result = await fetchLatestTag()
            await MainActor.run { presentResult(result) }
        }
    }

    private enum Result {
        case upToDate
        case newVersion(String, URL)
        case error
    }

    private static func fetchLatestTag() async -> Result {
        var request = URLRequest(url: latestReleaseAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                return .error
            }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            guard isVersion(latest, newerThan: currentVersion) else { return .upToDate }

            // Nume STABIL asteptat pe fiecare release ("MacMasterControlPro.pkg"),
            // vezi Regula 17 - build_installer.sh (cand va exista) trebuie sa-l publice.
            let assets = json["assets"] as? [[String: Any]] ?? []
            let pkgAsset = assets.first { ($0["name"] as? String) == "MacMasterControlPro.pkg" }
            guard let urlString = pkgAsset?["browser_download_url"] as? String, let pkgURL = URL(string: urlString) else {
                return .newVersion(latest, releasesPageURL)
            }
            return .newVersion(latest, pkgURL)
        } catch {
            return .error
        }
    }

    private static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(partsA.count, partsB.count) {
            let x = i < partsA.count ? partsA[i] : 0
            let y = i < partsB.count ? partsB[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func presentResult(_ result: Result) {
        let alert = NSAlert()
        switch result {
        case .upToDate:
            alert.messageText = "Ești la zi"
            alert.informativeText = "Rulezi deja ultima versiune (\(currentVersion))."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        case .newVersion(let version, let pkgURL):
            alert.messageText = "Este disponibilă o versiune nouă"
            alert.informativeText = "Mac Master Control Pro \(version) este disponibil (tu ai \(currentVersion)). Apasă „Actualizează acum” pentru a descărca și instala automat."
            alert.addButton(withTitle: "Actualizează acum")
            alert.addButton(withTitle: "Mai târziu")
            let response = alert.runModal()
            markDismissed(version)
            if response == .alertFirstButtonReturn {
                Task { await SelfUpdater.downloadAndInstall(pkgURL: pkgURL, version: version) }
            }
        case .error:
            alert.messageText = "Verificarea a eșuat"
            alert.informativeText = "Nu am putut verifica dacă există o versiune nouă. Verifică-ți conexiunea la internet și încearcă din nou."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
