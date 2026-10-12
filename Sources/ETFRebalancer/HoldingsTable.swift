import RebalancerCore
import SwiftUI

struct HoldingsTable: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: Set<Holding.ID>
    let onEdit: (Holding) -> Void

    var body: some View {
        @Bindable var model = model
        let portfolio = model.portfolio

        Table($model.portfolio.holdings, selection: $selection) {
            TableColumn("") { $holding in
                Button {
                    holding.isLocked.toggle()
                } label: {
                    Image(systemName: holding.isLocked ? "lock.fill" : "lock.open")
                        .foregroundStyle(holding.isLocked ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                }
                .buttonStyle(.borderless)
                .help(holding.isLocked ? "Locked: Suggest Buys won't buy this ETF. Click to unlock." : "Lock to stop Suggest Buys from buying this ETF")
            }
            .width(22)

            TableColumn("ETF") { $holding in
                ETFCell(holding: holding, error: model.errors[holding.id])
            }
            .width(min: 200, ideal: 250)

            TableColumn("Class") { $holding in
                Picker("Class", selection: $holding.assetClass) {
                    ForEach(AssetClass.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
            }
            .width(90)

            TableColumn("Price") { $holding in
                PriceCell(quote: holding.quote)
            }
            .width(min: 80, ideal: 95)

            TableColumn("Current") { $holding in
                NumberField(value: $holding.shares, width: 70)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 80, ideal: 85)

            TableColumn("To buy") { $holding in
                HStack(spacing: 2) {
                    TextField("", value: $holding.toBuy, format: .number)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(width: 52)
                    Stepper("To buy", value: $holding.toBuy, in: 0...1_000_000)
                        .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 85, ideal: 90)

            TableColumn("Total") { $holding in
                TrailingText(text: holding.totalShares.shares)
                    .fontWeight(holding.toBuy > 0 ? .semibold : .regular)
            }
            .width(min: 50, ideal: 60)

            TableColumn("Value") { $holding in
                TrailingText(
                    text: holding.value.money,
                    caption: holding.toBuy > 0 ? "+" + holding.buyCost.money : nil
                )
            }
            .width(min: 90, ideal: 100)

            TableColumn("Weight") { $holding in
                TrailingText(
                    text: portfolio.weight(of: holding).percent,
                    caption: holding.toBuy > 0 ? "was " + portfolio.currentWeight(of: holding).percent : nil
                )
            }
            .width(min: 70, ideal: 80)
        }
        .contextMenu(forSelectionType: Holding.ID.self) { ids in
            if ids.count == 1, let id = ids.first, let holding = portfolio.holdings.first(where: { $0.id == id }) {
                Button("Edit…") { onEdit(holding) }
                Button(holding.isLocked ? "Unlock" : "Lock") { model.toggleLock(id) }
                Button("Move Up") { model.move(id, by: -1) }
                Button("Move Down") { model.move(id, by: 1) }
                Divider()
            }
            if !ids.isEmpty {
                Button("Remove", role: .destructive) { model.remove(ids) }
            }
        } primaryAction: { ids in
            if let id = ids.first, let holding = portfolio.holdings.first(where: { $0.id == id }) {
                onEdit(holding)
            }
        }
        .onDeleteCommand { model.remove(selection) }
    }
}

private struct ETFCell: View {
    let holding: Holding
    let error: String?

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(holding.name.isEmpty ? "Unnamed ETF" : holding.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(holding.isin.isEmpty ? "No ISIN" : holding.isin)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            if let error {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(error)
            }
        }
        .help(holding.name)
    }
}

private struct PriceCell: View {
    let quote: Quote?

    var body: some View {
        if let quote {
            let age = quote.ageInDays() ?? 0
            TrailingText(
                text: quote.price.money,
                caption: age > 4 ? "\(age)d old" : quote.dailyChange?.signedPercent,
                captionStyle: captionStyle(age: age, change: quote.dailyChange)
            )
            .help(help(for: quote))
        } else {
            TrailingText(text: "—")
                .foregroundStyle(.secondary)
        }
    }

    private func captionStyle(age: Int, change: Double?) -> AnyShapeStyle {
        if age > 4 { return AnyShapeStyle(.orange) }
        guard let change, change != 0 else { return AnyShapeStyle(.secondary) }
        return AnyShapeStyle(change > 0 ? Color.green : Color.red)
    }

    private func help(for quote: Quote) -> String {
        var parts = ["Last price \(quote.date ?? "unknown date")"]
        if let venue = quote.venue { parts.append("on \(venue)") }
        if let previous = quote.previousClose { parts.append("· previous close \(previous.money)") }
        parts.append("· fetched \(quote.fetchedAt.formatted(date: .omitted, time: .shortened))")
        return parts.joined(separator: " ")
    }
}
