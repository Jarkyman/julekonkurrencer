# JuleKonkurrencer – App Spec

Simple December-only app to keep track of all Christmas calendar competitions (julekalendere) in one place: website calendars, app-based calendars and physical competitions.

The app should be fast to build, minimal in scope, and focused on making it easy to open today's calendars without hunting for links or apps.

---

## Tech Stack

- **Framework:** Flutter
- **Platforms:** Android, iOS (no web/desktop)
- **Language:** Dart
- **Analytics:** Firebase Analytics (Google Analytics)
- **Local storage:** `shared_preferences` or `hive` (local only, no backend in MVP)
- **Link/App launching:** `url_launcher`
- **Dev assistance:** ChatGPT / “Codex” agent in VS Code (used to generate and refactor code)

---

## Core Concept

User has a list of "Christmas competitions" (julekalendere).  
Each entry can be one of these types:

1. **Website calendar**
   - Opens an external browser with a stored URL.
   - Browser is responsible for cookies and autofill so the site "remembers" previous input.
   - Optionally use affiliate links where possible.

2. **App calendar**
   - Represents a calendar inside another app (e.g. McDonald’s, Meny).
   - Tapping opens the target app if installed.
   - If not installed, open the store page (Google Play / App Store).

3. **Physical competition**
   - Represents a physical calendar or competition in a store (scratch card, paper calendar, in-store draw, etc.).
   - Stores location/name and notes on how to participate.

4. **Email/newsletter calendar** (extra type from start, but simple)
   - Represents calendars where each day comes via email.
   - Mainly used as a reminder: "Check your inbox for this calendar."

The app should also ship with a **predefined list** of known calendars (some with affiliate URLs) that the user can quickly add to their own list.

---

## Data Model (suggested)

```dart
enum CalendarType { website, app, physical, email }

class AdventCalendarEntry {
  final String id; // uuid string
  final String name;
  final CalendarType type;

  final String? url;           // for website + affiliate URL
  final String? affiliateTag;  // optional, descriptive only

  final String? appPackage;    // Android package name
  final String? iosBundleId;   // iOS bundle id

  final String? location;      // for physical calendars
  final String? note;          // free-form note

  final bool isPredefined;     // true if came from the bundled list
  final bool isFavorite;       // for sorting/pinning

  final DateTime createdAt;
  final DateTime updatedAt;
}
