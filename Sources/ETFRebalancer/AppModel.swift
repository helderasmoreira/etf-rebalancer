import Foundation
import Observation
import RebalancerCore

@MainActor
@Observable
final class AppModel {
    var portfolio: Portfolio
    var isRefreshing = false
    var lastRefresh: Date?
    var errors: [Holding.ID: String] = [:]
    var saveError: String?

    private let client = JustETFClient()
    private let store = PortfolioStore()
    private static let refreshInterval: Duration = .seconds(300)

    init() {
        portfolio = store.load() ?? Portfolio()
    }

    func save() {
        do {
            try store.save(portfolio)
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }

    func keepPricesFresh() async {
        while !Task.isCancelled {
            await refreshPrices()
            try? await Task.sleep(for: Self.refreshInterval)
        }
    }

    func refreshPrices() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let client = client
        let requests = portfolio.holdings.map { ($0.id, $0.isin) }

        let results = await withTaskGroup(of: (Holding.ID, Result<Quote, any Error>).self) { group in
            for (id, isin) in requests {
                group.addTask {
                    do {
                        return (id, .success(try await client.quote(isin: isin)))
                    } catch {
                        return (id, .failure(error))
                    }
                }
            }
            var results: [(Holding.ID, Result<Quote, any Error>)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        for (id, result) in results {
            guard let index = portfolio.holdings.firstIndex(where: { $0.id == id }) else { continue }
            switch result {
            case .success(let quote):
                portfolio.holdings[index].quote = quote
                errors[id] = nil
            case .failure(let error):
                errors[id] = error.localizedDescription
            }
        }
        lastRefresh = .now
    }

    func lookUp(isin: String) async throws -> (name: String?, quote: Quote) {
        let client = client
        async let quote = client.quote(isin: isin)
        async let name = try? client.name(isin: isin)
        return try await (name, quote)
    }

    func upsert(_ holding: Holding) {
        if let index = portfolio.holdings.firstIndex(where: { $0.id == holding.id }) {
            portfolio.holdings[index] = holding
        } else {
            portfolio.holdings.append(holding)
        }
        if holding.quote != nil {
            errors[holding.id] = nil
        }
    }

    func remove(_ ids: Set<Holding.ID>) {
        portfolio.holdings.removeAll { ids.contains($0.id) }
        for id in ids {
            errors[id] = nil
        }
    }

    func toggleLock(_ id: Holding.ID) {
        guard let index = portfolio.holdings.firstIndex(where: { $0.id == id }) else { return }
        portfolio.holdings[index].isLocked.toggle()
    }

    func move(_ id: Holding.ID, by offset: Int) {
        guard let index = portfolio.holdings.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + offset
        guard portfolio.holdings.indices.contains(destination) else { return }
        portfolio.holdings.swapAt(index, destination)
    }
}
