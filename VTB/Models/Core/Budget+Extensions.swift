
import Foundation
import CoreData

extension Budget {

    var totalSpent: Decimal {
        guard let categories = categories as? Set<BudgetCategory> else {
            return 0
        }
        return categories.reduce(Decimal(0)) { total, category in
            let spent = category.spent?.toDecimal ?? 0
            return total + spent
        }
    }

    var totalLimitDecimal: Decimal {
        return totalLimit?.toDecimal ?? 0
    }

    var usagePercentage: Double {
        let limit = totalLimitDecimal
        guard limit > 0 else { return 0 }
        let spent = totalSpent
        return Double(truncating: NSDecimalNumber(decimal: spent / limit * 100))
    }

    var isExceeded: Bool {
        return totalSpent > totalLimitDecimal
    }

    var remaining: Decimal {
        return max(0, totalLimitDecimal - totalSpent)
    }

    var isActive: Bool {
        guard let endDate = endDate else {
            return true
        }
        return endDate >= Date()
    }
}
