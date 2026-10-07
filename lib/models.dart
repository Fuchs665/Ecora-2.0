

/// Colonne leggibili di `profiles`. Dal Block 6.2 (migration 0012) i grant
/// SELECT sono per colonna e `select=*` fallisce con permission denied:
/// ogni lettura del client DEVE enumerare le colonne. I timestamp di
/// consenso (age_confirmed_at/terms_accepted_at) sono esclusi di proposito.
const String kProfileSelectColumns =
    'id, role, nickname, avatar_url, generic_location, is_verified, '
    'created_at, profile_type, privacy_level, birth_year';

class SupabaseProfile {
  final String id;
  final String fullName;
  final String role; // 'cliente' or 'gestore'

  /// Anno di nascita (migrazione 0015). Null finché l'utente non lo
  /// inserisce; per le coppie è quello del più giovane.
  final int? birthYear;
  final String gender; // 'Uomo', 'Donna', 'Coppia'
  final int noShows;
  final int participationsCount;
  final String? profileType;
  final String? privacyLevel;
  final String? genericLocation;

  /// Locale verificato da noi (solo gestori, Blocco V.2): senza, non
  /// pubblica serate e quelle pubblicate non sono visibili (migrazione 0021).
  final bool isVerified;

  SupabaseProfile({
    required this.id,
    required this.fullName,
    required this.role,
    this.birthYear,
    required this.gender,
    this.noShows = 0,
    this.participationsCount = 0,
    this.profileType,
    this.privacyLevel,
    this.genericLocation,
    this.isVerified = false,
  });

  SupabaseProfile copyWith({
    String? id,
    String? fullName,
    String? role,
    int? birthYear,
    String? gender,
    int? noShows,
    int? participationsCount,
    String? profileType,
    String? privacyLevel,
    String? genericLocation,
    bool? isVerified,
  }) {
    return SupabaseProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      birthYear: birthYear ?? this.birthYear,
      gender: gender ?? this.gender,
      noShows: noShows ?? this.noShows,
      participationsCount: participationsCount ?? this.participationsCount,
      profileType: profileType ?? this.profileType,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      genericLocation: genericLocation ?? this.genericLocation,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  /// Età in anni compiuti o da compiere quest'anno: con il solo anno di
  /// nascita può superare quella reale di uno. Null se l'anno manca.
  int? ageAt(DateTime now) {
    final year = birthYear;
    return year == null ? null : now.year - year;
  }

  /// Maps a row from the real `profiles` table.
  /// gender is not stored in the DB: it is derived from profile_type.
  factory SupabaseProfile.fromRow(Map<String, dynamic> row) {
    final String? profileType = row['profile_type']?.toString();
    final String gender;
    if (profileType == null) {
      gender = 'Coppia';
    } else if (profileType.contains('Coppia')) {
      gender = 'Coppia';
    } else if (profileType.contains('Donna')) {
      gender = 'Donna';
    } else {
      gender = 'Uomo';
    }
    return SupabaseProfile(
      id: row['id']?.toString() ?? '',
      fullName: row['nickname']?.toString() ?? 'Utente Anonimo',
      role: row['role']?.toString() ?? 'cliente',
      birthYear: (row['birth_year'] as num?)?.toInt(),
      gender: gender,
      profileType: profileType,
      privacyLevel: row['privacy_level']?.toString(),
      genericLocation: row['generic_location']?.toString(),
      isVerified: row['is_verified'] == true,
    );
  }
}

class SupabaseEvent {
  final String id;
  final String title;
  final String description;
  final String organizerId;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final String eventDate;
  final int maxParticipants;
  final int currentApprovedCount;
  final String locationName;

  /// Posti per tipologia (Blocco C.5d, migrazione 0022): null = nessun
  /// limite. Gli approvati per categoria vengono da get_events_with_stats.
  final int? maxCouples;
  final int? maxWomen;
  final int? maxMen;
  final int approvedCouples;
  final int approvedWomen;
  final int approvedMen;

  SupabaseEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.organizerId,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.eventDate,
    required this.maxParticipants,
    this.currentApprovedCount = 0,
    this.locationName = "Secret Florence Villa",
    this.maxCouples,
    this.maxWomen,
    this.maxMen,
    this.approvedCouples = 0,
    this.approvedWomen = 0,
    this.approvedMen = 0,
  });

  double get tableCompletionPercentage =>
      maxParticipants > 0 ? (currentApprovedCount / maxParticipants) : 0.0;

  /// Maps a row returned by the `get_events_with_stats()` RPC
  /// (real DB keys: host_id, max_guests, approved_count).
  factory SupabaseEvent.fromStats(Map<String, dynamic> json) {
    return SupabaseEvent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      organizerId: json['host_id']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 43.7695,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 11.2558,
      imageUrl: json['image_url']?.toString() ?? '',
      eventDate:
          json['event_date']?.toString() ?? DateTime.now().toIso8601String(),
      maxParticipants: (json['max_guests'] as num?)?.toInt() ?? 0,
      currentApprovedCount: (json['approved_count'] as num?)?.toInt() ?? 0,
      locationName: json['location_name']?.toString() ?? 'Indirizzo nascosto',
      maxCouples: (json['max_couples'] as num?)?.toInt(),
      maxWomen: (json['max_women'] as num?)?.toInt(),
      maxMen: (json['max_men'] as num?)?.toInt(),
      approvedCouples: (json['approved_couples'] as num?)?.toInt() ?? 0,
      approvedWomen: (json['approved_women'] as num?)?.toInt() ?? 0,
      approvedMen: (json['approved_men'] as num?)?.toInt() ?? 0,
    );
  }

  SupabaseEvent copyWith({
    String? id,
    String? title,
    String? description,
    String? organizerId,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? eventDate,
    int? maxParticipants,
    int? currentApprovedCount,
    String? locationName,
  }) {
    // I posti per tipologia restano quelli della serata.
    return SupabaseEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      organizerId: organizerId ?? this.organizerId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      eventDate: eventDate ?? this.eventDate,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentApprovedCount: currentApprovedCount ?? this.currentApprovedCount,
      locationName: locationName ?? this.locationName,
      maxCouples: maxCouples,
      maxWomen: maxWomen,
      maxMen: maxMen,
      approvedCouples: approvedCouples,
      approvedWomen: approvedWomen,
      approvedMen: approvedMen,
    );
  }
}

class SupabaseParticipationRequest {
  final String id;
  final String userId;
  final String eventId;
  final String status; // 'pending', 'approved', 'rejected'

  /// Momento dell'invio, in ora locale. Null se assente o illeggibile.
  final DateTime? createdAt;

  SupabaseParticipationRequest({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.status,
    this.createdAt,
  });

  SupabaseParticipationRequest copyWith({
    String? id,
    String? userId,
    String? eventId,
    String? status,
    DateTime? createdAt,
  }) {
    return SupabaseParticipationRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventId: eventId ?? this.eventId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Maps a row from the real `event_requests` table.
  factory SupabaseParticipationRequest.fromRow(Map<String, dynamic> row) {
    return SupabaseParticipationRequest(
      id: row['id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      eventId: row['event_id']?.toString() ?? '',
      status: row['status']?.toString() ?? 'pending',
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal(),
    );
  }
}

class ProfilePhoto {
  /// Path nel bucket `profile_photos` (es. "<uid>/<timestamp>_<file>").
  final String path;

  /// Signed URL temporanea per la visualizzazione (bucket privato).
  final String url;

  ProfilePhoto({required this.path, required this.url});
}

class ChatMessage {
  final String id;
  final String eventId;
  final String senderId;
  final String content;
  final DateTime? createdAt;

  ChatMessage({
    required this.id,
    required this.eventId,
    required this.senderId,
    required this.content,
    this.createdAt,
  });

  /// Maps a row from the real `messages` table.
  factory ChatMessage.fromRow(Map<String, dynamic> row) {
    return ChatMessage(
      id: row['id']?.toString() ?? '',
      eventId: row['event_id']?.toString() ?? '',
      senderId: row['sender_id']?.toString() ?? '',
      content: row['content']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal(),
    );
  }
}

class NotificationItem {
  final String id;
  final String eventId;
  final String eventTitle;
  final String status; // 'approved', 'rejected'
  final String timestamp;
  final bool read;

  NotificationItem({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.status,
    required this.timestamp,
    this.read = false,
  });
}

/// Presenze e assenze di un ospite su tutti i locali (Blocco B.2c), da
/// `get_guest_reliability()` della migrazione 0015.
class GuestReliability {
  final int attended;
  final int noShows;

  const GuestReliability({required this.attended, required this.noShows});

  /// Nessuna serata con presenza segnata: niente da dire, né bene né male.
  bool get hasHistory => attended + noShows > 0;

  factory GuestReliability.fromRow(Map<String, dynamic> row) {
    return GuestReliability(
      attended: (row['attended'] as num?)?.toInt() ?? 0,
      noShows: (row['no_shows'] as num?)?.toInt() ?? 0,
    );
  }
}
