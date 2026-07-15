#if os(macOS)
import SwiftUI

struct SmartCollectionEditorView: View {
    @EnvironmentObject private var dataStorage: DataStorage
    @Environment(\.dismiss) private var dismiss

    private let original: SmartCollection?
    @State private var name: String
    @State private var query: String
    @State private var itemType: CollectionItemType?
    @State private var categoryId: UUID?
    @State private var tagIds: Set<UUID>
    @State private var matchesAllTags: Bool
    @State private var favoriteOnly: Bool
    @State private var dateFilter: SmartCollectionDateFilter
    @State private var customStartDate: Date
    @State private var customEndDate: Date
    @State private var sortOption: SortOption
    @State private var errorMessage: String?

    init(smartCollection: SmartCollection?) {
        original = smartCollection
        _name = State(initialValue: smartCollection?.name ?? "")
        _query = State(initialValue: smartCollection?.query ?? "")
        _itemType = State(initialValue: smartCollection?.itemType)
        _categoryId = State(initialValue: smartCollection?.categoryId)
        _tagIds = State(initialValue: Set(smartCollection?.tagIds ?? []))
        _matchesAllTags = State(initialValue: smartCollection?.matchesAllTags ?? false)
        _favoriteOnly = State(initialValue: smartCollection?.favoriteOnly ?? false)
        _dateFilter = State(initialValue: smartCollection?.dateFilter ?? .anyTime)
        _customStartDate = State(initialValue: smartCollection?.customStartDate ?? Date())
        _customEndDate = State(initialValue: smartCollection?.customEndDate ?? Date())
        _sortOption = State(initialValue: smartCollection?.sortOption ?? .newestFirst)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Smart collection name", text: $name)
                }

                Section("Rules") {
                    TextField("Search terms", text: $query)

                    Picker("Content Type", selection: $itemType) {
                        Text("All").tag(nil as CollectionItemType?)
                        ForEach(CollectionItemType.allCases) { type in
                            Text(label(for: type)).tag(Optional(type))
                        }
                    }

                    Picker("Category", selection: $categoryId) {
                        Text("Any Category").tag(nil as UUID?)
                        ForEach(filterableCategories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }

                    Toggle("Favorites Only", isOn: $favoriteOnly)

                    Picker("Added", selection: $dateFilter) {
                        ForEach(SmartCollectionDateFilter.allCases) { filter in
                            Text(label(for: filter)).tag(filter)
                        }
                    }

                    if dateFilter == .custom {
                        DatePicker("From", selection: $customStartDate, displayedComponents: .date)
                        DatePicker("Through", selection: $customEndDate, displayedComponents: .date)
                    }
                }

                Section("Tags") {
                    if dataStorage.tags.isEmpty {
                        Text("No tags available")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedTags) { tag in
                            Button {
                                if !tagIds.insert(tag.id).inserted {
                                    tagIds.remove(tag.id)
                                }
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(tag.color)
                                        .frame(width: 10, height: 10)
                                    Text(tag.name)
                                    Spacer()
                                    if tagIds.contains(tag.id) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if tagIds.count > 1 {
                        Toggle("Require All Selected Tags", isOn: $matchesAllTags)
                    }
                }

                Section("Sort") {
                    Picker("Order", selection: $sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(original == nil ? "New Smart Collection" : "Edit Smart Collection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 620)
    }

    private var filterableCategories: [Category] {
        dataStorage.categories.filter { $0.name != "All Bookmarks" && $0.name != "Favorites" }
    }

    private var sortedTags: [Tag] {
        dataStorage.tags.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dataStorage.smartCollectionNameExists(name: trimmedName, excluding: original?.id) else {
            errorMessage = "A smart collection with this name already exists."
            return
        }
        guard dateFilter != .custom || customStartDate <= customEndDate else {
            errorMessage = "The start date must not be after the end date."
            return
        }

        let smartCollection = SmartCollection(
            id: original?.id ?? UUID(),
            name: trimmedName,
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            itemType: itemType,
            categoryId: categoryId,
            tagIds: sortedTags.map(\.id).filter(tagIds.contains),
            matchesAllTags: matchesAllTags,
            favoriteOnly: favoriteOnly,
            dateFilter: dateFilter,
            customStartDate: dateFilter == .custom ? customStartDate : nil,
            customEndDate: dateFilter == .custom ? customEndDate : nil,
            sortOption: sortOption,
            createdAt: original?.createdAt ?? Date()
        )

        do {
            if original == nil {
                try dataStorage.addSmartCollection(smartCollection)
            } else {
                try dataStorage.updateSmartCollection(smartCollection)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func label(for type: CollectionItemType) -> String {
        switch type {
        case .bookmark: "Bookmarks"
        case .image: "Images"
        case .text: "Notes"
        }
    }

    private func label(for filter: SmartCollectionDateFilter) -> String {
        switch filter {
        case .anyTime: "Any Time"
        case .today: "Today"
        case .lastSevenDays: "Last 7 Days"
        case .lastThirtyDays: "Last 30 Days"
        case .custom: "Custom Range"
        }
    }
}
#endif
