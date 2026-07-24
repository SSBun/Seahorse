#if os(macOS)
//
//  AddBookmarkView.swift
//  Seahorse
//
//  Created by caishilin on 2025/11/14.
//

import SwiftUI
import Kingfisher
import AppKit

struct AddBookmarkView: View {
    @EnvironmentObject var dataStorage: DataStorage
    @Environment(\.dismiss) var dismiss
    
    @State private var urlString = ""
    @State private var title = ""
    @State private var summary = ""
    @State private var selectedCategoryId: UUID?
    @State private var selectedTagIds: Set<UUID> = []
    @State private var isFavorite = false
    @State private var iconURL: String? = nil
    @State private var webMetadata: WebMetadata? = nil // OGP/Twitter Data
    @StateObject private var parsingSession = BookmarkParsingSession()
    @State private var parsingTask: Task<Void, Never>?
    @State private var isFetchingMetadata = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var wasParsed = false // Track if bookmark was AI-parsed
    @State private var showingToast = false
    @State private var toastMessage = ""
    
    @State private var showingNewItemsDialog = false
    @State private var suggestedNewCategory: String?
    @State private var suggestedNewTags: [String] = []
    @State private var selectedNewCategory = false
    @State private var selectedNewTags: Set<String> = []
    @State private var hasManuallySelectedCategory = false

    private var isBusy: Bool {
        parsingSession.isRunning || isFetchingMetadata
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Bookmark")
                    .font(.system(size: 20, weight: .semibold))
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // URL Input with Parse Button
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("URL")
                                    .font(.system(size: 13, weight: .semibold))
                                
                                HStack {
                                    TextField("https://example.com", text: $urlString)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .disabled(isBusy)
                                    
                                    Button(action: {
                                        Task {
                                            await fetchMetadataOnly()
                                        }
                                    }) {
                                        Label("Fetch Info", systemImage: "link")
                                    }
                                    .disabled(urlString.isEmpty || isBusy)
                                    
                                    Button(action: parseURL) {
                                        Label(parsingSession.isRunning ? "Parsing..." : "AI Parse", systemImage: "sparkles")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(urlString.isEmpty || isBusy)
                                }
                            }
                        }
                        
                        Text("Enter the bookmark URL and click Parse to automatically fetch content and suggestions")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        BookmarkParsingProgressView(session: parsingSession)
                    }
                    
                    Divider()

                    // Poster Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.system(size: 13, weight: .semibold))

                        HStack {
                            Spacer()
                            posterPreview
                            Spacer()
                        }
                    }

                    Divider()

                    // Icon & Title
                    HStack(alignment: .top, spacing: 16) {
                        // Icon Preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icon")
                                .font(.headline)
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(
                                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 80, height: 80)
                                
                                // Fixed icon preview - no loading states
                                Image(systemName: "link")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.system(size: 13, weight: .semibold))
                            
                            TextField("Bookmark title", text: $title)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 13))
                        }
                    }
                    
                    // Summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.system(size: 13, weight: .semibold))
                        
                        ZStack(alignment: .topLeading) {
                            if summary.isEmpty {
                                Text("Click Parse to generate an AI summary, or write your own...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 10)
                            }
                            
                            TextEditor(text: $summary)
                                .font(.system(size: 13))
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                )
                        }
                    }
                    
                    Divider()
                    
                    // Category Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category")
                            .font(.system(size: 13, weight: .semibold))
                        
                        FlowLayout(spacing: 10) {
                            ForEach(dataStorage.categories) { category in
                                // Skip "All Bookmarks" and "Favorites"
                                if category.name != "All Bookmarks" && category.name != "Favorites" {
                                    CategorySelectionButton(
                                        category: category,
                                        isSelected: selectedCategoryId == category.id,
                                        onSelect: {
                                            selectedCategoryId = category.id
                                            hasManuallySelectedCategory = true
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Tag Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(.system(size: 13, weight: .semibold))
                        
                        if dataStorage.tags.isEmpty {
                            Text("No tags available. Create tags in Settings.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(dataStorage.tags) { tag in
                                    TagSelectionButton(
                                        tag: tag,
                                        isSelected: selectedTagIds.contains(tag.id),
                                        onToggle: {
                                            if selectedTagIds.contains(tag.id) {
                                                selectedTagIds.remove(tag.id)
                                            } else {
                                                selectedTagIds.insert(tag.id)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Favorite Toggle
                    HStack {
                        Toggle(isOn: $isFavorite) {
                            HStack(spacing: 8) {
                                Image(systemName: isFavorite ? "star.fill" : "star")
                                    .font(.system(size: 14))
                                    .foregroundStyle(isFavorite ? .yellow : .secondary)
                                Text("Add to Favorites")
                                    .font(.system(size: 13))
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add Bookmark") {
                    saveBookmark()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(urlString.isEmpty || title.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 700)
        .onAppear {
            setDefaultCategory()
        }
        .onChange(of: urlString) { _, _ in
            // Keep the default category until the user or parsing flow selects one.
            if !hasManuallySelectedCategory {
                setDefaultCategory()
            }
        }
        .onDisappear {
            parsingTask?.cancel()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingNewItemsDialog) {
            NewItemsConfirmationView(
                suggestedNewCategory: suggestedNewCategory,
                suggestedNewTags: suggestedNewTags,
                selectedNewCategory: $selectedNewCategory,
                selectedNewTags: $selectedNewTags,
                onConfirm: {
                    createAndUseNewItems()
                    showingNewItemsDialog = false
                },
                onCancel: {
                    clearNewItemSelections()
                    showingNewItemsDialog = false
                    toastMessage = "✨ Parsing completed successfully!"
                    showingToast = true
                }
            )
        }
        .toast(isPresented: $showingToast, message: toastMessage, icon: "checkmark.circle.fill")
    }

    // MARK: - Poster Preview

    /// Mirrors the actual StandardCardView appearance exactly.
    /// Reads imageURL live from dataStorage to reflect snapshot/crop changes.
    @ViewBuilder
    private var posterPreview: some View {
        let displayTitle = title.isEmpty ? "Untitled" : title
        let resolvedIcon: String = iconURL ?? "link.circle.fill"
        let categoryName = dataStorage.categories.first(where: { $0.id == selectedCategoryId })?.name
        let categoryColorHex = dataStorage.categories.first(where: { $0.id == selectedCategoryId })?.colorHex
        let categoryColor = categoryColorHex.flatMap { Color(hex: $0) } ?? .blue
        let tags = dataStorage.tags.filter { selectedTagIds.contains($0.id) }

        // Read imageURL live from dataStorage so snapshot changes are reflected
        let imageURL = webMetadata?.imageURL

        ZStack(alignment: .bottom) {
            // Layer 1: OGP poster image if available, otherwise gradient + icon (matching StandardCardView previewArea)
            ZStack {
                // Fallback gradient + icon (same as StandardCardView)
                LinearGradient(
                    colors: [Color.blue.opacity(0.5), Color.purple.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "link.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary.opacity(0.5))

                // Overlay the poster image if available (handles both HTTP URLs and local snapshot paths)
                if let imageURL = imageURL {
                    if let url = URL(string: imageURL),
                       url.scheme == "http" || url.scheme == "https" {
                        // Remote URL
                        KFImage.url(url)
                            .placeholder { Color.clear }
                            .onFailure { _ in }
                            .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 400, height: 300)))
                            .scaleFactor(NSScreen.main?.backingScaleFactor ?? 2.0)
                            .cacheOriginalImage()
                            .fade(duration: 0.25)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    } else {
                        // Local snapshot path - resolve via StorageManager
                        let resolvedPath = StorageManager.shared.resolveImagePath(imageURL)
                        KFImage.url(URL(fileURLWithPath: resolvedPath))
                            .placeholder { Color.clear }
                            .onFailure { _ in }
                            .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 400, height: 300)))
                            .scaleFactor(NSScreen.main?.backingScaleFactor ?? 2.0)
                            .cacheOriginalImage()
                            .fade(duration: 0.25)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Layer 2: Bottom overlay (matching StandardCardView bottomContainer)
            VStack(spacing: 0) {
                // Title - left-aligned, matching StandardCardView
                Text(displayTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 20, alignment: .top)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                    .padding(.bottom, 2)

                // Metadata bar
                HStack(spacing: 5) {
                    // Favorite star
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 10))
                        .foregroundStyle(isFavorite ? .yellow : .secondary)

                    // Category tag
                    if let name = categoryName, name != "All Bookmarks", name != "Favorites" {
                        Text("#\(name.lowercased())")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(categoryColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(categoryColor.opacity(0.1))
                            .cornerRadius(3)
                    }

                    // Tags
                    ForEach(Array(tags.prefix(2).enumerated()), id: \.element.id) { index, tag in
                        let tagColor = Color(hex: tag.colorHex) ?? .blue
                        Text("#\(tag.name.lowercased())")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(tagColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(tagColor.opacity(0.1))
                            .cornerRadius(3)
                    }

                    Spacer()

                    // Type badge
                    HStack(spacing: 3) {
                        Image(systemName: "link")
                            .font(.system(size: 8))
                        Text("Link")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(height: 28)
            }
            .background {
                Rectangle()
                    .fill(Color.black.opacity(0.5))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .aspectRatio(4/3, contentMode: .fit)
        .frame(width: 200)
    }

    private func parseURL() {
        let fillsTitle = BookmarkParsingPolicy.isPlaceholderTitle(title)
        let fillsSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let fillsTags = selectedTagIds.isEmpty

        parsingTask?.cancel()
        parsingTask = Task {
            do {
                let categories = dataStorage.categories
                    .filter { $0.name != "All Bookmarks" && $0.name != "Favorites" }
                let output = try await parsingSession.parse(
                    url: urlString,
                    categories: categories,
                    tags: dataStorage.tags
                )

                let resolution = output.resolution
                if fillsTitle {
                    title = resolution.refinedTitle.isEmpty
                        ? output.fetchedTitle
                        : resolution.refinedTitle
                }
                if iconURL == nil {
                    iconURL = output.faviconURL ?? resolution.suggestedSFSymbol
                }
                if let metadata = output.metadata {
                    webMetadata = metadata
                    if BookmarkParsingPolicy.isPlaceholderTitle(title) {
                        title = metadata.title ?? title
                    }
                    if fillsSummary, resolution.summary.isEmpty {
                        summary = metadata.description ?? ""
                    }
                }
                if fillsSummary, !resolution.summary.isEmpty {
                    summary = resolution.summary
                }

                var newCategory: String?
                if !hasManuallySelectedCategory, let existingCategory = resolution.category {
                    selectedCategoryId = existingCategory.id
                } else if !hasManuallySelectedCategory {
                    newCategory = resolution.suggestedNewCategoryName
                }

                var newTags: [String] = []
                if fillsTags {
                    selectedTagIds.formUnion(resolution.existingTags.map(\.id))
                    newTags = resolution.suggestedNewTagNames
                }

                wasParsed = true
                if newCategory != nil || !newTags.isEmpty {
                    suggestedNewCategory = newCategory
                    suggestedNewTags = newTags
                    selectedNewCategory = newCategory != nil
                    selectedNewTags = Set(newTags)
                    showingNewItemsDialog = true
                } else {
                    toastMessage = "✨ Parsing completed successfully!"
                    showingToast = true
                }
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func fetchMetadataOnly() async {
        guard let url = URL(string: urlString) else { return }
        
        isFetchingMetadata = true
        defer { isFetchingMetadata = false }
        
        do {
            let metadata = try await OpenGraphService.shared.fetchMetadata(url: url)
            print("Fetched Metadata: \(metadata)")
            
            await MainActor.run {
                self.webMetadata = metadata
                
                // Overwrite fields with OGP data
                if let ogTitle = metadata.title, !ogTitle.isEmpty {
                    title = ogTitle
                }
                
                if let ogDescription = metadata.description, !ogDescription.isEmpty {
                    summary = ogDescription
                }
                
                if let favicon = metadata.faviconURL {
                    iconURL = favicon
                }
                
                // If we found a site name, maybe use it as a default category or tag?
                // For now, just leaving it in metadata
            }
        } catch {
            print("Failed to fetch metadata: \(error)")
        }
    }
    
    private func clearNewItemSelections() {
        suggestedNewCategory = nil
        suggestedNewTags = []
        selectedNewCategory = false
        selectedNewTags.removeAll()
    }

    private func createAndUseNewItems() {
        // Create new category if selected
        if selectedNewCategory, let newCategoryName = suggestedNewCategory {
            do {
                selectedCategoryId = try createCategoryIfNeeded(named: newCategoryName)
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
                return
            }
        }
        
        // Create new tags if selected
        do {
            let selectedNames = suggestedNewTags.filter { selectedNewTags.contains($0) }
            let newTagIDs = try dataStorage.createTagsIfNeeded(named: selectedNames)
            selectedTagIds.formUnion(newTagIDs)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            return
        }
        
        clearNewItemSelections()
        
        // Show success toast
        toastMessage = "✨ Parsing completed successfully!"
        showingToast = true
    }

    private func createCategoryIfNeeded(named name: String) throws -> UUID {
        if let category = dataStorage.category(named: name) {
            return category.id
        }
        let category = Category(name: name, icon: "folder.fill", color: .blue)
        try dataStorage.addCategory(category)
        return category.id
    }
    
    private func setDefaultCategory() {
        if let noneCategory = dataStorage.categories.first(where: { $0.name == "None" }) {
            selectedCategoryId = noneCategory.id
        }
    }
    
    private func saveBookmark() {
        guard !urlString.isEmpty, !title.isEmpty else { return }
        
        // Ensure a category is selected
        let categoryId = selectedCategoryId ?? {
            if let noneCategory = dataStorage.categories.first(where: { $0.name == "None" }) {
                return noneCategory.id
            }
            return dataStorage.categories.first?.id ?? UUID()
        }()
        
        let bookmark = Bookmark(
            title: title,
            url: urlString,
            icon: iconURL ?? "link.circle.fill",
            categoryId: categoryId,
            isFavorite: isFavorite,
            notes: summary.isEmpty ? nil : summary,
            tagIds: Array(selectedTagIds),
            isParsed: wasParsed,
            metadata: webMetadata
        )
        
        do {
            try dataStorage.addBookmark(bookmark)
            dismiss()
        } catch DatabaseError.duplicateBookmarkURL {
            toastMessage = "Bookmark already collected"
            showingToast = true
            NotificationCenter.default.post(name: .seahorseDuplicateBookmarkDetected, object: bookmark.id)
            NotificationService.shared.showBookmarkAlreadyCollectedNotification(for: AnyCollectionItem(bookmark))
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Supporting Views

struct CategorySelectionButton: View {
    let category: Category
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12))
                Text(category.name)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? category.color.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? category.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TagSelectionButton: View {
    let tag: Tag
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11))
                Text(tag.name)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? tag.color.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? tag.color : Color(NSColor.separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowLayoutResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowLayoutResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowLayoutResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    AddBookmarkView()
        .environmentObject(DataStorage.shared)
}


#endif
