//
//  iOSSettingsView.swift
//  Seahorse
//

#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers
import ZipArchive

struct iOSSettingsView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @EnvironmentObject var appearanceManager: AppearanceManager
    @StateObject private var aiSettings = AISettings.shared
    @State private var isImporting = false
    @State private var importError: String?
    @State private var importSuccess: String?
    @State private var isImportingInProgress = false

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Theme", selection: $appearanceManager.selectedMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }

                Section("Data") {
                    Button(action: { isImporting = true }) {
                        HStack {
                            Label("Import Data", systemImage: "square.and.arrow.down")
                            if isImportingInProgress {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isImportingInProgress)
                }

                Section("AI") {
                    Toggle("Auto AI Parsing", isOn: $aiSettings.autoParsingEnabled)
                    if aiSettings.autoParsingEnabled {
                        Toggle("Create New Categories", isOn: $aiSettings.autoParsingCreateCategories)
                        Toggle("Create New Tags", isOn: $aiSettings.autoParsingCreateTags)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    LabeledContent("Items", value: "\(dataStorage.items.count)")
                    LabeledContent("Categories", value: "\(dataStorage.categories.count)")
                    LabeledContent("Tags", value: "\(dataStorage.tags.count)")
                }
            }
            .navigationTitle("Settings")
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.zip, .folder],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert("Import Error", isPresented: .constant(importError != nil)) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
            .alert("Import Successful", isPresented: .constant(importSuccess != nil)) {
                Button("OK") { importSuccess = nil }
            } message: {
                Text(importSuccess ?? "")
            }
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()

            if url.pathExtension.lowercased() == "zip" {
                importFromZip(url, accessed: accessing)
            } else {
                importFromFolder(url, accessed: accessing)
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func importFromZip(_ zipURL: URL, accessed: Bool) {
        isImportingInProgress = true

        Task {
            defer {
                if accessed { zipURL.stopAccessingSecurityScopedResource() }
            }

            do {
                let tempDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: tempDir) }

                guard SSZipArchive.unzipFile(atPath: zipURL.path, toDestination: tempDir.path) else {
                    throw NSError(domain: "ZIP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract ZIP file"])
                }

                let exportDir = findExportRoot(in: tempDir)
                try await performImport(from: exportDir)
            } catch {
                await MainActor.run {
                    isImportingInProgress = false
                    importError = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func importFromFolder(_ folderURL: URL, accessed: Bool) {
        isImportingInProgress = true

        Task {
            defer {
                if accessed { folderURL.stopAccessingSecurityScopedResource() }
            }
            do {
                try await performImport(from: folderURL)
            } catch {
                await MainActor.run {
                    isImportingInProgress = false
                    importError = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func findExportRoot(in dir: URL) -> URL {
        let fm = FileManager.default
        if fm.fileExists(atPath: dir.appendingPathComponent("Data").path) {
            return dir
        }
        if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for child in contents where child.hasDirectoryPath {
                if fm.fileExists(atPath: child.appendingPathComponent("Data").path) {
                    return child
                }
            }
        }
        return dir
    }

    private func performImport(from folderURL: URL) async throws {
        let fileManager = FileManager.default
        let dataDir = folderURL.appendingPathComponent("Data", isDirectory: true)
        let imagesDir = folderURL.appendingPathComponent("Images", isDirectory: true)

        guard fileManager.fileExists(atPath: dataDir.path) else {
            await MainActor.run {
                isImportingInProgress = false
                importError = "Invalid export format: Data directory not found"
            }
            return
        }

        let decoder = JSONDecoder()

        let itemsURL = dataDir.appendingPathComponent("items.json")
        guard fileManager.fileExists(atPath: itemsURL.path) else {
            await MainActor.run {
                isImportingInProgress = false
                importError = "Invalid export format: items.json not found"
            }
            return
        }
        let items = try decoder.decode([AnyCollectionItem].self, from: Data(contentsOf: itemsURL))

        var categories: [Category] = []
        let categoriesURL = dataDir.appendingPathComponent("categories.json")
        if fileManager.fileExists(atPath: categoriesURL.path) {
            categories = try decoder.decode([Category].self, from: Data(contentsOf: categoriesURL))
        }

        var tags: [Tag] = []
        let tagsURL = dataDir.appendingPathComponent("tags.json")
        if fileManager.fileExists(atPath: tagsURL.path) {
            tags = try decoder.decode([Tag].self, from: Data(contentsOf: tagsURL))
        }

        var imagesCopied = 0
        if fileManager.fileExists(atPath: imagesDir.path) {
            let destImagesDir = StorageManager.shared.getImagesDirectory()
            try fileManager.createDirectory(at: destImagesDir, withIntermediateDirectories: true)
            let imageFiles = try fileManager.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)
            for imageFile in imageFiles {
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: imageFile.path, isDirectory: &isDir), !isDir.boolValue else { continue }
                let dest = destImagesDir.appendingPathComponent(imageFile.lastPathComponent)
                guard !fileManager.fileExists(atPath: dest.path) else { continue }
                try fileManager.copyItem(at: imageFile, to: dest)
                imagesCopied += 1
            }
        }

        await MainActor.run {
            for category in categories {
                if !dataStorage.categories.contains(where: { $0.name.lowercased() == category.name.lowercased() }) {
                    try? dataStorage.addCategory(category)
                }
            }
            for tag in tags {
                if !dataStorage.tags.contains(where: { $0.name.lowercased() == tag.name.lowercased() }) {
                    try? dataStorage.addTag(tag)
                }
            }
            for item in items {
                if !dataStorage.items.contains(where: { $0.id == item.id }) {
                    dataStorage.addItem(item)
                }
            }

            isImportingInProgress = false
            var msg = "Imported \(items.count) items, \(categories.count) categories, \(tags.count) tags"
            if imagesCopied > 0 { msg += ", \(imagesCopied) images" }
            importSuccess = msg
        }
    }
}

#endif
