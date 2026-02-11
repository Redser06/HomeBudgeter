import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DocumentsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DocumentsViewModel()
    @State private var showingFilePicker = false
    @State private var selectedDocument: Document?

    var body: some View {
        VStack(spacing: 0) {
            toolbarArea

            if viewModel.documents.isEmpty {
                emptyState
            } else {
                documentGrid
            }
        }
        .background(Color.appBackground)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingFilePicker = true }) {
                    Label("Upload Document", systemImage: "arrow.up.doc.fill")
                }
            }
        }
        .onAppear {
            viewModel.loadDocuments(modelContext: modelContext)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf, .spreadsheet, .presentation],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(item: $selectedDocument) { document in
            DocumentDetailView(document: document) {
                viewModel.deleteDocument(document, modelContext: modelContext)
            }
        }
    }

    private var toolbarArea: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search documents...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 300)

            Picker("Type", selection: $viewModel.selectedType) {
                Text("All Types").tag(nil as DocumentType?)
                ForEach(DocumentType.allCases, id: \.self) { type in
                    Label(type.rawValue, systemImage: type.icon).tag(type as DocumentType?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "internaldrive").foregroundStyle(.secondary)
                Text("\(viewModel.documents.count) documents").foregroundStyle(.secondary)
                Text("•").foregroundStyle(.secondary)
                Text(viewModel.formattedStorageUsed).foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color.cardBackground)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Documents", systemImage: "doc.fill")
        } description: {
            Text("Upload your first document to get started")
        } actions: {
            Button("Upload Document") { showingFilePicker = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var documentGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 250))], spacing: 16) {
                ForEach(viewModel.displayedDocuments) { document in
                    DocumentCard(document: document)
                        .onTapGesture { selectedDocument = document }
                        .contextMenu {
                            Button("Open") { openDocument(document) }
                            Button("Show in Finder") { showInFinder(document) }
                            Divider()
                            Button("Delete", role: .destructive) {
                                viewModel.deleteDocument(document, modelContext: modelContext)
                            }
                        }
                }
            }
            .padding()
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                try? await viewModel.importDocument(from: url, modelContext: modelContext)
            }
        case .failure(let error):
            print("File picker error: \(error)")
        }
    }

    private func openDocument(_ document: Document) {
        NSWorkspace.shared.open(URL(fileURLWithPath: document.localPath))
    }

    private func showInFinder(_ document: Document) {
        NSWorkspace.shared.selectFile(document.localPath, inFileViewerRootedAtPath: "")
    }
}

struct DocumentCard: View {
    let document: Document

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: document.documentType.icon)
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
                Spacer()
                Text(document.documentType.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }

            Text(document.filename)
                .font(.headline)
                .lineLimit(2)
                .truncationMode(.middle)

            HStack {
                Text(document.formattedUploadDate).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(document.formattedFileSize).font(.caption).foregroundStyle(.secondary)
            }

            if document.isProcessed {
                Label("Processed", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
            } else {
                Label("Not processed", systemImage: "clock")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct DocumentDetailView: View {
    @Bindable var document: Document
    @Environment(\.dismiss) private var dismiss
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay {
                        Image(systemName: document.documentType.icon)
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 300)

                Form {
                    Section("Document Info") {
                        LabeledContent("Filename", value: document.filename)
                        LabeledContent("Type", value: document.documentType.rawValue)
                        LabeledContent("Size", value: document.formattedFileSize)
                        LabeledContent("Uploaded", value: document.formattedUploadDate)
                    }

                    Section("Notes") {
                        TextEditor(text: Binding(
                            get: { document.notes ?? "" },
                            set: { document.notes = $0.isEmpty ? nil : $0 }
                        ))
                        .frame(minHeight: 80)
                    }

                    Section {
                        Button("Open in Preview") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: document.localPath))
                        }
                        Button("Show in Finder") {
                            NSWorkspace.shared.selectFile(document.localPath, inFileViewerRootedAtPath: "")
                        }
                        Button("Delete Document", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Document Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }
}

#Preview {
    DocumentsView()
        .modelContainer(for: Document.self, inMemory: true)
}
