import Foundation
import SwiftUI

/// Starea cautarii de duplicate, SCOASA din View (2026-09-11).
///
/// Inainte traia in `@State` pe `DuplicateFinderView`. La schimbarea tab-ului
/// din meniul lateral, SwiftUI distruge view-ul si `@State` dispare cu el:
/// rezultatele se pierdeau, iar scanarea pornita continua sa scrie intr-un
/// view mort. Exact simptomul raportat ("se opreste cand schimb meniul").
///
/// Acelasi tipar ca `DiskAnalyzerViewModel.shared`, care functioneaza deja
/// corect in acest repo — nu inventam o solutie noua pentru o problema deja
/// rezolvata o data aici.
@MainActor
public final class DuplicateFinderViewModel: ObservableObject {
    public static let shared = DuplicateFinderViewModel()

    @Published public private(set) var groups: [DuplicateGroup] = []
    @Published public private(set) var isScanning = false
    @Published public private(set) var progress: DuplicateScanProgress?
    @Published public private(set) var totalReclaimable: Int64 = 0
    @Published public private(set) var errorMessage: String?
    /// Bifele userului — supravietuiesc si ele schimbarii de tab.
    @Published public var markedForDeletion: Set<String> = []

    private var consumeTask: Task<Void, Never>?

    public init() {}

    public var statusText: String {
        if let progress { return progress.phase.label }
        if isScanning { return "Se pregătește…" }
        return ""
    }

    public func start(roots: [String]) {
        guard !roots.isEmpty, !isScanning else { return }
        groups = []
        markedForDeletion = []
        totalReclaimable = 0
        errorMessage = nil
        progress = nil
        isScanning = true

        consumeTask = Task { [weak self] in
            let stream = await DuplicateScanService.shared.scan(roots: roots)
            for await event in stream {
                guard let self else { return }
                switch event {
                case .progress(let p):
                    self.progress = p
                case .group(let g):
                    // Grupurile apar pe masura ce sunt gasite, nu toate la
                    // final — userul vede rezultate imediat pe volume mari.
                    self.groups.append(g)
                    self.totalReclaimable += g.reclaimableBytes
                    // Sugestie implicita: pastreaza cel mai vechi exemplar
                    // (originalul, probabil), bifeaza restul.
                    let sorted = g.files.sorted { ($0.modifiedDate ?? .distantFuture) < ($1.modifiedDate ?? .distantFuture) }
                    self.markedForDeletion.formUnion(sorted.dropFirst().map(\.path))
                case .finished:
                    self.isScanning = false
                    self.progress = nil
                case .failed(let message):
                    self.errorMessage = message
                    self.isScanning = false
                    self.progress = nil
                }
            }
            self?.isScanning = false
        }
    }

    public func cancel() {
        consumeTask?.cancel()
        consumeTask = nil
        Task { await DuplicateScanService.shared.cancel() }
        isScanning = false
        progress = nil
    }

    public func toggleMark(_ path: String) {
        if markedForDeletion.contains(path) { markedForDeletion.remove(path) }
        else { markedForDeletion.insert(path) }
    }

    /// Sterge fisierele bifate si scoate din lista grupurile ramase fara rost.
    public func deleteMarked(log: @escaping (String) -> Void) {
        let toDelete = groups.flatMap(\.files).filter { markedForDeletion.contains($0.path) }
        guard !toDelete.isEmpty else { return }
        DuplicateFinderService.delete(toDelete, log: log)
        let deleted = Set(toDelete.map(\.path))
        groups = groups.compactMap { group in
            let remaining = group.files.filter { !deleted.contains($0.path) }
            // Un grup cu un singur exemplar ramas nu mai e un duplicat.
            return remaining.count > 1 ? DuplicateGroup(id: group.id, files: remaining) : nil
        }
        markedForDeletion.subtract(deleted)
        totalReclaimable = groups.reduce(0) { $0 + $1.reclaimableBytes }
    }
}
