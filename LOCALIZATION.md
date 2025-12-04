# Seahorse Localization Guide

## Overview

Seahorse now supports full multi-language localization using **String Catalogs** (`.xcstrings`), the modern approach for macOS 13+ and iOS 15+ localization.

## Implementation

### 1. **String Catalog** (`Localizable.xcstrings`)

Location: `/Seahorse/Localizable.xcstrings`

Currently supports:
- **English** (en) - Source language
- **Simplified Chinese** (zh-Hans) - Full translation

**Format**: JSON-based string catalog with automatic key extraction

### 2. **Localization Helper** (`LocalizationHelper.swift`)

Centralized string constants accessed via `L10n`:

```swift
// Usage Examples
Text(L10n.add)                  // "Add" / "添加"
Text(L10n.addBookmark)          // "Add Bookmark" / "添加书签"
Button(L10n.save) { ... }       // "Save Changes" / "保存更改"
```

**Categories**:
- Common actions (Add, Cancel, Delete, Edit, Save, etc.)
- Bookmarks (Add Bookmark, All Bookmarks, Favorites, etc.)
- Settings (App Language, Primary Color, Appearance, etc.)
- Preview (Title, URL, Summary, Added, etc.)
- Alerts & Tooltips

### 3. **Localized Components**

#### ✅ **BasicSettingsView**
- App Language selector with hint
- AI Parsing Language selector
- Primary Color, Appearance, Card Style labels
- Preference Folder section
- Data Management (Export/Import)
- Restart Required alert

#### ✅ **BookmarkPreviewView**
- All section headers (URL, Summary, Category, Tags, Added)
- Action buttons (Open in Browser, Copy URL)
- AI Parsed badge

#### ✅ **SettingsView**
- Tab labels (Basic, Category, Tag)

#### ✅ **ContentView**
- Diagnostic button tooltips
- Accessibility labels

#### ✅ **All Card Views**
- Context menu items (Edit, Open URL, Delete)
- BookmarkCardView
- CompactBookmarkCardView
- RectangleBookmarkCardView
- BookmarkListItemView

### 4. **Accessibility Support**

All interactive elements include:
- `.accessibilityLabel()` - Readable label for screen readers
- `.accessibilityHint()` - Additional context for users
- `.help()` - Tooltips for mouse users

Examples:
```swift
Picker("", selection: $languageManager.appLanguage) { ... }
    .accessibilityLabel(L10n.appLanguage)
    .accessibilityHint(L10n.appLanguageHint)

Button(L10n.reset) { ... }
    .help(L10n.resetToDefaultLocation)
    .accessibilityLabel(L10n.reset)
    .accessibilityHint(L10n.resetToDefaultLocation)
```

## Adding New Languages

### Step 1: Add Language to String Catalog

1. Open `Localizable.xcstrings` in Xcode
2. Click the `+` button to add a new language
3. Select language (e.g., Japanese, Spanish, French)
4. Xcode will create empty translations for all keys

### Step 2: Translate Strings

For each key in the catalog:
```json
"Add" : {
  "localizations" : {
    "en" : { "value" : "Add" },
    "zh-Hans" : { "value" : "添加" },
    "ja" : { "value" : "追加" }  // Japanese
  }
}
```

### Step 3: Update Language Models

Add new language to `/Seahorse/Models/Language.swift`:

```swift
enum AppLanguage: String, CaseIterable {
    case english = "English"
    case japanese = "日本語"  // Add this
    // ...
    
    var code: String {
        case .japanese: return "ja"  // Add this
    }
}
```

### Step 4: Update AI Language

Add to `AILanguage` enum:

```swift
enum AILanguage: String, CaseIterable {
    case japanese = "日本語"
    
    var promptSuffix: String {
        case .japanese: return "日本語で答えてください。"
    }
}
```

## Language System Architecture

```
┌─────────────────────────────────────────┐
│         User Changes Language           │
│      (BasicSettingsView picker)         │
└────────────┬────────────────────────────┘
             │
             ├──> LanguageManager.shared
             │    └──> Sets AppleLanguages
             │         └──> Requires app restart
             │
             └──> AISettings.shared
                  └──> Sets aiLanguage
                       └──> Appends to AI prompts
                            └──> Immediate effect
```

## Key Features

### ✅ **Implemented**
- String Catalog-based localization
- Centralized `L10n` helper
- Full accessibility support
- Context menu localization
- Tooltip localization
- Alert dialog localization
- Tab label localization
- Settings page localization

### 🌐 **Supported Languages**
- English (en)
- Simplified Chinese (zh-Hans)
- Ready to add: Japanese, Korean, French, German, Spanish, Italian, Portuguese, Russian, Arabic, Traditional Chinese

### 🎯 **Best Practices**
1. **Always use `L10n` constants** instead of hardcoded strings
2. **Add accessibility labels** to all interactive elements
3. **Keep string keys descriptive** for easy maintenance
4. **Test with multiple languages** before release
5. **Use `.textSelection(.enabled)` for user-facing content

## Testing Localization

### In Xcode:
1. Product > Scheme > Edit Scheme
2. Run > Options > App Language
3. Select language to test
4. Run app

### In App:
1. Open Settings > Basic
2. Change "App Language"
3. Restart app
4. Verify all UI elements display correctly

## Translation Coverage

| Component | English | Chinese | Status |
|-----------|---------|---------|--------|
| Basic Settings | ✅ | ✅ | Complete |
| Bookmark Preview | ✅ | ✅ | Complete |
| Context Menus | ✅ | ✅ | Complete |
| Tooltips | ✅ | ✅ | Complete |
| Alerts | ✅ | ✅ | Complete |
| Tab Labels | ✅ | ✅ | Complete |

## Future Enhancements

- [ ] Add more languages (Japanese, Korean, etc.)
- [ ] Localize error messages
- [ ] Localize date/time formats
- [ ] Localize number formats
- [ ] Add RTL support for Arabic
- [ ] Localize AddBookmarkView
- [ ] Localize DiagnosticResultsView
- [ ] Localize CategoryManagementView
- [ ] Localize TagManagementView

## Notes

- **App Language**: Changes entire UI (requires restart)
- **AI Language**: Only affects AI-generated content (immediate)
- **String Catalogs**: Automatically extracted by Xcode during build
- **Fallback**: Missing translations automatically fall back to English

