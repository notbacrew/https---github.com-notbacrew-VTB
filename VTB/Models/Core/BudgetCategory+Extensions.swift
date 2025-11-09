
import Foundation
import CoreData

extension BudgetCategory {

    var spentDecimal: Decimal {
        return spent?.toDecimal ?? 0
    }

    var limitDecimal: Decimal {
        return limit?.toDecimal ?? 0
    }

    var usagePercentage: Double {
        let limitValue = limitDecimal
        guard limitValue > 0 else { return 0 }
        let spentAmount = spentDecimal
        return Double(truncating: NSDecimalNumber(decimal: spentAmount / limitValue * 100))
    }

    var isExceeded: Bool {
        return spentDecimal > limitDecimal
    }

    var remaining: Decimal {
        return max(0, limitDecimal - spentDecimal)
    }

    var categoryEnum: TransactionCategory? {
        guard let categoryType = categoryType else { return nil }
        return TransactionCategory(rawValue: categoryType)
    }
}
