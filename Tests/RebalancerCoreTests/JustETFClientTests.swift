import Foundation
import Testing
@testable import RebalancerCore

@Suite struct JustETFClientTests {
    @Test func parsesAQuote() throws {
        let json = """
        {"latestQuote":{"raw":173.44,"localized":"173.44"},"latestQuoteDate":"2026-10-12","previousQuote":{"raw":172.92,"localized":"172.92"},"previousQuoteDate":"2026-10-09","dtdPrc":{"raw":0.30,"localized":"0.30"},"dtdAmt":{"raw":0.52,"localized":"0.52"},"quoteTradingVenue":"XETRA","quoteLowHigh":{"low":{"raw":140.50,"localized":"140.50"},"high":{"raw":173.65,"localized":"173.65"}}}
        """
        let quote = try JustETFClient.parseQuote(Data(json.utf8), isin: "IE00B5BMR087")
        #expect(quote.price == 173.44)
        #expect(quote.previousClose == 172.92)
        #expect(quote.date == "2026-10-12")
        #expect(quote.venue == "XETRA")
        #expect(abs(quote.dailyChange! - 0.003007) < 0.00001)
    }

    @Test func rejectsAnUnknownISIN() {
        let json = """
        {"latestQuote":null,"latestQuoteDate":null,"previousQuote":null,"previousQuoteDate":null,"dtdPrc":null,"dtdAmt":null,"quoteTradingVenue":null,"quoteLowHigh":null}
        """
        #expect(throws: QuoteError.noQuote("XS0000000009")) {
            try JustETFClient.parseQuote(Data(json.utf8), isin: "XS0000000009")
        }
    }

    @Test func parsesTheFundName() {
        let html = """
        <h1 id="etf-title" class="mb-1" data-testid="etf-profile-header_etf-name">iShares Core S&amp;P 500 UCITS ETF
        </h1>
        """
        #expect(JustETFClient.parseName(html) == "iShares Core S&P 500 UCITS ETF")
        #expect(JustETFClient.parseName("<title>ETF Screener | justETF</title>") == nil)
    }

    @Test func measuresQuoteAge() {
        let quote = Quote(price: 1, date: "2026-10-09")
        let now = ISO8601DateFormatter().date(from: "2026-10-12T15:00:00Z")!
        #expect(quote.ageInDays(now: now) == 3)
    }
}

@Suite struct ISINTests {
    @Test(arguments: ["US0378331005", "US5949181045", "IE00B5BMR087", "LU0274208692"])
    func acceptsValidISINs(_ isin: String) {
        #expect(ISIN.isValid(isin))
    }

    @Test(arguments: ["US5949181046", "US0378331006", "US037833100", "us0378331005", "1S0378331005", ""])
    func rejectsInvalidISINs(_ isin: String) {
        #expect(!ISIN.isValid(isin))
    }

    @Test func normalizesInput() {
        #expect(ISIN.normalize(" us03 7833-1005 ") == "US0378331005")
    }
}

@Suite struct PortfolioStoreTests {
    @Test func roundTripsAPortfolio() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "etf-rebalancer-\(UUID().uuidString)/portfolio.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = PortfolioStore(url: url)
        let portfolio = Portfolio(
            holdings: [Holding(name: "Equity", isin: "US0378331005", shares: 10, toBuy: 2, quote: Quote(price: 100, previousClose: 99, date: "2026-10-12", venue: "XETRA", fetchedAt: Date(timeIntervalSince1970: 1_800_000_000)))],
            cash: 10,
            deposit: 500,
            equityTarget: 0.7
        )
        try store.save(portfolio)
        #expect(store.load() == portfolio)
    }
}
