import Foundation

public enum AssetClass: String, Codable, CaseIterable, Identifiable, Sendable {
    case equity
    case bonds

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .equity: "Equity"
        case .bonds: "Bonds"
        }
    }
}

public struct Quote: Codable, Equatable, Sendable {
    public var price: Double
    public var previousClose: Double?
    public var date: String?
    public var venue: String?
    public var fetchedAt: Date

    public init(price: Double, previousClose: Double? = nil, date: String? = nil, venue: String? = nil, fetchedAt: Date = .now) {
        self.price = price
        self.previousClose = previousClose
        self.date = date
        self.venue = venue
        self.fetchedAt = fetchedAt
    }

    public var dailyChange: Double? {
        guard let previousClose, previousClose > 0 else { return nil }
        return (price - previousClose) / previousClose
    }

    public var day: Date? {
        guard let date else { return nil }
        return Self.dayFormatter.date(from: date)
    }

    public func ageInDays(now: Date = .now) -> Int? {
        guard let day else { return nil }
        return Calendar(identifier: .gregorian).dateComponents([.day], from: day, to: now).day
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

public struct Holding: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var isin: String
    public var assetClass: AssetClass
    public var shares: Double
    public var toBuy: Int
    public var isLocked: Bool
    public var quote: Quote?

    public init(id: UUID = UUID(), name: String = "", isin: String = "", assetClass: AssetClass = .equity, shares: Double = 0, toBuy: Int = 0, isLocked: Bool = false, quote: Quote? = nil) {
        self.id = id
        self.name = name
        self.isin = isin
        self.assetClass = assetClass
        self.shares = shares
        self.toBuy = toBuy
        self.isLocked = isLocked
        self.quote = quote
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, isin, assetClass, shares, toBuy, isLocked, quote
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isin = try container.decode(String.self, forKey: .isin)
        assetClass = try container.decode(AssetClass.self, forKey: .assetClass)
        shares = try container.decode(Double.self, forKey: .shares)
        toBuy = try container.decode(Int.self, forKey: .toBuy)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        quote = try container.decodeIfPresent(Quote.self, forKey: .quote)
    }

    public var price: Double { quote?.price ?? 0 }
    public var totalShares: Double { shares + Double(toBuy) }
    public var currentValue: Double { shares * price }
    public var value: Double { totalShares * price }
    public var buyCost: Double { Double(toBuy) * price }
}

public struct Portfolio: Codable, Equatable, Sendable {
    public var holdings: [Holding]
    public var cash: Double
    public var deposit: Double
    public var equityTarget: Double

    public init(holdings: [Holding] = [], cash: Double = 0, deposit: Double = 0, equityTarget: Double = 0.85) {
        self.holdings = holdings
        self.cash = cash
        self.deposit = deposit
        self.equityTarget = equityTarget
    }

    private enum CodingKeys: String, CodingKey {
        case holdings, cash, deposit, equityTarget
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        holdings = try container.decode([Holding].self, forKey: .holdings)
        cash = try container.decode(Double.self, forKey: .cash)
        deposit = try container.decode(Double.self, forKey: .deposit)
        equityTarget = try container.decodeIfPresent(Double.self, forKey: .equityTarget) ?? 0.85
    }
}
