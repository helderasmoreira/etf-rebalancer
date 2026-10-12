import SwiftUI

extension Double {
    var money: String {
        formatted(.currency(code: "EUR"))
    }

    var percent: String {
        formatted(.percent.precision(.fractionLength(2)))
    }

    var signedPercent: String {
        formatted(.percent.precision(.fractionLength(2)).sign(strategy: .always()))
    }

    var shares: String {
        formatted(.number.precision(.fractionLength(0...4)))
    }
}

struct NumberField: View {
    @Binding var value: Double
    var width: CGFloat = 80
    var fractionDigits: ClosedRange<Int> = 0...4

    var body: some View {
        TextField("", value: $value, format: .number.precision(.fractionLength(fractionDigits)))
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: width)
    }
}

struct TrailingText: View {
    let text: String
    var caption: String?
    var captionStyle: AnyShapeStyle = AnyShapeStyle(.secondary)

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(text)
                .monospacedDigit()
            if let caption {
                Text(caption)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(captionStyle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
