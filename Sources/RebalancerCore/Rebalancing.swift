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

    /// Buy-only rebalance in whole shares, minimising the squared distance of equity, bonds
    /// and cash (target zero) from their targets. Locked holdings are never picked and keep
    /// their "To buy".
    mutating func suggestBuys() {
        for index in holdings.indices where !holdings[index].isLocked {
            holdings[index].toBuy = 0
        }
        guard totalAfter > 0 else { return }
        let buys = BuyPlanner(portfolio: self).plan()
        for index in holdings.indices where !holdings[index].isLocked {
            holdings[index].toBuy = buys[index]
        }
    }
}

/// Greedy fill, then local search: give back one share and refill without that ETF,
/// keeping the change whenever it lands closer to the targets.
private struct BuyPlanner {
    let prices: [Double]
    let classes: [AssetClass]
    let buyable: [Bool]
    let baseValues: [AssetClass: Double]
    let targets: [AssetClass: Double]
    let budget: Double

    init(portfolio: Portfolio) {
        let total = portfolio.totalAfter
        prices = portfolio.holdings.map(\.price)
        classes = portfolio.holdings.map(\.assetClass)
        buyable = portfolio.holdings.map { !$0.isLocked && $0.price > 0 }
        baseValues = Dictionary(uniqueKeysWithValues: AssetClass.allCases.map { assetClass in
            (assetClass, portfolio.holdings.filter { $0.assetClass == assetClass }.reduce(0) { $0 + $1.value })
        })
        targets = Dictionary(uniqueKeysWithValues: AssetClass.allCases.map { ($0, portfolio.classTarget($0) * total) })
        budget = portfolio.cashAfter
    }

    func plan() -> [Int] {
        var best = fill(Array(repeating: 0, count: prices.count), excluding: nil)
        var bestError = error(best)
        for _ in 0..<10_000 {
            var improved = false
            for index in best.indices where best[index] > 0 {
                var trial = best
                trial[index] -= 1
                trial = fill(trial, excluding: index)
                let trialError = error(trial)
                if trialError < bestError - 1e-6 {
                    best = trial
                    bestError = trialError
                    improved = true
                    break
                }
            }
            if !improved { break }
        }
        return best
    }

    private func fill(_ start: [Int], excluding excluded: Int?) -> [Int] {
        var buys = start
        var values = classValues(buys)
        var cash = cashLeft(buys)
        while true {
            var best: (index: Int, change: Double)?
            for index in prices.indices where buyable[index] && index != excluded {
                let price = prices[index]
                guard price <= cash + 1e-9 else { continue }
                let excess = values[classes[index], default: 0] - targets[classes[index], default: 0]
                let change = 2 * price * (excess - cash) + 2 * price * price
                if change < -1e-9, change < (best?.change ?? 0) {
                    best = (index, change)
                }
            }
            guard let best else { return buys }
            buys[best.index] += 1
            values[classes[best.index], default: 0] += prices[best.index]
            cash -= prices[best.index]
        }
    }

    private func classValues(_ buys: [Int]) -> [AssetClass: Double] {
        var values = baseValues
        for index in buys.indices {
            values[classes[index], default: 0] += Double(buys[index]) * prices[index]
        }
        return values
    }

    private func cashLeft(_ buys: [Int]) -> Double {
        budget - buys.indices.reduce(0) { $0 + Double(buys[$1]) * prices[$1] }
    }

    private func error(_ buys: [Int]) -> Double {
        let values = classValues(buys)
        let cash = cashLeft(buys)
        return AssetClass.allCases.reduce(cash * cash) { sum, assetClass in
            let gap = values[assetClass, default: 0] - targets[assetClass, default: 0]
            return sum + gap * gap
        }
    }
}
