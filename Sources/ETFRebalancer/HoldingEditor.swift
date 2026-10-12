import RebalancerCore
import SwiftUI

struct HoldingEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Holding
    @State private var lookup: Lookup = .idle
    private let isNew: Bool

    private enum Lookup: Equatable {
        case idle
        case loading
        case found
        case failed(String)
    }

    init(holding: Holding, isNew: Bool) {
        _draft = State(initialValue: holding)
        self.isNew = isNew
    }

    var body: some View {
        let isinValid = ISIN.isValid(draft.isin)

        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("ISIN", text: Binding(
                        get: { draft.isin },
                        set: { draft.isin = ISIN.normalize($0) }
                    ), prompt: Text("IE00B5BMR087"))
                    .font(.body.monospaced())
                    lookupStatus(isinValid: isinValid)
                    TextField("Name", text: $draft.name, prompt: Text("Filled in from justETF"))
                    Picker("Class", selection: $draft.assetClass) {
                        ForEach(AssetClass.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    LabeledContent("Shares held") {
                        NumberField(value: $draft.shares, width: 100)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                if !isNew {
                    Button("Remove", role: .destructive) {
                        model.remove([draft.id])
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save") {
                    model.upsert(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isinValid)
            }
            .padding()
        }
        .frame(width: 480)
        .task(id: draft.isin) {
            await look(up: draft.isin)
        }
    }

    @ViewBuilder
    private func lookupStatus(isinValid: Bool) -> some View {
        switch lookup {
        case .idle:
            if !draft.isin.isEmpty && !isinValid {
                Text("That isn't a valid ISIN yet.").font(.caption).foregroundStyle(.secondary)
            }
        case .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Looking up on justETF…").font(.caption).foregroundStyle(.secondary)
            }
        case .found:
            if let quote = draft.quote {
                Label("\(quote.price.money) on \(quote.venue ?? "justETF"), \(quote.date ?? "")", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private func look(up isin: String) async {
        guard ISIN.isValid(isin) else {
            lookup = .idle
            return
        }
        if !isNew, isin == draft.isin, draft.quote != nil, lookup == .idle {
            lookup = .found
            return
        }
        lookup = .loading
        do {
            let result = try await model.lookUp(isin: isin)
            guard !Task.isCancelled else { return }
            draft.quote = result.quote
            if let name = result.name, draft.name.isEmpty || isNew {
                draft.name = name
            }
            lookup = .found
        } catch {
            guard !Task.isCancelled else { return }
            draft.quote = nil
            lookup = .failed(error.localizedDescription)
        }
    }
}
