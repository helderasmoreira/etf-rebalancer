import Foundation
import Testing
@testable import RebalancerCore

private func quote(_ price: Double) -> Quote {
    Quote(price: price, fetchedAt: Date(timeIntervalSince1970: 0))
}

private func example(toBuyB: Int = 20, equityTarget: Double = 0.8) -> Portfolio {
    Portfolio(
        holdings: [
            Holding(name: "Equity A", assetClass: .equity, shares: 10, quote: quote(100)),
            Holding(name: "Equity B", assetClass: .equity, shares: 40, toBuy: toBuyB, quote: quote(50)),
            Holding(name: "Bonds", assetClass: .bonds, shares: 40, quote: quote(25)),
        ],
        cash: 10,
        deposit: 1000,
        equityTarget: equityTarget
    )
}

private func squaredError(_ portfolio: Portfolio) -> Double {
    let total = portfolio.totalAfter
    let classes = AssetClass.allCases.reduce(0.0) { sum, assetClass in
        sum + pow((portfolio.classWeight(assetClass) - portfolio.classTarget(assetClass)) * total, 2)
    }
    return classes + pow(portfolio.cashAfter, 2)
}

private func percent(_ fraction: Double) -> Double {
    (fraction * 10_000).rounded() / 100
}

@Suite struct ArithmeticTests {
    let portfolio = example()

    @Test func totalsIncludeTheBuys() {
        #expect(portfolio.holdings.map(\.totalShares) == [10, 60, 40])
        #expect(portfolio.holdings.map(\.value) == [1000, 3000, 1000])
        #expect(portfolio.buyCost == 1000)
        #expect(portfolio.cashAfter == 10)
        #expect(portfolio.totalBefore == 4010)
        #expect(portfolio.totalAfter == 5010)
    }

    @Test func weightsIncludeTheBuys() {
        #expect(portfolio.holdings.map { percent(portfolio.weight(of: $0)) } == [19.96, 59.88, 19.96])
        #expect(percent(portfolio.cashWeight) == 0.2)
        #expect(percent(portfolio.classWeight(.equity)) == 79.84)
        #expect(percent(portfolio.classWeight(.bonds)) == 19.96)
    }

    @Test func currentWeightsIgnoreTheBuysAndDeposit() {
        #expect(percent(portfolio.currentClassWeight(.equity)) == 74.81)
        #expect(percent(portfolio.currentClassWeight(.bonds)) == 24.94)
        #expect(percent(portfolio.currentCashWeight) == 0.25)
    }
}

@Suite struct SuggestBuysTests {
    @Test func spendsTheDepositWithoutOverdrawing() {
        var portfolio = example(toBuyB: 0)
        portfolio.suggestBuys()
        #expect(portfolio.cashAfter >= 0)
        #expect(portfolio.cashAfter < portfolio.holdings.map(\.price).max()!)
        #expect(portfolio.holdings.allSatisfy { $0.toBuy >= 0 })
    }

    @Test func movesCloserToTheSplitThanNotBuying() {
        var suggested = example(toBuyB: 0)
        let untouched = suggested
        suggested.suggestBuys()
        #expect(squaredError(suggested) < squaredError(untouched))
    }

    @Test func landsNearTheSplit() {
        var portfolio = example(toBuyB: 0)
        portfolio.suggestBuys()
        #expect(abs(portfolio.classWeight(.equity) - 0.8) < 0.01)
        #expect(abs(portfolio.classWeight(.bonds) - 0.2) < 0.01)
    }

    @Test func onlyBuysTheUnderweightClass() {
        var portfolio = example(toBuyB: 0, equityTarget: 0.3)
        portfolio.suggestBuys()
        #expect(portfolio.holdings[0].toBuy == 0)
        #expect(portfolio.holdings[1].toBuy == 0)
        #expect(portfolio.holdings[2].toBuy > 0)
    }

    @Test func buysNothingWhenNothingIsAffordable() {
        var portfolio = example(toBuyB: 0)
        portfolio.cash = 0
        portfolio.deposit = 20
        portfolio.suggestBuys()
        #expect(portfolio.holdings.allSatisfy { $0.toBuy == 0 })
    }

    @Test func skipsHoldingsWithoutAPrice() {
        var portfolio = example(toBuyB: 0, equityTarget: 0.5)
        portfolio.holdings[2].quote = nil
        portfolio.suggestBuys()
        #expect(portfolio.holdings[2].toBuy == 0)
        #expect(portfolio.cashAfter >= 0)
    }

    @Test func replacesPreviousManualBuys() {
        var portfolio = example(toBuyB: 500)
        portfolio.suggestBuys()
        #expect(portfolio.cashAfter >= 0)
    }
}

@Suite struct TargetTests {
    @Test func bondsTargetIsTheRemainder() {
        let portfolio = example(equityTarget: 0.7)
        #expect(portfolio.classTarget(.equity) == 0.7)
        #expect(abs(portfolio.classTarget(.bonds) - 0.3) < 1e-9)
    }

    @Test func currentAllocationBecomesTheSplit() {
        var portfolio = example(equityTarget: 0.5)
        portfolio.useCurrentAllocationAsTarget()
        #expect(abs(portfolio.equityTarget - 0.75) < 1e-9)
    }

    @Test func decodesOldFilesWithoutASplit() throws {
        let json = #"{"holdings":[],"cash":10,"deposit":100,"currency":"EUR"}"#
        let portfolio = try JSONDecoder().decode(Portfolio.self, from: Data(json.utf8))
        #expect(portfolio.equityTarget == 0.85)
    }
}
