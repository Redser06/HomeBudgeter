import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@Observable
class DocumentsViewModel {
    var documents: [Document] = []
    var selectedDocument: Document?
    var showingFilePicker = false
    var showingDocumentPreview = false
    var isProcessing = false
    var processingProgress: Double = 0

    private let encryptionService = FileEncryptionService.shared

    /// Whether encryption is enabled in user preferences.
    private var isEncryptionEnabled: Bool {
        UserDefaults.standard.bool(forKey: "encryptDocuments")
    }

    var searchText: String = "" {
        didSet { applyFilters() }
    }

    var selectedType: DocumentType? {
        didSet { applyFilters() }
    }

    private var filteredDocuments: [Document] = []

    var displayedDocuments: [Document] {
        filteredDocuments.isEmpty && searchText.isEmpty && selectedType == nil
            ? documents
            : filteredDocuments
    }

    var documentsByType: [DocumentType: [Document]] {
        Dictionary(grouping: documents) { $0.documentType }
    }

    var totalStorageUsed: Int64 {
        documents.reduce(0) { $0 + $1.fileSize }
    }

    var formattedStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: totalStorageUsed, countStyle: .file)
    }

    func loadDocuments(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Document>(
            sortBy: [SortDescriptor(\.uploadDate, order: .reverse)]
        )

        do {
            documents = try modelContext.fetch(descriptor)
            applyFilters()
        } catch {
            print("Error loading documents: \(error)")
        }
    }

    private func applyFilters() {
        var result = documents

        if let type = selectedType {
            result = result.filter { $0.documentType == type }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.filename.localizedCaseInsensitiveContains(searchText) ||
                $0.notes?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        filteredDocuments = result
    }

    func importDocument(from url: URL, modelContext: ModelContext) async throws {
        isProcessing = true
        processingProgress = 0

        defer { isProcessing = false }

        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            throw DocumentError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // Get file attributes
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        processingProgress = 0.3

        // Create documents directory if needed
        let documentsPath = getDocumentsDirectory()
        try FileManager.default.createDirectory(at: documentsPath, withIntermediateDirectories: true)

        // Copy file to app's documents directory
        let destinationURL = documentsPath.appendingPathComponent(UUID().uuidString + "_" + url.lastPathComponent)
        try FileManager.default.copyItem(at: url, to: destinationURL)

        processingProgress = 0.6

        // Encrypt if enabled
        var finalURL = destinationURL
        var finalSize = fileSize
        if isEncryptionEnabled {
            let fileData = try Data(contentsOf: destinationURL)
            let encryptedData = try encryptionService.encrypt(data: fileData)
            let encryptedURL = destinationURL.appendingPathExtension("encrypted")
            try encryptedData.write(to: encryptedURL)
            try FileManager.default.removeItem(at: destinationURL)
            finalURL = encryptedURL
            finalSize = Int64(encryptedData.count)
        }

        processingProgress = 0.7

        // Create document record
        let document = Document(
            filename: url.lastPathComponent,
            localPath: finalURL.path,
            documentType: inferDocumentType(from: url.lastPathComponent),
            fileSize: finalSize,
            mimeType: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        )

        modelContext.insert(document)
        try modelContext.save()

        processingProgress = 1.0

        await MainActor.run {
            documents.insert(document, at: 0)
        }
    }

    /// Returns the document's file data, decrypting if the file is encrypted.
    func documentData(for document: Document) throws -> Data {
        let url = URL(fileURLWithPath: document.localPath)
        let data = try Data(contentsOf: url)

        if document.localPath.hasSuffix(".encrypted") {
            return try encryptionService.decrypt(data: data)
        }
        return data
    }

    func deleteDocument(_ document: Document, modelContext: ModelContext) {
        // Delete file from disk
        let fileURL = URL(fileURLWithPath: document.localPath)
        try? FileManager.default.removeItem(at: fileURL)

        // Delete from database
        modelContext.delete(document)
        try? modelContext.save()

        documents.removeAll { $0.id == document.id }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HomeBudgeter")
            .appendingPathComponent("Documents")
    }

    private func inferDocumentType(from filename: String) -> DocumentType {
        let lowercased = filename.lowercased()

        if lowercased.contains("payslip") || lowercased.contains("salary") || lowercased.contains("wage") {
            return .payslip
        } else if lowercased.contains("bill") || lowercased.contains("utility") {
            return .bill
        } else if lowercased.contains("invoice") {
            return .invoice
        } else if lowercased.contains("receipt") {
            return .receipt
        } else if lowercased.contains("statement") || lowercased.contains("bank") {
            return .statement
        } else if lowercased.contains("tax") || lowercased.contains("p60") || lowercased.contains("p45") {
            return .tax
        }

        return .other
    }
}

enum DocumentError: LocalizedError {
    case accessDenied
    case copyFailed
    case invalidFile

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "Could not access the file"
        case .copyFailed: return "Failed to copy the file"
        case .invalidFile: return "The file is invalid or corrupted"
        }
    }
}
