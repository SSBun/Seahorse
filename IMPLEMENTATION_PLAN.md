## Stage 1: Understand current preview and toolbar flows
**Goal**: Locate bookmark web preview toolbar, OGP preview rendering, and image storage helpers.
**Success Criteria**: Know where to add a snapshot control and how preview images are stored/loaded.
**Tests**: None (discovery only).
**Status**: Complete

## Stage 2: Snapshot capture & persistence
**Goal**: Add a toolbar snapshot mode that lets users drag a rectangle over the web view and save a captured image locally.
**Success Criteria**: Snapshot button toggles selection UI; Save writes PNG to storage and updates bookmark metadata image path; cancels cleanly.
**Tests**: Manual: open bookmark detail → capture snapshot → preview shows saved image.
**Status**: Complete

## Stage 3: Preview area UX improvements
**Goal**: Always render preview area in sidebar, allow external image drop, and support local paths in cards.
**Success Criteria**: Sidebar preview shows placeholder when empty, accepts drag/drop to set preview; cards render local preview paths.
**Tests**: Manual: drag external image into preview area → card shows image; fallback placeholder visible when empty.
**Status**: Complete

## Stage 4: Startup setting discovery
**Goal**: Understand current settings architecture and how preferences are stored to add an auto-launch toggle.
**Success Criteria**: Identify where to place UI and which persistence/manager pattern to follow for startup behavior.
**Tests**: None (discovery only).
**Status**: Complete

## Stage 5: Login item manager
**Goal**: Implement a manager that enables/disables Seahorse at login using ServiceManagement and keeps the preference persisted.
**Success Criteria**: Toggling the setting registers/unregisters the app as a login item without errors; preference is stored.
**Tests**: Manual: toggle on/off and observe no errors in logs.
**Status**: Complete

## Stage 6: UI and localization
**Goal**: Expose the startup toggle in Basic Settings with localized copy and accessibility labels.
**Success Criteria**: Toggle appears in settings, uses localized strings, and updates state reactively.
**Tests**: Manual: open Settings → Basic → toggle is visible and updates.
**Status**: Complete

## Stage 7: Validation
**Goal**: Verify startup behavior and document manual test steps.
**Success Criteria**: Manual check shows Seahorse can be set to launch at login and disabled again; plan file updated.
**Tests**: Manual: enable auto-start, restart login session (simulated), then disable and confirm removal.
**Status**: Not Started

## Stage 8: Image path portability
**Goal**: Store only filenames for local images and resolve paths using the current storage directory to avoid breakage after migrations.
**Success Criteria**: Saved image paths omit absolute directories; UI renders local images via resolved paths; existing remote URLs unaffected.
**Tests**: Manual: add image and snapshot, move storage folder, reopen and confirm images load.
**Status**: In Progress

