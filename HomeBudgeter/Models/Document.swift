import Foundation
import SwiftData

enum DocumentType: String, Codable, CaseIterable {
    case payslip = "Payslip"
    case bill = "Bill"
    case invoice = "Invoice"
    case receipt = "Receipt"
    case statement = "Statement"
    case tax = "Tax Document"
    case other = "Other"

    var icon: String {
        switch self {
        case .payslip: return "doc.text.fill"
        case .bill: return "doc.plaintext.fill"
        case .invoice: return "doc.richtext.fill"
        case .receipt: return "receipt.fill"
        case .statement: return "list.bullet.rectangle.fill"
        case .tax: return "building.columns.fill"
        case .other: return "doc.fill"
        }
    }
}

@Model
final class Document {
    @Attribute(.unique) var id: UUID
    var filename: String
    var localPath: String
    var uploadDate: Date
    var documentType: DocumentType
    var fileSize: Int64
    var mimeType: String
    var isProcessed: Bool
    var extractedData: String?
    var notes: String?
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Transaction.linkedDocument)
    var linkedTransaction: Transaction?

    var linkedPayslip: Payslip?

    init(
        filename: String,
        localPath: String,
        documentType: DocumentType = .other,
        fileSize: Int64 = 0,
        mimeType: String = "application/pdf"
    ) {
        self.id = UUID()
        self.filename = filename
        self.localPath = localPath
        self.uploadDate = Date()
        self.documentType = documentType
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.isProcessed = false
        self.createdAt = Date()
    }

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var formattedUploadDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: uploadDate)
    }
}
