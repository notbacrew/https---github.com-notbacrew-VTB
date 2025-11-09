
import Foundation

extension Decimal {

    func formattedCurrency(currencyCode: String = "RUB") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: self as NSDecimalNumber) ?? "\(self) ₽"
    }

    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }

    init(_ nsDecimalNumber: NSDecimalNumber) {
        self = nsDecimalNumber as Decimal
    }

    init?(_ nsDecimalNumber: NSDecimalNumber?) {
        guard let nsDecimalNumber = nsDecimalNumber else { return nil }
        self = nsDecimalNumber as Decimal
    }
}

extension NSDecimalNumber {

    var toDecimal: Decimal {
        return self as Decimal
    }

    func formattedCurrency(currencyCode: String = "RUB") -> String {
        return toDecimal.formattedCurrency(currencyCode: currencyCode)
    }
}

extension Optional where Wrapped == NSDecimalNumber {

    var decimalValue: Decimal {
        return self?.toDecimal ?? 0
    }
}
