import RebalancerCore
import SwiftUI

struct CashPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let portfolio = model.portfolio

        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 7) {
                    GridRow {
                        Text("Cash in account")
                        moneyField($model.portfolio.cash)
                    }
                    GridRow {
                        Text("Deposit")
                        moneyField($model.portfolio.deposit)
                    }
                    Divider().gridCellColumns(2)
                    row("Available", portfolio.available.money)
                    row("Cost of buys", portfolio.buyCost > 0 ? (-portfolio.buyCost).money : 0.0.money)
                    GridRow {
                        Text("Cash left").fontWeight(.semibold)
                        Text(portfolio.cashAfter.money)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(portfolio.cashAfter < -0.005 ? .red : .primary)
                            .gridColumnAlignment(.trailing)
                    }
                    Divider().gridCellColumns(2)
                    row("Portfolio now", portfolio.totalBefore.money)
                    row("After deposit", portfolio.totalAfter.money)
                }

                if portfolio.cashAfter < -0.005 {
                    Label("These buys cost \((-portfolio.cashAfter).money) more than you have.", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                }

                HStack {
                    Button("Suggest Buys", systemImage: "wand.and.stars") {
                        model.portfolio.suggestBuys()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(portfolio.holdings.allSatisfy { $0.quote == nil })
                    .help("Fill “To buy” with the whole shares that bring you closest to your equity/bonds split without selling anything")

                    Button("Clear") {
                        model.portfolio.clearBuys()
                    }
                    .disabled(portfolio.holdings.allSatisfy { $0.toBuy == 0 })
                }
            }
            .padding(6)
        } label: {
            Label("Cash", systemImage: "eurosign.circle")
        }
        .frame(width: 330)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).monospacedDigit().gridColumnAlignment(.trailing)
        }
    }

    private func moneyField(_ value: Binding<Double>) -> some View {
        HStack(spacing: 4) {
            NumberField(value: value, width: 110, fractionDigits: 0...2)
            Text("EUR").font(.caption).foregroundStyle(.secondary)
        }
        .gridColumnAlignment(.trailing)
    }
}

struct AllocationPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let portfolio = model.portfolio
        let canSplit = portfolio.hasHoldings(in: .equity) && portfolio.hasHoldings(in: .bonds)

        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("")
                        Text("")
                        Text("Now").font(.caption).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                        Text("After").font(.caption).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                        Text("Target").font(.caption).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                    }
                    allocationRow("Equity", color: .blue, now: portfolio.currentClassWeight(.equity), after: portfolio.classWeight(.equity), target: portfolio.classTarget(.equity))
                    allocationRow("Bonds", color: .teal, now: portfolio.currentClassWeight(.bonds), after: portfolio.classWeight(.bonds), target: portfolio.classTarget(.bonds))
                    allocationRow("Cash", color: .gray, now: portfolio.currentCashWeight, after: portfolio.cashWeight, target: 0)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Target split")
                        Spacer()
                        Text("\(Int((portfolio.equityTarget * 100).rounded()))% equity · \(Int(((1 - portfolio.equityTarget) * 100).rounded()))% bonds")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $model.portfolio.equityTarget, in: 0...1, step: 0.01) {
                        Text("Target split")
                    } minimumValueLabel: {
                        Text("Bonds").font(.caption)
                    } maximumValueLabel: {
                        Text("Equity").font(.caption)
                    }
                    .labelsHidden()
                    .disabled(!canSplit)
                    if !canSplit {
                        Text("Add an equity and a bond ETF to set the split.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Spacer()
                    Button("Use Current Allocation") {
                        model.portfolio.useCurrentAllocationAsTarget()
                    }
                    .help("Set the target split to today's equity/bonds split, before buying")
                }
            }
            .padding(6)
        } label: {
            Label("Allocation", systemImage: "chart.pie")
        }
    }

    private func allocationRow(_ label: String, color: Color, now: Double, after: Double, target: Double) -> some View {
        GridRow {
            Text(label)
            AllocationBar(value: after, target: target, color: color)
                .frame(minWidth: 140, maxWidth: .infinity)
            Text(now.percent).monospacedDigit().foregroundStyle(.secondary)
            Text(after.percent).monospacedDigit().fontWeight(.semibold)
            Text(target.percent).monospacedDigit().foregroundStyle(.secondary)
        }
    }
}

private struct AllocationBar: View {
    let value: Double
    let target: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(color.gradient)
                    .frame(width: max(0, min(1, value)) * width)
                Rectangle()
                    .fill(.primary)
                    .frame(width: 2, height: 14)
                    .offset(x: max(0, min(1, target)) * width - 1)
            }
        }
        .frame(height: 10)
        .help("Bar: after buying · Line: target")
    }
}
