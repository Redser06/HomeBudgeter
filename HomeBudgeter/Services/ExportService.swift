//
//  ExportService.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import AppKit
import SwiftData
import UniformTypeIdentifiers

final class ExportService {
    static let shared = ExportService()
    private init() {}

    // MARK: - CSV Generation

    func generateTransactionCSV(transactions: [Transaction]) -> Data {
        var lines: [String] = []
        lines.append("Date,Description,Type,Category,Amount,Account,Notes")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for t in transactions {
            let date = dateFormatter.string(from: t.date)
            let desc = csvEscape(t.descriptionText)
            let type = t.type.rawValue
            let category = csvEscape(t.category?.type.rawValue ?? "General")
            let amount = "\(t.amount)"
            let account = csvEscape(t.account?.name ?? "")
            let notes = csvEscape(t.notes ?? "")
            lines.append("\(date),\(desc),\(type),\(category),\(amount),\(account),\(notes)")
        }

        return lines.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    func generateBudgetCSV(categories: [BudgetCategory], spent: [UUID: Decimal]) -> Data {
        var lines: [String] = []
        lines.append("Category,Budget Amount,Spent,Remaining,Utilisation %")

        for cat in categories {
            let name = csvEscape(cat.type.rawValue)
            let budget = "\(cat.budgetAmount)"
            let spentAmount = spent[cat.id] ?? 0
            let remaining = cat.budgetAmount - spentAmount
            let utilisation = cat.budgetAmount > 0
                ? Double(truncating: (spentAmount / cat.budgetAmount * 100) as NSNumber)
                : 0.0
            lines.append("\(name),\(budget),\(spentAmount),\(remaining),\(String(format: "%.1f", utilisation))")
        }

        return lines.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    // MARK: - PDF Generation

    func generateTransactionPDF(
        transactions: [Transaction],
        title: String = "Transaction Report",
        dateRange: String? = nil
    ) -> Data {
        let pageWidth: CGFloat = 595 // A4 width in points
        let pageHeight: CGFloat = 842 // A4 height in points
        let margin: CGFloat = 50
        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        var yPosition = pageHeight - margin

        func startNewPage() {
            if yPosition < pageHeight - margin {
                context.endPage()
            }
            context.beginPage(mediaBox: &mediaBox)
            yPosition = pageHeight - margin
        }

        func drawText(_ text: String, x: CGFloat, y: CGFloat, font: NSFont, color: NSColor = .black) {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            let attrString = NSAttributedString(string: text, attributes: attributes)
            let line = CTLineCreateWithAttributedString(attrString)

            context.saveGState()
            context.textMatrix = .identity
            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)
            context.restoreGState()
        }

        func drawLine(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat, color: NSColor = .separatorColor) {
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: x1, y: y1))
            context.addLine(to: CGPoint(x: x2, y: y2))
            context.strokePath()
        }

        // Start first page
        startNewPage()

        // Title
        drawText(title, x: margin, y: yPosition, font: .boldSystemFont(ofSize: 18))
        yPosition -= 22

        // Date range subtitle
        if let range = dateRange {
            drawText(range, x: margin, y: yPosition, font: .systemFont(ofSize: 11), color: .secondaryLabelColor)
            yPosition -= 16
        }

        // Generated date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        drawText(
            "Generated: \(dateFormatter.string(from: Date()))",
            x: margin, y: yPosition,
            font: .systemFont(ofSize: 9), color: .tertiaryLabelColor
        )
        yPosition -= 24
        drawLine(x1: margin, y1: yPosition, x2: pageWidth - margin, y2: yPosition)
        yPosition -= 20

        // Table header
        let colDate: CGFloat = margin
        let colDesc: CGFloat = margin + 80
        let colType: CGFloat = margin + 280
        let colCategory: CGFloat = margin + 340
        let colAmount: CGFloat = pageWidth - margin - 70

        let headerFont = NSFont.boldSystemFont(ofSize: 9)
        drawText("Date", x: colDate, y: yPosition, font: headerFont, color: .secondaryLabelColor)
        drawText("Description", x: colDesc, y: yPosition, font: headerFont, color: .secondaryLabelColor)
        drawText("Type", x: colType, y: yPosition, font: headerFont, color: .secondaryLabelColor)
        drawText("Category", x: colCategory, y: yPosition, font: headerFont, color: .secondaryLabelColor)
        drawText("Amount", x: colAmount, y: yPosition, font: headerFont, color: .secondaryLabelColor)
        yPosition -= 6
        drawLine(x1: margin, y1: yPosition, x2: pageWidth - margin, y2: yPosition)
        yPosition -= 14

        // Rows
        let rowDateFmt = DateFormatter()
        rowDateFmt.dateFormat = "dd MMM yyyy"
        let rowFont = NSFont.systemFont(ofSize: 9)

        var totalIncome: Decimal = 0
        var totalExpenses: Decimal = 0

        for transaction in transactions {
            if yPosition < margin + 40 {
                startNewPage()
                // Re-draw header on new page
                drawText("Date", x: colDate, y: yPosition, font: headerFont, color: .secondaryLabelColor)
                drawText("Description", x: colDesc, y: yPosition, font: headerFont, color: .secondaryLabelColor)
                drawText("Type", x: colType, y: yPosition, font: headerFont, color: .secondaryLabelColor)
                drawText("Category", x: colCategory, y: yPosition, font: headerFont, color: .secondaryLabelColor)
                drawText("Amount", x: colAmount, y: yPosition, font: headerFont, color: .secondaryLabelColor)
                yPosition -= 6
                drawLine(x1: margin, y1: yPosition, x2: pageWidth - margin, y2: yPosition)
                yPosition -= 14
            }

            let dateStr = rowDateFmt.string(from: transaction.date)
            let desc = String(transaction.descriptionText.prefix(30))
            let type = transaction.type.rawValue
            let cat = transaction.category?.type.rawValue ?? "General"
            let amountStr = CurrencyFormatter.shared.format(transaction.amount)
            let amountColor: NSColor = transaction.type == .expense ? .systemRed : .systemGreen

            if transaction.type == .income {
                totalIncome += transaction.amount
            } else if transaction.type == .expense {
                totalExpenses += transaction.amount
            }

            drawText(dateStr, x: colDate, y: yPosition, font: rowFont)
            drawText(desc, x: colDesc, y: yPosition, font: rowFont)
            drawText(type, x: colType, y: yPosition, font: rowFont)
            drawText(cat, x: colCategory, y: yPosition, font: rowFont)
            drawText(amountStr, x: colAmount, y: yPosition, font: rowFont, color: amountColor)
            yPosition -= 16
        }

        // Summary footer
        yPosition -= 10
        drawLine(x1: margin, y1: yPosition, x2: pageWidth - margin, y2: yPosition)
        yPosition -= 18

        let summaryFont = NSFont.boldSystemFont(ofSize: 10)
        drawText("Total Income:", x: colCategory - 80, y: yPosition, font: summaryFont)
        drawText(CurrencyFormatter.shared.format(totalIncome), x: colAmount, y: yPosition, font: summaryFont, color: .systemGreen)
        yPosition -= 16
        drawText("Total Expenses:", x: colCategory - 80, y: yPosition, font: summaryFont)
        drawText(CurrencyFormatter.shared.format(totalExpenses), x: colAmount, y: yPosition, font: summaryFont, color: .systemRed)
        yPosition -= 16
        let net = totalIncome - totalExpenses
        drawText("Net:", x: colCategory - 80, y: yPosition, font: summaryFont)
        drawText(
            CurrencyFormatter.shared.format(net),
            x: colAmount, y: yPosition,
            font: summaryFont,
            color: net >= 0 ? .systemGreen : .systemRed
        )

        context.endPage()
        context.closePDF()

        return pdfData as Data
    }

    // MARK: - File Save Helper

    func saveWithPanel(data: Data, suggestedName: String, fileType: ExportFileType) async -> URL? {
        await MainActor.run {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = suggestedName
            panel.allowedContentTypes = [fileType.utType]
            panel.canCreateDirectories = true

            guard panel.runModal() == .OK, let url = panel.url else { return nil }

            do {
                try data.write(to: url)
                return url
            } catch {
                return nil
            }
        }
    }

    // MARK: - Private

    private func csvEscape(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n")
        if needsQuoting {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}

// MARK: - ExportFileType

enum ExportFileType {
    case csv
    case pdf

    var utType: UTType {
        switch self {
        case .csv: return .commaSeparatedText
        case .pdf: return .pdf
        }
    }

    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .pdf: return "pdf"
        }
    }
}
