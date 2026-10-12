import Foundation

public enum QuoteError: LocalizedError, Equatable {
    case invalidISIN(String)
    case noQuote(String)
    case http(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidISIN(let isin): "\(isin) is not a valid ISIN."
        case .noQuote(let isin): "justETF has no price for \(isin)."
        case .http(let status): "justETF responded with HTTP \(status)."
        }
    }
}

public struct JustETFClient: Sendable {
    private let session: URLSession
    private static let userAgent = "ETFRebalancer/1.0"

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func quote(isin: String) async throws -> Quote {
        guard ISIN.isValid(isin) else { throw QuoteError.invalidISIN(isin) }
        var components = URLComponents(string: "https://www.justetf.com/api/etfs/\(isin)/quote")!
        components.queryItems = [
            URLQueryItem(name: "locale", value: "en"),
            URLQueryItem(name: "currency", value: "EUR"),
            URLQueryItem(name: "isin", value: isin),
        ]
        let data = try await get(components.url!)
        return try Self.parseQuote(data, isin: isin)
    }

    public func name(isin: String) async throws -> String? {
        guard ISIN.isValid(isin) else { throw QuoteError.invalidISIN(isin) }
        let url = URL(string: "https://www.justetf.com/en/etf-profile.html?isin=\(isin)")!
        let data = try await get(url)
        return Self.parseName(String(decoding: data, as: UTF8.self))
    }

    private func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw QuoteError.http(http.statusCode)
        }
        return data
    }

    static func parseQuote(_ data: Data, isin: String, now: Date = .now) throws -> Quote {
        struct Value: Decodable { let raw: Double }
        struct Response: Decodable {
            let latestQuote: Value?
            let latestQuoteDate: String?
            let previousQuote: Value?
            let quoteTradingVenue: String?
        }

        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let latest = response.latestQuote else { throw QuoteError.noQuote(isin) }
        return Quote(
            price: latest.raw,
            previousClose: response.previousQuote?.raw,
            date: response.latestQuoteDate,
            venue: response.quoteTradingVenue,
            fetchedAt: now
        )
    }

    static func parseName(_ html: String) -> String? {
        let marker = "data-testid=\"etf-profile-header_etf-name\">"
        guard let start = html.range(of: marker)?.upperBound,
              let end = html[start...].firstIndex(of: "<")
        else { return nil }
        let name = decodeEntities(String(html[start..<end])).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private static func decodeEntities(_ text: String) -> String {
        [("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&#x27;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " ")]
            .reduce(text) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
    }
}
