import RebalancerCore
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var selection = Set<Holding.ID>()
    @State private var editing: EditRequest?

    private struct EditRequest: Identifiable {
        let holding: Holding
        let isNew: Bool
        var id: Holding.ID { holding.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            HoldingsTable(selection: $selection) { holding in
                editing = EditRequest(holding: holding, isNew: false)
            }

            HStack(alignment: .top, spacing: 16) {
                CashPanel()
                AllocationPanel()
            }
            .padding()
            .background(.background.secondary)
        }
        .navigationSubtitle(status)
        .toolbar { toolbar }
        .sheet(item: $editing) { request in
            HoldingEditor(holding: request.holding, isNew: request.isNew)
        }
        .task { await model.keepPricesFresh() }
        .onChange(of: model.portfolio) { model.save() }
        .overlay {
            if model.portfolio.holdings.isEmpty {
                ContentUnavailableView {
                    Label("No ETFs yet", systemImage: "chart.pie")
                } description: {
                    Text("Add an ETF by its ISIN to start.")
                } actions: {
                    Button("Add ETF") { addHolding() }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                Task { await model.refreshPrices() }
            } label: {
                if model.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Refresh Prices", systemImage: "arrow.clockwise")
                }
            }
            .help("Refresh prices (⌘R). They also refresh every 5 minutes.")
            .disabled(model.isRefreshing)

            Button("Remove ETF", systemImage: "minus") {
                model.remove(selection)
                selection.removeAll()
            }
            .disabled(selection.isEmpty)

            Button("Add ETF", systemImage: "plus") { addHolding() }
        }
    }

    private var status: String {
        if let saveError = model.saveError {
            return "Couldn't save: \(saveError)"
        }
        if model.isRefreshing {
            return "Updating prices…"
        }
        if !model.errors.isEmpty {
            return "\(model.errors.count) price(s) unavailable"
        }
        if let lastRefresh = model.lastRefresh {
            return "Prices from justETF · updated \(lastRefresh.formatted(date: .omitted, time: .shortened))"
        }
        return "Prices from justETF"
    }

    private func addHolding() {
        editing = EditRequest(holding: Holding(), isNew: true)
    }
}
