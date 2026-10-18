import Foundation
import CryptoKit

/// Ediția comunitară: fără core comercial, fără activare. Funcționează ca Demo: sesiuni de 10 minute de utilizare activă,
/// următoarea după 48 de ore de la epuizare. Starea e în Keychain (HMAC cu o cheie locală); ceasul dat înapoi nu ajută.
public final class CommunityAccess: AccessProviding {
    public static let sessionSeconds = 600
    public static let cooldownSeconds = 172_800
    public static let maxTick = 5

    struct State: Codable, Equatable {
        var consumed = 0
        var started = false
        var exhaustedAt: Double?       // epoch
        var maxSeenNow: Double = 0     // ceas „de încredere”: nu merge înapoi
    }

    private let account: String
    private var state = State()
    private let now: () -> Date
    private var lastTick: Date?
    public var onChange: (() -> Void)?

    public init(account: String = "demo-state", now: @escaping () -> Date = Date.init) {
        self.account = account; self.now = now; load(); reconcileClock()
    }

    private var trusted: Double { max(now().timeIntervalSince1970, state.maxSeenNow) }

    public var mode: AccessMode {
        if let ex = state.exhaustedAt {
            let next = ex + Double(Self.cooldownSeconds)
            if trusted >= next { return .demoAvailable(remainingSeconds: Self.sessionSeconds) }   // sesiune nouă
            return .demoLocked(next: Date(timeIntervalSince1970: next))
        }
        return .demoAvailable(remainingSeconds: max(0, Self.sessionSeconds - state.consumed))
    }

    public var offers: [OfferSummary] { [] }
    public var isOfficialEdition: Bool { false }
    public func activationRequestText() -> String { "Cerere de licență Master Control Studio Pro. Machine ID: \(MachineID.display)" }
    public func submitLicense(_ text: String) async -> String? { "Ediția comunitară nu are activare. Licențele se aplică în ediția oficială distribuită de GDC." }
    public func refresh() async {}

    public func tick(active: Bool) {
        let t = now()
        defer { lastTick = t; reconcileClock() }
        // O sesiune nouă începe după cooldown: contorul se resetează.
        if let ex = state.exhaustedAt, trusted >= ex + Double(Self.cooldownSeconds) {
            state = State(consumed: 0, started: false, exhaustedAt: nil, maxSeenNow: state.maxSeenNow); save(); onChange?()
        }
        guard case .demoAvailable = mode, active else { return }
        let dt = lastTick.map { min(Self.maxTick, max(0, Int(t.timeIntervalSince($0).rounded()))) } ?? 0
        if !state.started { state.started = true }
        state.consumed += dt
        if state.consumed >= Self.sessionSeconds {
            state.consumed = Self.sessionSeconds; state.exhaustedAt = trusted
        }
        save(); onChange?()
    }

    public func resetForTesting() { state = State(); save() }

    private func reconcileClock() { let n = now().timeIntervalSince1970; if n > state.maxSeenNow { state.maxSeenNow = n } }

    // MARK: - Persistență (Keychain + HMAC)
    private var keyAccount: String { account + ".key" }
    private func hmacKey() -> SymmetricKey {
        if let s = SecretStore.get(account: keyAccount), let d = Data(base64Encoded: s) { return SymmetricKey(data: d) }
        let k = SymmetricKey(size: .bits256)
        SecretStore.set(k.withUnsafeBytes { Data($0).base64EncodedString() }, account: keyAccount)
        return k
    }
    private func load() {
        guard let s = SecretStore.get(account: account), let d = Data(base64Encoded: s), d.count > 32 else { return }
        let mac = d.prefix(32), body = d.dropFirst(32)
        guard HMAC<SHA256>.isValidAuthenticationCode(mac, authenticating: body, using: hmacKey()), let st = try? JSONDecoder().decode(State.self, from: body) else {
            // stare coruptă/falsificată: sesiune epuizată acum
            state = State(consumed: Self.sessionSeconds, started: true, exhaustedAt: now().timeIntervalSince1970, maxSeenNow: now().timeIntervalSince1970)
            DiagnosticLog.write(.warning, tag: "access", event: "state.invalid"); save(); return
        }
        state = st
    }
    private func save() {
        guard let body = try? JSONEncoder().encode(state) else { return }
        let mac = HMAC<SHA256>.authenticationCode(for: body, using: hmacKey())
        SecretStore.set((Data(mac) + body).base64EncodedString(), account: account)
    }
}
