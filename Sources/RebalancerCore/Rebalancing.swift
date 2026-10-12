import Foundation

public extension Portfolio {
    var buyCost: Double { holdings.reduce(0) { $0 + $1.buyCost } }
    var available: Double { cash + deposit }
    var cashAfter: Double { available - buyCost }
    var investedBefore: Double { holdings.reduce(0) { $0 + $1.currentValue } }
    var investedAfter: Double { holdings.reduce(0) { $0 + $1.value } }
    var totalBefore: Double { investedBefore + cash }
    var totalAfter: Double { investedAfter + cashAfter }

    func weight(of holding: Holding) -> Double {
        totalAfter > 0 ? holding.value / totalAfter : 0
    }

    func currentWeight(of holding: Holding) -> Double {
        totalBefore > 0 ? holding.currentValue / totalBefore : 0
    }

    func classWeight(_ assetClass: AssetClass) -> Double {
        holdings.filter { $0.assetClass == assetClass }.reduce(0) { $0 + weight(of: $1) }
    }

    func currentClassWeight(_ assetClass: AssetClass) -> Double {
        holdings.filter { $0.assetClass == assetClass }.reduce(0) { $0 + currentWeight(of: $1) }
    }

    var cashWeight: Double { totalAfter > 0 ? cashAfter / totalAfter : 0 }
    var currentCashWeight: Double { totalBefore > 0 ? cash / totalBefore : 0 }

    func classTarget(_ assetClass: AssetClass) -> Double {
        switch assetClass {
        case .equity: equityTarget
        case .bonds: 1 - equityTarget
        }
    }

    func hasHoldings(in assetClass: AssetClass) -> Bool {
        holdings.contains { $0.assetClass == assetClass }
    }

    mutating func useCurrentAllocationAsTarget() {
        let equity = currentClassWeight(.equity)
        let bonds = currentClassWeight(.bonds)
        guard equity + bonds > 0 else { return }
        equityTarget = equity / (equity + bonds)
    }

    mutating func clearBuys() {
        for index in holdings.indices {
            holdings[index].toBuy = 0
        }
    }

    /// Buy-only rebalance in whole shares: greedily buys the share that most reduces the
    /// squared distance of equity, bonds and cash from their targets (cash targets zero).
    /// Locked holdings keep their "To buy" untouched and are never picked.
    mutating func suggestBuys() {
        for index in holdings.indices where !holdings[index].isLocked {
            holdings[index].toBuy = 0
        }
        let total = totalAfter
        guard total > 0 else { return }

        var classValues = Dictionary(uniqueKeysWithValues: AssetClass.allCases.map { assetClass in
            (assetClass, holdings.filter { $0.assetClass == assetClass }.reduce(0) { $0 + $1.value })
        })
        var budget = cashAfter

        for _ in 0..<1_000_000 {
            var best: (index: Int, change: Double)?
            for (index, holding) in holdings.enumerated() {
                let price = holding.price
                guard !holding.isLocked, price > 0, price <= budget + 1e-9 else { continue }
                let excess = classValues[holding.assetClass, default: 0] - classTarget(holding.assetClass) * total
                let change = 2 * price * (excess - budget) + 2 * price * price
                if change < -1e-9, change < (best?.change ?? 0) {
                    best = (index, change)
                }
            }
            guard let best else { break }
            let holding = holdings[best.index]
            holdings[best.index].toBuy += 1
            classValues[holding.assetClass, default: 0] += holding.price
            budget -= holding.price
        }
    }
}
