# Performance Optimization Guide for Card List View

## Identified Performance Issues

### 1. **Computed Properties Recalculated on Every Render**
- `StandardCardView` and `StandardListItemView` have many computed properties that are recalculated even when the item hasn't changed
- Properties like `displayTitle`, `displayDomain`, `categoryId`, `tagIds`, etc. are recalculated on every SwiftUI render

### 2. **Repeated DataStorage Lookups**
- Each card performs `dataStorage.categories.first(where:)` and `dataStorage.tags.first(where:)` lookups
- With many items, this creates O(n*m) complexity where n = items, m = categories/tags

### 3. **Image Loading Not Optimized**
- List view thumbnails load full-resolution images without proper downsampling
- Remote images don't use appropriate cache strategies
- Local images are loaded synchronously with `NSImage(contentsOfFile:)`

### 4. **Complex View Hierarchies**
- Multiple nested ZStacks, GeometryReaders, and conditional views
- Material effects and blur operations are expensive

### 5. **No View Identity Optimization**
- SwiftUI may recreate views unnecessarily if identity isn't stable
- `AnyCollectionItem` doesn't conform to `Hashable` or `Equatable`

### 6. **Filtered Items Recalculated**
- `filteredItems` computed property in `ContentView` recalculates on every render
- Complex filtering logic runs repeatedly

---

## Optimization Recommendations

### Priority 1: Critical Optimizations

#### 1.1 Add Equatable Conformance to AnyCollectionItem

**File**: `Seahorse/Models/AnyCollectionItem.swift`

```swift
extension AnyCollectionItem: Equatable {
    static func == (lhs: AnyCollectionItem, rhs: AnyCollectionItem) -> Bool {
        lhs.id == rhs.id
    }
}

extension AnyCollectionItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

**Impact**: SwiftUI can better identify unchanged views and skip unnecessary redraws.

---

#### 1.2 Cache Category and Tag Lookups

**File**: `Seahorse/Views/Cards/StandardCardView.swift`

Create a helper to pre-compute category/tag lookups:

```swift
struct StandardCardView: View {
    // ... existing code ...
    
    // Add cached lookups
    private var category: Category? {
        dataStorage.categories.first(where: { $0.id == categoryId })
    }
    
    private var tags: [Tag] {
        tagIds.compactMap { tagId in
            dataStorage.tags.first(where: { $0.id == tagId })
        }
    }
    
    // Update bottomContainer to use cached tags
    private var bottomContainer: some View {
        // ... existing code ...
        ForEach(Array(tags.enumerated()), id: \.element.id) { index, tag in
            // Use tag directly instead of lookup
        }
    }
}
```

**Impact**: Reduces O(n*m) lookups to O(n) with caching.

---

#### 1.3 Optimize Image Loading in List View

**File**: `Seahorse/Views/Lists/StandardListItemView.swift`

```swift
// Replace lines 79-91 with:
if let url = URL(string: imageItem.imagePath), (url.scheme == "http" || url.scheme == "https") {
    KFImage(url)
        .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 40, height: 40)))
        .cacheMemoryOnly()
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 6))
} else if let nsImage = NSImage(contentsOfFile: resolvedPath) {
    // For local images, create thumbnail
    let thumbnail = nsImage.resized(to: CGSize(width: 40, height: 40))
    Image(nsImage: thumbnail)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 6))
}
```

**Add NSImage extension** (create new file or add to utilities):

```swift
extension NSImage {
    func resized(to size: CGSize) -> NSImage {
        let resized = NSImage(size: size)
        resized.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: size),
                 from: NSRect(origin: .zero, size: self.size),
                 operation: .sourceOver,
                 fraction: 1.0)
        resized.unlockFocus()
        return resized
    }
}
```

**Impact**: Reduces memory usage and improves scrolling performance.

---

#### 1.4 Memoize Filtered Items

**File**: `Seahorse/ContentView.swift`

```swift
@State private var cachedFilteredItems: [AnyCollectionItem] = []
@State private var lastFilterHash: Int = 0

var filteredItems: [AnyCollectionItem] {
    // Create a hash of filter criteria
    let currentHash = hashValue(
        category: selectedCategory?.id,
        tag: selectedTag?.id,
        searchText: searchText,
        sortOption: sortPreferenceManager.sortOption
    )
    
    // Return cached if nothing changed
    if currentHash == lastFilterHash && !cachedFilteredItems.isEmpty {
        return cachedFilteredItems
    }
    
    // Recalculate
    var items = dataStorage.items
    // ... existing filtering logic ...
    
    let sorted = sortPreferenceManager.sortOption.sort(items)
    cachedFilteredItems = sorted
    lastFilterHash = currentHash
    return sorted
}

private func hashValue(category: UUID?, tag: UUID?, searchText: String, sortOption: SortOption) -> Int {
    var hasher = Hasher()
    hasher.combine(category?.uuidString)
    hasher.combine(tag?.uuidString)
    hasher.combine(searchText)
    hasher.combine(sortOption.rawValue)
    return hasher.finalize()
}
```

**Impact**: Prevents unnecessary recalculations during scrolling.

---

### Priority 2: Important Optimizations

#### 2.1 Use @State for Expensive Computed Properties

**File**: `Seahorse/Views/Cards/StandardCardView.swift`

```swift
struct StandardCardView: View {
    // ... existing code ...
    
    // Cache expensive computations
    @State private var cachedDisplayTitle: String = ""
    @State private var cachedCategory: Category?
    @State private var cachedTags: [Tag] = []
    
    private func updateCache() {
        cachedDisplayTitle = computeDisplayTitle()
        cachedCategory = dataStorage.categories.first(where: { $0.id == categoryId })
        cachedTags = tagIds.compactMap { tagId in
            dataStorage.tags.first(where: { $0.id == tagId })
        }
    }
    
    var body: some View {
        // ... existing body ...
        .onAppear {
            updateCache()
        }
        .onChange(of: item.id) { _ in
            updateCache()
        }
    }
}
```

**Impact**: Reduces redundant computations during scrolling.

---

#### 2.2 Optimize GeometryReader Usage

**File**: `Seahorse/Views/Cards/StandardCardView.swift`

Replace multiple GeometryReaders with fixed sizes where possible:

```swift
// Instead of GeometryReader for preview images, use fixed aspect ratio
private var previewArea: some View {
    Group {
        switch item.itemType {
        case .bookmark:
            if let bookmark = bookmark, let metadata = bookmark.metadata, let previewURL = metadata.imageURL {
                // Use fixed size instead of GeometryReader
                KFImage.url(URL(string: previewURL))
                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 400, height: 300)))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
        // ... rest of cases
        }
    }
}
```

**Impact**: GeometryReader causes layout passes; fixed sizes are faster.

---

#### 2.3 Reduce Material Effects

**File**: `Seahorse/Views/Cards/StandardCardView.swift`

```swift
// In bottomContainer, replace .thickMaterial with lighter option
.background {
    ZStack {
        Rectangle()
            .fill(Color.black.opacity(0.3)) // Reduced opacity
        
        // Use .regularMaterial instead of .thickMaterial
        Rectangle()
            .fill(.regularMaterial) // Lighter than .thickMaterial
    }
}
```

**Impact**: Material effects are expensive; lighter materials improve performance.

---

#### 2.4 Add Drawing Group for Complex Views

**File**: `Seahorse/Views/Cards/StandardCardView.swift`

```swift
var body: some View {
    ZStack(alignment: .bottom) {
        // ... existing layers ...
    }
    .drawingGroup() // Renders view as single layer
    // ... rest of modifiers ...
}
```

**Impact**: Reduces overdraw and improves rendering performance.

---

### Priority 3: Nice-to-Have Optimizations

#### 3.1 Implement View Recycling

**File**: `Seahorse/Views/Lists/ItemCollectionView.swift`

```swift
private var listView: some View {
    ScrollView {
        LazyVStack(spacing: 8) {
            ForEach(items, id: \.id) { item in
                StandardListItemView(item: item)
                    .id(item.id) // Explicit ID for better recycling
            }
        }
        .padding(16)
    }
}
```

---

#### 3.2 Debounce Search Text Updates

**File**: `Seahorse/ContentView.swift`

```swift
@State private var debouncedSearchText: String = ""

var body: some View {
    // ... existing code ...
    .onChange(of: searchText) { newValue in
        // Debounce search updates
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            await MainActor.run {
                debouncedSearchText = newValue
            }
        }
    }
}
```

---

#### 3.3 Use AsyncImage for Remote Images (Alternative)

Consider using SwiftUI's native `AsyncImage` with proper caching instead of Kingfisher for simpler cases, though Kingfisher is generally better for complex scenarios.

---

## Implementation Order

1. **Start with Priority 1 optimizations** - These will have the biggest impact
2. **Test after each change** - Measure scrolling performance
3. **Add Priority 2 optimizations** - Fine-tune performance
4. **Consider Priority 3** - Only if needed after Priority 1 & 2

## Testing Performance

Use Instruments to measure:
- Time Profiler: Identify slow functions
- Allocations: Check memory usage
- Core Animation: Measure frame rate during scrolling

Target: Maintain 60 FPS during scrolling with 100+ items.

---

## Additional Notes

- Consider pagination for very large collections (1000+ items)
- Implement virtual scrolling if needed (though LazyVStack should handle this)
- Profile on actual devices, not just simulators
- Test with various image sizes and types
