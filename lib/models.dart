

/// Colonne leggibili di `profiles`. Dal Block 6.2 (migration 0012) i grant
/// SELECT sono per colonna e `select=*` fallisce con permission denied:
/// ogni lettura del client DEVE enumerare le colonne. I timestamp di
/// consenso (age_confirmed_at/terms_accepted_at) sono esclusi di proposito.
const String kProfileSelectColumns =
    'id, role, nickname, avatar_url, generic_location, is_verified, '
    'created_at, profile_type, privacy_level';

class SupabaseProfile {
  final String id;
  final String fullName;
  final String role; // 'cliente' or 'gestore'
  final int age;
  final String gender; // 'Uomo', 'Donna', 'Coppia'
  final int noShows;
  final int participationsCount;
  final String? profileType;
  final String? privacyLevel;
  final String? genericLocation;

  SupabaseProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.age,
    required this.gender,
    this.noShows = 0,
    this.participationsCount = 0,
    this.profileType,
    this.privacyLevel,
    this.genericLocation,
  });

  SupabaseProfile copyWith({
    String? id,
    String? fullName,
    String? role,
    int? age,
    String? gender,
    int? noShows,
    int? participationsCount,
    String? profileType,
    String? privacyLevel,
    String? genericLocation,
  }) {
    return SupabaseProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      noShows: noShows ?? this.noShows,
      participationsCount: participationsCount ?? this.participationsCount,
      profileType: profileType ?? this.profileType,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      genericLocation: genericLocation ?? this.genericLocation,
    );
  }

  /// Maps a row from the real `profiles` table.
  /// age/gender are not stored in the DB yet: gender is derived from
  /// profile_type, age uses a neutral placeholder.
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
      age: 30,
      gender: gender,
      profileType: profileType,
      privacyLevel: row['privacy_level']?.toString(),
      genericLocation: row['generic_location']?.toString(),
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
      imageUrl: json['image_url']?.toString() ??
          "https://images.unsplash.com/photo-1541252260730-0412e8e2108e?auto=format&fit=crop&q=80&w=600",
      eventDate:
          json['event_date']?.toString() ?? DateTime.now().toIso8601String(),
      maxParticipants: (json['max_guests'] as num?)?.toInt() ?? 0,
      currentApprovedCount: (json['approved_count'] as num?)?.toInt() ?? 0,
      locationName: json['location_name']?.toString() ?? 'Località riservata',
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
    );
  }
}

class SupabaseParticipationRequest {
  final String id;
  final String userId;
  final String eventId;
  final String status; // 'pending', 'approved', 'rejected'

  SupabaseParticipationRequest({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.status,
  });

  SupabaseParticipationRequest copyWith({
    String? id,
    String? userId,
    String? eventId,
    String? status,
  }) {
    return SupabaseParticipationRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventId: eventId ?? this.eventId,
      status: status ?? this.status,
    );
  }

  /// Maps a row from the real `event_requests` table.
  factory SupabaseParticipationRequest.fromRow(Map<String, dynamic> row) {
    return SupabaseParticipationRequest(
      id: row['id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      eventId: row['event_id']?.toString() ?? '',
      status: row['status']?.toString() ?? 'pending',
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
