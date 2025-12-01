# context.md

# JuleKonkurrencer – Context for AI / Cursor

You are assisting with the implementation of a Flutter app called **JuleKonkurrencer**.

The app is meant to be a simple December-only utility that helps the user keep track of all their Christmas competition calendars ("julekalendere") in one place.

---

## High-Level Concept

In December, many companies and shops run daily Christmas competitions as “calendars”:
- Some are on websites.
- Some live inside other apps (e.g. McDonald’s, Meny, supermarkets).
- Some are physical competitions (paper calendars, in-store contests).
- Some are email-based (where each day’s entry comes via newsletter).

The user easily loses track of them and forgets to participate.

**Goal of the app:**  
Provide a single list where the user can register all their active Christmas competitions, so they can quickly open them each day without hunting for links or apps. The app should also come with a predefined list of known calendars, potentially with affiliate URLs.

---

## Platforms and Tech

- **Framework:** Flutter
- **Platforms:** Android and iOS (only)
- **Language:** Dart
- **Analytics:** Firebase Analytics (via Firebase)
- **Local Storage:** Local-only (no external backend)
  - Either `shared_preferences` or a simple local DB like `hive`.
- **Link / App Launching:** `url_launcher`
- **Notifications (later):** `flutter_local_notifications` (for reminders, optional)

All code and code comments must be written in **English**.

---

## Main Data Types

We have one primary model: a “calendar entry” for a competition.

**Calendar types:**

1. `website`
   - Represents a Christmas calendar on a website.
   - Has a URL (possibly with affiliate parameters).
   - Should open in the external browser so cookies and login info are reused.

2. `app`
   - Represents a calendar that lives in another app (e.g. McDonald’s app).
   - Tapping should try to open that app.
   - If not installed, fall back to the store page.

3. `physical`
   - Represents a physical competition:
     - In-store scratch cards.
     - Paper calendars.
     - Local shop campaigns.
   - Mainly stores a location and a note about how to participate.

4. `email`
   - Represents calendars where participation is driven by emails.
   - This entry is basically a reminder to check the inbox.

**Suggested model:**

```dart
enum CalendarType { website, app, physical, email }

class AdventCalendarEntry {
  final String id;           // uuid string
  final String name;         // human readable name
  final CalendarType type;

  final String? url;         // website URL, may include affiliate params
  final String? affiliateTag;

  final String? appPackage;  // Android package name
  final String? iosBundleId; // iOS bundle id

  final String? location;    // for physical calendars
  final String? note;        // generic note

  final bool isPredefined;   // true if from bundled predefined list
  final bool isFavorite;     // for pinning important entries

  final DateTime createdAt;
  final DateTime updatedAt;
}
