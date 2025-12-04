# Seahorse UI Guide

## Overview
Seahorse features a Finder-like interface with a three-panel layout optimized for macOS.

## Layout Structure

```
┌─────────────────────────────────────────────────────────────────┐
│  Seahorse                                              ⚫ 🟡 🟢  │
├──────────────┬──────────────────────────────────────────────────┤
│              │  [+] [🗑️]  [🔲|☰]          🔍 [Search...]      │
│ CATEGORIES   ├──────────────────────────────────────────────────┤
│              │                                                  │
│ 📖 All       │  ┌────────┐  ┌────────┐  ┌────────┐           │
│ ⭐ Favorites │  │ [Icon] │  │ [Icon] │  │ [Icon] │           │
│ 💼 Work      │  │ GitHub │  │ Slack  │  │ Jira   │           │
│ 👤 Personal  │  │ ⭐     │  │        │  │        │           │
│ </> Dev      │  └────────┘  └────────┘  └────────┘           │
│ 📚 Reading   │                                                  │
│ ▶️ Videos    │  ┌────────┐  ┌────────┐  ┌────────┐           │
│ 🔍 Research  │  │ [Icon] │  │ [Icon] │  │ [Icon] │           │
│              │  │ Gmail  │  │ Drive  │  │Netflix │           │
│              │  │ ⭐     │  │        │  │        │           │
│              │  └────────┘  └────────┘  └────────┘           │
└──────────────┴──────────────────────────────────────────────────┘
```

## Components

### 1. Sidebar (Left Panel)
- **Width**: 200-220px
- **Style**: Native macOS sidebar
- **Content**: 
  - Section header: "CATEGORIES"
  - 8 default categories with colored icons
  - Selection highlights active category

**Categories:**
| Icon | Name | Color | Purpose |
|------|------|-------|---------|
| 📖 | All Bookmarks | Blue | Shows all bookmarks |
| ⭐ | Favorites | Yellow | Shows starred bookmarks |
| 💼 | Work | Purple | Work-related bookmarks |
| 👤 | Personal | Green | Personal bookmarks |
| </> | Development | Orange | Dev resources |
| 📚 | Reading | Red | Articles & blogs |
| ▶️ | Videos | Pink | Video content |
| 🔍 | Research | Indigo | Academic resources |

### 2. Toolbar (Top of Right Panel)
- **Height**: ~40px
- **Background**: Window background color

**Elements (Left to Right):**
1. **Add Button** [+] - Add new bookmark (UI only)
2. **Delete Button** [🗑️] - Delete selected bookmark (UI only)
3. **Divider**
4. **View Mode Toggle** [🔲|☰] - Switch between grid/list view
5. **Spacer**
6. **Search Field** - Filter bookmarks with clear button

### 3. Content Area (Bottom of Right Panel)

#### Grid View Mode
- **Layout**: Adaptive grid (minimum 164px, maximum 200px per card)
- **Spacing**: 20px between cards
- **Card Design**:
  - Size: 140x160px (content) + 12px padding
  - Gradient icon background (80x80px)
  - Title (2 lines max, 13pt, medium weight)
  - URL (1 line, 11pt, truncated in middle)
  - Favorite star (if applicable)
  - Hover effects: Scale 1.02x, shadow enhancement
  - Border highlight on hover

#### List View Mode
- **Layout**: Vertical stack with 1px spacing
- **Item Design**:
  - Horizontal layout with 12px padding
  - 40x40px gradient icon
  - Title (13pt, medium) + favorite star
  - URL (11pt, secondary)
  - Notes (10pt, tertiary, if available)
  - Date (11pt, secondary, right-aligned)
  - Background highlight on hover

### 4. Empty States

**No Selection:**
```
┌─────────────────────────┐
│                         │
│   Select a category     │
│                         │
└─────────────────────────┘
```

**No Bookmarks:**
```
┌─────────────────────────┐
│         📖/             │
│                         │
│    No Bookmarks         │
│                         │
│  Add your first         │
│  bookmark to            │
│  get started            │
└─────────────────────────┘
```

**No Search Results:**
```
┌─────────────────────────┐
│         📖/             │
│                         │
│    No Bookmarks         │
│                         │
│  No bookmarks match     │
│  your search            │
└─────────────────────────┘
```

## Interactions

### Hover Effects
- **Cards**: Scale up slightly, enhanced shadow, accent border
- **List Items**: Background highlight
- **Buttons**: System default hover states

### Selection
- **Sidebar**: Selected category highlighted with accent color
- **Bookmarks**: Click to select (ready for future implementation)

### Search
- **Real-time filtering** as you type
- **Searches**: Title, URL, and notes fields
- **Case insensitive**
- **Clear button** appears when text is entered

### View Toggle
- **Grid View**: Visual cards for browsing
- **List View**: Compact rows with more details
- **State preserved** across category changes

## Color Scheme

### System Colors Used
- **Window Background**: NSColor.windowBackgroundColor
- **Control Background**: NSColor.controlBackgroundColor
- **Accent**: System accent color (respects user preference)
- **Labels**: System semantic colors (.secondary, .tertiary)

### Custom Colors
- **Icon Gradients**: Blue to Purple (per bookmark)
- **Category Icons**: Unique color per category (see table above)

## Typography

| Element | Size | Weight |
|---------|------|--------|
| Category Name | 13pt | Regular |
| Toolbar Icons | System | Regular |
| Search Field | 13pt | Regular |
| Card Title | 13pt | Medium |
| Card URL | 11pt | Regular |
| List Title | 13pt | Medium |
| List URL | 11pt | Regular |
| List Notes | 10pt | Regular |
| List Date | 11pt | Regular |
| Empty State Title | 20pt | Semibold |
| Empty State Body | 14pt | Regular |

## Window Configuration
- **Default Size**: 1200x800px
- **Minimum Size**: Auto (based on content constraints)
- **Resizable**: Yes
- **Style**: Standard macOS window with traffic lights

## Accessibility
- System font scaling supported
- Semantic colors respect system appearance (Light/Dark mode)
- Hover states for keyboard navigation (future)
- VoiceOver labels ready for implementation

## Mock Data Summary
- **8 Categories** across different life areas
- **18 Sample Bookmarks** distributed across categories
- **Realistic examples**: GitHub, Gmail, YouTube, Stack Overflow, etc.
- **5 Favorited items** for testing favorite filtering
- **Notes included** on some bookmarks for search testing

## Next Development Phase
When implementing actual functionality, the UI is ready for:
1. Click handlers on add/delete buttons
2. Bookmark detail view/editor
3. Drag and drop support
4. Context menus
5. Keyboard shortcuts
6. Multi-selection in list view

