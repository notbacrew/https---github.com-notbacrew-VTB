
import Foundation
import PDFKit
import UIKit
import CoreData

final class ExportService {
    static let shared = ExportService()

    private init() {}

    func exportToPDF(
        accounts: [BankAccount],
        transactions: [Transaction],
        budgets: [Budget],
        context: NSManagedObjectContext
    ) throws -> URL {
        let pdfMetaData = [
            kCGPDFContextCreator: "VTB Financial App",
            kCGPDFContextAuthor: "User",
            kCGPDFContextTitle: "Финансовый отчет"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let fileName = "financial_report_\(Date().timeIntervalSince1970).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try renderer.writePDF(to: tempURL) { context in
            context.beginPage()

            var yPosition: CGFloat = 50

            let title = "Финансовый отчет"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            let titleSize = title.size(withAttributes: titleAttributes)
            title.draw(at: CGPoint(x: (pageWidth - titleSize.width) / 2, y: yPosition), withAttributes: titleAttributes)
            yPosition += titleSize.height + 30

            let dateString = "Дата: \(Date().formatted())"
            let dateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            dateString.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: dateAttributes)
            yPosition += 30

            yPosition = drawSection(
                title: "Счета",
                content: formatAccounts(accounts),
                yPosition: yPosition,
                pageWidth: pageWidth,
                context: context
            )

            if yPosition > pageHeight - 200 {
                context.beginPage()
                yPosition = 50
            }

            yPosition = drawSection(
                title: "Транзакции",
                content: formatTransactions(transactions),
                yPosition: yPosition,
                pageWidth: pageWidth,
                context: context
            )

            if yPosition > pageHeight - 200 {
                context.beginPage()
                yPosition = 50
            }

            yPosition = drawSection(
                title: "Бюджеты",
                content: formatBudgets(budgets),
                yPosition: yPosition,
                pageWidth: pageWidth,
                context: context
            )
        }

        return tempURL
    }

    private func drawSection(
        title: String,
        content: String,
        yPosition: CGFloat,
        pageWidth: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var currentY = yPosition

        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        title.draw(at: CGPoint(x: 50, y: currentY), withAttributes: sectionAttributes)
        currentY += 25

        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]

        let maxWidth = pageWidth - 100
        let contentSize = content.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: contentAttributes,
            context: nil
        ).size

        let contentRect = CGRect(x: 50, y: currentY, width: maxWidth, height: contentSize.height)
        content.draw(in: contentRect, withAttributes: contentAttributes)

        return currentY + contentSize.height + 30
    }

    private func formatAccounts(_ accounts: [BankAccount]) -> String {
        guard !accounts.isEmpty else {
            return "Нет счетов"
        }

        var result = ""
        for account in accounts {
            let name = account.name ?? account.accountNumber ?? "Счет"
            let balance = (account.balance?.toDecimal ?? 0).formattedCurrency(currencyCode: account.currency ?? "RUB")
            result += "\(name): \(balance)\n"
        }
        return result
    }

    private func formatTransactions(_ transactions: [Transaction]) -> String {
        guard !transactions.isEmpty else {
            return "Нет транзакций"
        }

        var result = ""
        for transaction in transactions.prefix(20) {
            let description = transaction.transactionDescription ?? "Транзакция"
            let amount = (transaction.amount?.toDecimal ?? 0).formattedCurrency(currencyCode: transaction.currency ?? "RUB")
            let date = transaction.transactionDate?.formatted(style: .short) ?? ""
            result += "\(date) - \(description): \(amount)\n"
        }
        if transactions.count > 20 {
            result += "... и ещё \(transactions.count - 20) транзакций\n"
        }
        return result
    }

    private func formatBudgets(_ budgets: [Budget]) -> String {
        guard !budgets.isEmpty else {
            return "Нет бюджетов"
        }

        var result = ""
        for budget in budgets {
            let name = budget.name ?? "Бюджет"
            let total = budget.totalLimitDecimal.formattedCurrency()
            let spent = budget.totalSpent.formattedCurrency()
            let percentage = Int(budget.usagePercentage)
            result += "\(name): \(spent) / \(total) (\(percentage)%)\n"
        }
        return result
    }

    func exportToXLSX(
        accounts: [BankAccount],
        transactions: [Transaction],
        budgets: [Budget],
        context: NSManagedObjectContext
    ) throws -> URL {
        let fileName = "financial_report_\(Date().timeIntervalSince1970).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        var csvContent = "Финансовый отчет\n"
        csvContent += "Дата создания: \(Date().formatted())\n\n"

        csvContent += "СЧЕТА\n"
        csvContent += "Название,Номер счета,Баланс,Валюта\n"
        for account in accounts {
            let name = account.name ?? account.accountNumber ?? "Счет"
            let number = account.accountNumber ?? ""
            let balance = (account.balance?.toDecimal ?? 0).formattedCurrency(currencyCode: account.currency ?? "RUB")
            let currency = account.currency ?? "RUB"
            csvContent += "\"\(name)\",\"\(number)\",\"\(balance)\",\"\(currency)\"\n"
        }

        csvContent += "\n"

        csvContent += "ТРАНЗАКЦИИ\n"
        csvContent += "Дата,Описание,Сумма,Валюта,Категория\n"
        for transaction in transactions.prefix(100) {
            let date = transaction.transactionDate?.formatted(style: .short) ?? ""
            let description = (transaction.transactionDescription ?? "Транзакция").replacingOccurrences(of: "\"", with: "\"\"")
            let amount = (transaction.amount?.toDecimal ?? 0).formattedCurrency(currencyCode: transaction.currency ?? "RUB")
            let currency = transaction.currency ?? "RUB"
            let category = transaction.categoryEnum?.displayName ?? ""
            csvContent += "\"\(date)\",\"\(description)\",\"\(amount)\",\"\(currency)\",\"\(category)\"\n"
        }

        csvContent += "\n"

        csvContent += "БЮДЖЕТЫ\n"
        csvContent += "Название,Лимит,Потрачено,Остаток,Использовано %\n"
        for budget in budgets {
            let name = (budget.name ?? "Бюджет").replacingOccurrences(of: "\"", with: "\"\"")
            let limit = budget.totalLimitDecimal.formattedCurrency()
            let spent = budget.totalSpent.formattedCurrency()
            let remaining = budget.remaining.formattedCurrency()
            let percentage = Int(budget.usagePercentage)
            csvContent += "\"\(name)\",\"\(limit)\",\"\(spent)\",\"\(remaining)\",\(percentage)%\n"
        }

        try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)

        return tempURL
    }

    func exportToDOCX(
        accounts: [BankAccount],
        transactions: [Transaction],
        budgets: [Budget],
        context: NSManagedObjectContext
    ) throws -> URL {
        let fileName = "financial_report_\(Date().timeIntervalSince1970).rtf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        var rtfContent = "{\\rtf1\\ansi\\deff0\n"
        rtfContent += "{\\fonttbl{\\f0 Times New Roman;}}\n"
        rtfContent += "\\f0\\fs24\n"

        rtfContent += "\\b Финансовый отчет\\b0\\par\n"
        rtfContent += "Дата создания: \(Date().formatted())\\par\\par\n"

        rtfContent += "\\b СЧЕТА\\b0\\par\n"
        for account in accounts {
            let name = account.name ?? account.accountNumber ?? "Счет"
            let balance = (account.balance?.toDecimal ?? 0).formattedCurrency(currencyCode: account.currency ?? "RUB")
            rtfContent += "\(name): \(balance)\\par\n"
        }

        rtfContent += "\\par\n"

        rtfContent += "\\b ТРАНЗАКЦИИ\\b0\\par\n"
        for transaction in transactions.prefix(50) {
            let date = transaction.transactionDate?.formatted(style: .short) ?? ""
            let description = transaction.transactionDescription ?? "Транзакция"
            let amount = (transaction.amount?.toDecimal ?? 0).formattedCurrency(currencyCode: transaction.currency ?? "RUB")
            rtfContent += "\(date) - \(description): \(amount)\\par\n"
        }

        rtfContent += "\\par\n"

        rtfContent += "\\b БЮДЖЕТЫ\\b0\\par\n"
        for budget in budgets {
            let name = budget.name ?? "Бюджет"
            let limit = budget.totalLimitDecimal.formattedCurrency()
            let spent = budget.totalSpent.formattedCurrency()
            let percentage = Int(budget.usagePercentage)
            rtfContent += "\(name): \(spent) / \(limit) (\(percentage)%)\\par\n"
        }

        rtfContent += "}\n"

        try rtfContent.write(to: tempURL, atomically: true, encoding: .utf8)

        return tempURL
    }
}
