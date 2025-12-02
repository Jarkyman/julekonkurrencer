import 'package:uuid/uuid.dart';

enum CalendarType { website, app, physical, email }

CalendarType calendarTypeFromString(String value) {
  return CalendarType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => CalendarType.website,
  );
}

class AdventCalendarEntry {
  AdventCalendarEntry({
    required this.id,
    required this.name,
    required this.type,
    this.logo,
    this.url,
    this.appPackage,
    this.iosBundleId,
    this.location,
    this.note,
    this.isPredefined = false,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final CalendarType type;
  final String? logo;
  final String? url;
  final String? appPackage;
  final String? iosBundleId;
  final String? location;
  final String? note;
  final bool isPredefined;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AdventCalendarEntry.create({
    required String name,
    required CalendarType type,
    String? logo,
    String? url,
    String? appPackage,
    String? iosBundleId,
    String? location,
    String? note,
    bool isPredefined = false,
    bool isFavorite = false,
  }) {
    final now = DateTime.now();
    return AdventCalendarEntry(
      id: const Uuid().v4(),
      name: name,
      type: type,
      logo: logo,
      url: url,
      appPackage: appPackage,
      iosBundleId: iosBundleId,
      location: location,
      note: note,
      isPredefined: isPredefined,
      isFavorite: isFavorite,
      createdAt: now,
      updatedAt: now,
    );
  }

  AdventCalendarEntry copyWith({
    String? id,
    String? name,
    CalendarType? type,
    String? logo,
    String? url,
    String? appPackage,
    String? iosBundleId,
    String? location,
    String? note,
    bool? isPredefined,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdventCalendarEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      logo: logo ?? this.logo,
      url: url ?? this.url,
      appPackage: appPackage ?? this.appPackage,
      iosBundleId: iosBundleId ?? this.iosBundleId,
      location: location ?? this.location,
      note: note ?? this.note,
      isPredefined: isPredefined ?? this.isPredefined,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'logo': logo,
      'url': url,
      'appPackage': appPackage,
      'iosBundleId': iosBundleId,
      'location': location,
      'note': note,
      'isPredefined': isPredefined,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AdventCalendarEntry.fromJson(Map<String, dynamic> json) {
    return AdventCalendarEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      type: calendarTypeFromString(json['type'] as String),
      logo: json['logo'] as String? ?? json['Logo'] as String?,
      url: json['url'] as String?,
      appPackage: json['appPackage'] as String?,
      iosBundleId: json['iosBundleId'] as String?,
      location: json['location'] as String?,
      note: json['note'] as String?,
      isPredefined: json['isPredefined'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
