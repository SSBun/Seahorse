# Seahorse - Bookmark Manager

A native macOS SwiftUI application for managing bookmarks with a Finder-like interface.

## Features

- **Finder-like UI**: Familiar macOS interface with sidebar and detail view
- **Category Management**: Organize bookmarks by categories
- **Multiple View Modes**: Switch between grid and list views
- **Search Functionality**: Quick search across bookmarks
- **Favorites**: Mark important bookmarks as favorites
- **Modern Design**: Clean, native macOS design using SwiftUI

## Project Structure

```
Seahorse/
├── Models/
│   ├── Category.swift          # Category data model with mock data
│   └── Bookmark.swift           # Bookmark data model with mock data
├── Views/
│   ├── SidebarView.swift        # Left sidebar with categories
│   ├── ToolbarView.swift        # Top toolbar with actions and search
│   ├── BookmarkCardView.swift   # Grid view card component
│   ├── BookmarkListItemView.swift # List view item component
│   └── BookmarkCollectionView.swift # Main collection view (grid/list)
├── ContentView.swift            # Main application view
└── SeahorseApp.swift           # App entry point
```

## UI Components

### Sidebar
- Displays categories with icons and colors
- Uses native macOS List style
- Supports category selection

### Toolbar
- Add/Delete bookmark buttons (UI only)
- Grid/List view toggle
- Search field with clear button

### Content Area
- **Grid View**: Visual cards with bookmark icons, titles, URLs, and favorite indicators
- **List View**: Compact rows with all bookmark details
- Empty state when no bookmarks match criteria

### Bookmark Display
- Gradient icon backgrounds
- Hover effects for better interactivity
- Favorite star indicators
- Date information in list view
- Optional notes display

## Mock Data

The app currently uses mock data for demonstration:

### Categories
- All Bookmarks
- Favorites
- Work
- Personal
- Development
- Reading
- Videos
- Research

### Bookmarks
18 sample bookmarks distributed across categories including:
- GitHub, Slack, Jira (Work)
- Gmail, Google Drive, Netflix (Personal)
- Stack Overflow, MDN, SwiftUI Docs (Development)
- Medium, Dev.to, Hacker News (Reading)
- YouTube, Vimeo (Videos)
- Google Scholar, ArXiv, ResearchGate (Research)

## Current Status

✅ UI Implementation Complete
- All views created and styled
- Mock data rendering working
- Search and filtering working
- View mode switching working

⏳ Pending Implementation
- Actual bookmark persistence (database/storage)
- Add/Edit/Delete bookmark functionality
- Import bookmarks from browsers
- Export functionality
- Settings and preferences
- Keyboard shortcuts
- Drag and drop support

## Technical Details

- **Platform**: macOS
- **Framework**: SwiftUI
- **Minimum Target**: macOS 13.0+
- **Architecture**: MVVM-ready structure
- **Navigation**: NavigationSplitView for sidebar layout

## Build and Run

1. Open `Seahorse.xcodeproj` in Xcode
2. Select a macOS target
3. Build and run (⌘R)

## Next Steps

After UI completion, the following features should be implemented:

1. **Data Persistence**
   - Core Data or SwiftData integration
   - Cloud sync support (optional)

2. **CRUD Operations**
   - Create new bookmarks
   - Edit existing bookmarks
   - Delete bookmarks
   - Manage categories

3. **Import/Export**
   - Browser bookmark import
   - JSON/CSV export

4. **Advanced Features**
   - Tags support
   - Smart folders
   - Quick add with keyboard shortcut
   - Safari extension integration

## License

[Add your license here]

