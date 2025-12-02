# TODO.md

# JuleKonkurrencer – TODO

This file tracks implementation steps for the JuleKonkurrencer app.

The app is a small December-only utility that lets users keep track of all their Christmas competition calendars (web, app, physical, email) and quickly open them each day.

All code and comments must be written in English.

---

## Milestone 1 – MVP

Goal: A functional app where the user can manage a list of Christmas competition calendars and open them.

### Project Setup

- [x] Create Flutter project `julekonkurrencer` targeting Android and iOS.
- [x] Set application id / bundle id to `com.hartvigsolutions.julekonkurrencer` (or similar).
- [x] Add dependencies to `pubspec.yaml`:
  - [x] `url_launcher`
  - [x] Local storage: `shared_preferences` **or** `hive`
  - [x] `firebase_core`
  - [x] `firebase_analytics`
- [x] Configure Firebase project:
  - [x] Create Firebase project.
  - [x] Register Android app and iOS app.
  - [x] Add `google-services.json` (Android).
  - [x] Add `GoogleService-Info.plist` (iOS).
  - [x] Initialize Firebase in `main.dart`.
- [x] Initialize Firebase Analytics.

### Data Model & Storage

- [x] Define `CalendarType` enum: `website`, `app`, `physical`, `email`.
- [x] Define `AdventCalendarEntry` model with fields:
  - [x] `id` (String, uuid)
  - [x] `name` (String)
  - [x] `type` (CalendarType)
  - [x] `url` (String?, for website calendars and affiliate URLs)
  - [x] `affiliateTag` (String?, optional description)
  - [x] `appPackage` (String?, Android package name)
  - [x] `iosBundleId` (String?, iOS bundle id)
  - [x] `location` (String?, for physical calendars)
  - [x] `note` (String?, free-form)
  - [x] `isPredefined` (bool, default false)
  - [x] `isFavorite` (bool, default false)
  - [x] `createdAt` (DateTime)
  - [x] `updatedAt` (DateTime)
- [x] Implement serialization to/from JSON for `AdventCalendarEntry`.
- [x] Implement a storage service:
  - [x] Load all entries from local storage on startup.
  - [x] Save entries whenever they change.
  - [x] Provide CRUD operations (add, update, delete).

### UI – Home Screen

- [x] Implement `HomeScreen`:
  - [x] Display list of `AdventCalendarEntry` items in a scrollable list.
  - [x] Show icon or visual indicator based on `CalendarType`.
  - [x] Show name and a secondary text (e.g. type or note).
- [x] Add a Floating Action Button (FAB) or primary button to add a new calendar.
- [x] Handle tap on a list item:
  - [x] Default action: open the calendar (website/app/physical/email behavior).
- [x] Add a way to edit/delete an entry:
  - [x] Long-press or context menu, or trailing icon button.

### UI – Add / Edit Screen

- [x] Implement a screen for creating and editing an `AdventCalendarEntry`:
  - [x] Type selector (segmented control, dropdown, or chips) for `CalendarType`.
  - [x] Common fields:
    - [x] Name (required).
    - [x] Note (optional).
  - [x] Type-specific fields:
    - Website: `url` (+ optional affiliate info).
    - App: `appPackage` and `iosBundleId`.
    - Physical: `location`.
    - Email: maybe a short reminder note.
  - [x] "Save" button to persist changes and navigate back.
  - [x] Input validation (e.g. non-empty name, valid URL for website type).

### Open Actions

- [x] Implement open logic for each type:
  - [x] Website:
    - [x] Use `url_launcher` to open `url` in the external browser.
  - [x] App:
    - [x] Attempt to open installed app (best-effort using known approaches).
    - [x] If not possible, open store link (if stored or derivable).
  - [x] Physical:
    - [x] Open a simple detail view showing name, location, and note.
  - [x] Email:
    - [x] Open a simple detail view reminding user to check inbox.
- [x] Handle errors gracefully (e.g. show a SnackBar if a link cannot be launched).

### Analytics (MVP level)

- [x] Create a small analytics helper/wrapper.
- [x] Log events:
  - [x] `add_calendar` (include type and whether predefined).
  - [x] `open_calendar` (include type).
  - [x] `delete_calendar`.

---

## Milestone 2 – MVP2

Goal: Better usability, predefined calendars and simple filtering.

### Predefined Calendars

- [x] Add `predefined_calendars.json` to the project from github gist (https://gist.githubusercontent.com/Jarkyman/6bdd0d0b99f06e8f8878b4309a181e82/raw/predefined_calendars.json).
  - [x] Define JSON array following `AdventCalendarEntry` structure (subset is fine).
  - [x] Include popular Danish website calendars.
  - [x] Include app-based calendars (McDonald’s, Meny, etc.).
  - [x] Use affiliate URLs where possible in the `url` field.
  - [x] Mark these with `isPredefined: true`.
- [x] Load predefined calendars on startup:
  - [x] Parse JSON from assets.
  - [x] Keep in memory as a separate list from user’s list.

### UI for Predefined Calendars

- [x] Create a screen or dialog to browse predefined calendars:
  - [x] List items with name and type.
  - [x] “Add” button to add an item to user’s list.
- [x] When adding:
  - [x] Create a copy of the predefined entry.
  - [x] Set `isPredefined` on the instance.
  - [x] Add to local storage list.
- [x] Analytics:
  - [x] Log `view_predefined_list`.
  - [x] Log `add_predefined_calendar`.

### Filtering and Favorites

- [x] Add `isFavorite` toggle to `AdventCalendarEntry`.
- [x] Update UI:
  - [x] Add a control for filtering by type: All / Website / App / Physical / Email.
  - [x] Add simple sorting:
    - Favorites first, then alphabetical by name.
- [x] Provide a way to toggle favorite from the home list or detail view.
- [x] Analytics:
  - [x] Log `toggle_favorite`.

---

## Milestone 3 – Nice to Have

Goal: Quality-of-life improvements and polish for December usage.

### Daily Reminders

- [x] Add local notifications (e.g. using `flutter_local_notifications`).
- [x] Ask user to allow notifications.
- [x] Schedule daily notification(s) in December:
  - [x] Default time, e.g. 09:00.
  - [x] Message like “Remember to check your Christmas competitions”.
- [ ] Optional: configurable reminder time in settings.

### “Done Today” / Progress

- [x] Add a per-entry state for “completed today”.
- [x] On the home screen:
  - [x] Show a checkmark or indicator if the user has marked it as done for today.
- [ ] Add a small summary:
  - [ ] “X / Y calendars done today”.
- [x] Reset “done today” status automatically at midnight or on app open next day.

### Theming and Polish

- [ ] Add a simple Christmas-inspired theme:
  - [ ] Primary/secondary colors.
  - [ ] Icons or small decorative touches.
- [ ] Create a custom app icon related to Christmas competitions.
- [ ] Add a simple splash screen.
- [ ] Refresh overall UI styling so it looks polished (layouts, spacing, buttons, fonts, colors).

### Optional: In-App WebView

- [ ] Consider adding a WebView screen for website calendars using `webview_flutter`.
- [ ] Ensure cookies are persisted so logins are remembered.
- [ ] Let user choose whether to open in browser or in-app.

---

## General Notes

- Keep the architecture simple and pragmatic.
- No remote backend in MVP/MVP2 – everything is local + Firebase Analytics.
- All code and comments must be in English.
- Prefer readability and maintainability over premature optimization.
