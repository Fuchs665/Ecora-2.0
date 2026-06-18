package com.example.data

import android.os.Build
import androidx.compose.runtime.mutableStateListOf
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

// --- SUPABASE DATABASE MODELS ---

data class SupabaseProfile(
    val id: String,
    val fullName: String,
    val role: String, // 'cliente' or 'gestore'
    val age: Int,
    val gender: String, // 'Uomo', 'Donna', 'Coppia'
    val noShows: Int = 0,
    val participationsCount: Int = 0
)

data class SupabaseEvent(
    val id: String,
    val title: String,
    val description: String,
    val organizerId: String,
    val latitude: Double,
    val longitude: Double,
    val imageUrl: String,
    val eventDate: String, // timestamp as elegant ISO string
    val maxParticipants: Int,
    val currentApprovedCount: Int = 0,
    val locationName: String = "Secret Florence Villa"
) {
    // Percentage completion of tables (near filling pushes urgency)
    val tableCompletionPercentage: Float
        get() = if (maxParticipants > 0) (currentApprovedCount.toFloat() / maxParticipants.toFloat()) else 0f
}

data class SupabaseParticipationRequest(
    val id: String,
    val userId: String,
    val eventId: String,
    val status: String // 'pending', 'approved', 'rejected'
)

// --- REACTIVE EXPERT SUPABASE SIMULATOR (Service Object) ---

object SupabaseClient {

    // Current Logged-in Profile
    private val _currentProfile = MutableStateFlow<SupabaseProfile?>(null)
    val currentProfile: StateFlow<SupabaseProfile?> = _currentProfile.asStateFlow()

    // Database Tables represented as Reactive State Flows
    private val _profiles = MutableStateFlow<List<SupabaseProfile>>(emptyList())
    private val _events = MutableStateFlow<List<SupabaseEvent>>(emptyList())
    val events: StateFlow<List<SupabaseEvent>> = _events.asStateFlow()

    private val _requests = MutableStateFlow<List<SupabaseParticipationRequest>>(emptyList())
    val requests: StateFlow<List<SupabaseParticipationRequest>> = _requests.asStateFlow()

    // Notification Badge resets on Tab 2 click
    val notificationBadgeCount = MutableStateFlow(0)
    
    // Notifications list with swipe-to-delete support
    private val _notifications = MutableStateFlow<List<NotificationItem>>(emptyList())
    val notifications: StateFlow<List<NotificationItem>> = _notifications.asStateFlow()

    data class NotificationItem(
        val id: String,
        val eventId: String,
        val eventTitle: String,
        val status: String, // 'approved', 'rejected'
        val timestamp: String,
        val read: Boolean = false
    )

    init {
        // Initialize Premium Mock Database
        seedDatabase()
    }

    private fun seedDatabase() {
        val clienteUser = SupabaseProfile(
            id = "user-cliente-123",
            fullName = "Alex & Sofia",
            role = "cliente",
            age = 32,
            gender = "Coppia",
            noShows = 0,
            participationsCount = 8
        )

        val hostUser = SupabaseProfile(
            id = "user-gestore-456",
            fullName = "Villa Secret Club",
            role = "gestore",
            age = 40,
            gender = "Donna",
            noShows = 0,
            participationsCount = 45
        )

        val seededProfiles = listOf(
            clienteUser,
            hostUser,
            SupabaseProfile("user-test-789", "Marcus & Ellen", "cliente", 29, "Coppia", 0, 3),
            SupabaseProfile("user-test-101", "Isabella", "cliente", 27, "Donna", 1, 12),
            SupabaseProfile("user-test-102", "Valerio", "cliente", 34, "Uomo", 2, 4)
        )

        // Florence default center coords
        val florenceLat = 43.7695
        val florenceLng = 11.2558

        val seededEvents = listOf(
            SupabaseEvent(
                id = "event-1",
                title = "Golden Velvet Soiree",
                description = "An ultra-exclusive champagne reception inside Florence's most beautiful private terrace. Designed for open-minded couples looking for meaningful conversations in absolute secrecy. Smart formal attire required.",
                organizerId = hostUser.id,
                latitude = florenceLat + 0.008,
                longitude = florenceLng + 0.006,
                imageUrl = "https://images.unsplash.com/photo-1541252260730-0412e8e2108e?auto=format&fit=crop&q=80&w=600",
                eventDate = "2026-06-25T21:00:00",
                maxParticipants = 10,
                currentApprovedCount = 8,
                locationName = "Private Luxury Villa, Florence Hills"
            ),
            SupabaseEvent(
                id = "event-2",
                title = "Midsummer Amber Eyes",
                description = "Discreet masquerade cocktail party. Strictly limited to 6 couples. Perfect visual atmosphere with glowing amber candles, private lounge, and soft ambient sounds.",
                organizerId = hostUser.id,
                latitude = florenceLat - 0.004,
                longitude = florenceLng - 0.003,
                imageUrl = "https://images.unsplash.com/photo-1517457373958-b7bdd4587205?auto=format&fit=crop&q=80&w=600",
                eventDate = "2026-06-28T22:30:00",
                maxParticipants = 6,
                currentApprovedCount = 5, // 5 out of 6 -> Extremely near finish! Push table completion urgency!
                locationName = "Secluded Velvet Room, Florence South"
            ),
            SupabaseEvent(
                id = "event-3",
                title = "Shadow Tapestry Meet",
                description = "Discreet after-party gather for international luxury travelers. Pre-screening mandatory. Perfect security, dark elegant cocktail room, premium gold acoustics.",
                organizerId = hostUser.id,
                latitude = florenceLat + 0.015,
                longitude = florenceLng - 0.012,
                imageUrl = "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&q=80&w=600",
                eventDate = "2026-07-02T23:00:00",
                maxParticipants = 12,
                currentApprovedCount = 4,
                locationName = "Secret Palace, Florence Airport Area"
            )
        )

        val seededRequests = listOf(
            SupabaseParticipationRequest("req-1", "user-test-789", "event-1", "pending"),
            SupabaseParticipationRequest("req-2", "user-test-101", "event-1", "pending"),
            SupabaseParticipationRequest("req-3", "user-test-102", "event-2", "pending")
        )

        _profiles.value = seededProfiles
        _events.value = seededEvents
        _requests.value = seededRequests

        // Set default profile logging in as Alex & Sofia (Cliente)
        _currentProfile.value = clienteUser
    }

    // --- SUPABASE SERVICES SIMULATION ---

    /**
     * Auth Role Gate Router (Query profiles table for user role).
     */
    fun login(email: String, selectRole: String) {
        // Query the profile associated with user's selection to simulate the gate router
        val profile = _profiles.value.find { it.role == selectRole } 
            ?: SupabaseProfile(
                id = UUID.randomUUID().toString(),
                fullName = if (selectRole == "cliente") "Claudio & Maya" else "Noble Club Firenze",
                role = selectRole,
                age = 35,
                gender = if (selectRole == "cliente") "Coppia" else "Donna",
                noShows = 0,
                participationsCount = if (selectRole == "cliente") 2 else 12
            )
        
        // Save back into profiles simulation
        if (!_profiles.value.any { it.id == profile.id }) {
            _profiles.value = _profiles.value + profile
        }
        _currentProfile.value = profile
    }

    fun logout() {
        _currentProfile.value = null
    }

    /**
     * RPC function simulation: get_events_within_radius(user_lat, user_lon, max_distance_km)
     * Matches events tables using the official Haversine formula calculation.
     */
    fun getEventsWithinRadius(userLat: Double, userLon: Double, maxDistanceKm: Double): List<SupabaseEvent> {
        return _events.value.filter { event ->
            val dist = calculateHaversineDistance(userLat, userLon, event.latitude, event.longitude)
            dist <= maxDistanceKm
        }
    }

    /**
     * Fallback standard database query if radius filter is omitted or location is forbidden.
     * Supabase equivalent: supabase.from('events').select()
     */
    fun fetchEventsNormal(): List<SupabaseEvent> {
        return _events.value
    }

    /**
     * Haversine formula to strictly compute distance between spheres
     */
    fun calculateHaversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val r = 6371.0 // Earth's radius in kilometers
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                Math.sin(dLon / 2) * Math.sin(dLon / 2)
        val c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        return r * c
    }

    /**
     * Submit Participation Invitation Request (guest taps Join)
     * Equivalent to: supabase.from('participation_requests').insert(...)
     */
    fun submitParticipationRequest(eventId: String, userId: String) {
        // Prevent duplicate requests
        val exists = _requests.value.any { it.userId == userId && it.eventId == eventId }
        if (!exists) {
            val newRequest = SupabaseParticipationRequest(
                id = UUID.randomUUID().toString(),
                userId = userId,
                eventId = eventId,
                status = "pending"
            )
            _requests.value = _requests.value + newRequest
        }
    }

    /**
     * Host Approve or Reject Invitation Request with instant status visual update.
     * Equivalent to: supabase.from('participation_requests').update().eq().select()
     */
    fun reviewParticipationRequest(requestId: String, setStatus: String) {
        _requests.value = _requests.value.map { req ->
            if (req.id == requestId) {
                // Update request
                val updated = req.copy(status = setStatus)
                
                // If approved, update approved participants count in events
                if (setStatus == "approved") {
                    updateEventApprovedCount(req.eventId, 1)
                }

                // Add real-time notification simulation for the recipient guest
                val eventObj = _events.value.find { it.id == req.eventId }
                if (eventObj != null) {
                    val formattedTime = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        LocalDateTime.now().format(DateTimeFormatter.ofPattern("HH:mm"))
                    } else {
                        "Just Now"
                    }
                    val notif = NotificationItem(
                        id = UUID.randomUUID().toString(),
                        eventId = req.eventId,
                        eventTitle = eventObj.title,
                        status = setStatus,
                        timestamp = formattedTime
                    )
                    _notifications.value = listOf(notif) + _notifications.value
                    notificationBadgeCount.value += 1
                }

                updated
            } else {
                req
            }
        }
    }

    private fun updateEventApprovedCount(eventId: String, increment: Int) {
        _events.value = _events.value.map { ev ->
            if (ev.id == eventId) {
                ev.copy(currentApprovedCount = (ev.currentApprovedCount + increment).coerceAtMost(ev.maxParticipants))
            } else {
                ev
            }
        }
    }

    /**
     * Mock delete notification
     */
    fun deleteNotification(notificationId: String) {
        _notifications.value = _notifications.value.filter { it.id != notificationId }
    }

    /**
     * Clear notification counts when Tab 2 (Notifications) is active
     */
    fun resetNotificationBadge() {
        notificationBadgeCount.value = 0
    }

    /**
     * Host / Gestore creates a premium meeting event.
     * Simulates image_picker upload to supabase event_images storage bucket, gets image URL,
     * and compiles the event model record inside Supabase events table.
     */
    fun insertEventAndUploadImage(
        title: String,
        description: String,
        organizerId: String,
        latitude: Double,
        longitude: Double,
        mockImagePath: String?, // acts as Supabase Storage Bucket Key / URL
        maxParticipants: Int,
        locationName: String
    ) {
        val mockUploadedUrl = if (!mockImagePath.isNullOrBlank()) {
            // Equivalent to calling Storage bucket url resolver:
            // supabase.storage.from('event_images').getPublicUrl(mockImagePath)
            mockImagePath
        } else {
            // Seed a luxury premium visual fallback
            "https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?auto=format&fit=crop&q=80&w=600"
        }

        val freshEvent = SupabaseEvent(
            id = UUID.randomUUID().toString(),
            title = title,
            description = description,
            organizerId = organizerId,
            latitude = latitude,
            longitude = longitude,
            imageUrl = mockUploadedUrl,
            eventDate = "2026-06-30T22:00:00",
            maxParticipants = maxParticipants,
            currentApprovedCount = 1, // Created by host is 1 participant
            locationName = locationName
        )

        _events.value = listOf(freshEvent) + _events.value
    }

    /**
     * Host or guest statistics queries from Profiles table records
     */
    fun getProfileById(userId: String): SupabaseProfile? {
        return _profiles.value.find { it.id == userId }
    }
}
