import Foundation

public enum ISIN {
    public static func normalize(_ input: String) -> String {
        String(input.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
    }

    public static func isValid(_ isin: String) -> Bool {
        let characters = Array(isin)
        guard characters.count == 12,
              characters[0...1].allSatisfy({ $0.isASCII && $0.isUppercase }),
              characters[11].isNumber
        else { return false }

        var digits: [Int] = []
        for character in characters {
            if let digit = character.wholeNumberValue, character.isASCII {
                digits.append(digit)
            } else if character.isASCII, character.isUppercase, let ascii = character.asciiValue {
                let value = Int(ascii) - 55
                digits.append(value / 10)
                digits.append(value % 10)
            } else {
                return false
            }
        }

        let sum = digits.reversed().enumerated().reduce(0) { sum, pair in
            var digit = pair.element
            if pair.offset.isMultiple(of: 2) == false {
                digit *= 2
                if digit > 9 { digit -= 9 }
            }
            return sum + digit
        }
        return sum.isMultiple(of: 10)
    }
}
