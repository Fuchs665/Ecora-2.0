package com.example.ui.screens

import androidx.compose.animation.*
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.example.data.SupabaseEvent
import com.example.data.SupabaseClient
import com.example.data.SupabaseParticipationRequest
import com.example.ui.theme.MatteDark
import com.example.ui.theme.PremiumGold
import com.example.ui.theme.SlateSurface
import com.example.ui.theme.TextPrimary
import com.example.ui.theme.TextSecondary

@OptIn(ExperimentalAnimationApi::class)
@Composable
fun ClientNavigationHub(
    onSelectEvent: (SupabaseEvent) -> Unit,
    onLogout: () -> Unit
) {
    var selectedTab by remember { mutableStateOf(0) } // 0 = Home, 1 = Notifications, 2 = Messages, 3 = Profile

    val currentProfile by SupabaseClient.currentProfile.collectAsState()
    val events by SupabaseClient.events.collectAsState()
    val requests by SupabaseClient.requests.collectAsState()
    val notifications by SupabaseClient.notifications.collectAsState()
    val badgeCount by SupabaseClient.notificationBadgeCount.collectAsState()

    val profile = currentProfile ?: return

    // Trigger notification badge reset when opening notifications tab
    LaunchedEffect(selectedTab) {
        if (selectedTab == 1) {
            SupabaseClient.resetNotificationBadge()
        }
    }

    Scaffold(
        bottomBar = {
            NavigationBar(
                containerColor = SlateSurface,
                tonalElevation = 8.dp,
                modifier = Modifier.navigationBarsPadding()
            ) {
                // Tab 1: Home (Discover)
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = {
                        Icon(
                            imageVector = if (selectedTab == 0) Icons.Filled.Explore else Icons.Outlined.Explore,
                            contentDescription = "Discover"
                        )
                    },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = PremiumGold,
                        unselectedIconColor = TextSecondary,
                        indicatorColor = Color.Transparent
                    ),
                    alwaysShowLabel = false
                )

                // Tab 2: Notifications
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = {
                        BadgedBox(
                            badge = {
                                if (badgeCount > 0) {
                                    Badge(
                                        containerColor = PremiumGold,
                                        contentColor = MatteDark
                                    ) {
                                        Text("$badgeCount", fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        ) {
                            Icon(
                                imageVector = if (selectedTab == 1) Icons.Filled.Notifications else Icons.Outlined.Notifications,
                                contentDescription = "Alerts"
                            )
                        }
                    },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = PremiumGold,
                        unselectedIconColor = TextSecondary,
                        indicatorColor = Color.Transparent
                    ),
                    alwaysShowLabel = false
                )

                // Tab 3: Messages
                NavigationBarItem(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    icon = {
                        Icon(
                            imageVector = if (selectedTab == 2) Icons.Filled.Forum else Icons.Outlined.Forum,
                            contentDescription = "Chats"
                        )
                    },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = PremiumGold,
                        unselectedIconColor = TextSecondary,
                        indicatorColor = Color.Transparent
                    ),
                    alwaysShowLabel = false
                )

                // Tab 4: Profile
                NavigationBarItem(
                    selected = selectedTab == 3,
                    onClick = { selectedTab = 3 },
                    icon = {
                        Icon(
                            imageVector = if (selectedTab == 3) Icons.Filled.Person else Icons.Outlined.Person,
                            contentDescription = "Profile"
                        )
                    },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = PremiumGold,
                        unselectedIconColor = TextSecondary,
                        indicatorColor = Color.Transparent
                    ),
                    alwaysShowLabel = false
                )
            }
        },
        containerColor = MatteDark
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            AnimatedContent(
                targetState = selectedTab,
                transitionSpec = {
                    fadeIn(animationSpec = tween(220)) with fadeOut(animationSpec = tween(220))
                },
                label = "hub_content"
            ) { targetTab ->
                when (targetTab) {
                    0 -> DiscoverScreen(
                        events = events,
                        requests = requests,
                        userId = profile.id,
                        onSelectEvent = onSelectEvent
                    )
                    1 -> NotificationsScreen(
                        notifications = notifications,
                        onDeleteNotification = { SupabaseClient.deleteNotification(it) }
                    )
                    2 -> MessagesScreen()
                    3 -> UserProfilePage(
                        profile = profile,
                        onLogout = onLogout
                    )
                }
            }
        }
    }
}

// --- TAB 1: DISCOVER SCREEN ---

@Composable
fun DiscoverScreen(
    events: List<SupabaseEvent>,
    requests: List<SupabaseParticipationRequest>,
    userId: String,
    onSelectEvent: (SupabaseEvent) -> Unit
) {
    var isMapView by remember { mutableStateOf(false) }
    var radiusKm by remember { mutableStateOf(15f) } // Radius slider default
    var isRadiusActive by remember { mutableStateOf(false) }

    // Location permission/status simulation: fallback mock GPS
    // If device GPS returns null, fallback smoothly to Florence, Italy (43.7695, 11.2558)
    val fallbackLat = 43.7695
    val fallbackLng = 11.2558

    // Read and filter reactive list based on search radius
    val filteredAndSortedEvents = remember(events, radiusKm, isRadiusActive) {
        val eligible = if (isRadiusActive) {
            // Apply radius filter RPC simulation
            SupabaseClient.getEventsWithinRadius(fallbackLat, fallbackLng, radiusKm.toDouble())
        } else {
            // Revert to stable supabase fetch normal
            SupabaseClient.fetchEventsNormal()
        }

        // Urgency sorting: Sort strictly by Table Completion (descending: events close to filling up first)
        eligible.sortedByDescending { it.tableCompletionPercentage }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        // --- PREMIUM ELEGANT DARK HEADER SECTION ---
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(SlateSurface)
                .border(BorderStroke(1.dp, Color.White.copy(alpha = 0.05f)))
                .statusBarsPadding()
                .padding(horizontal = 20.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Shield,
                    contentDescription = "Shield",
                    tint = PremiumGold,
                    modifier = Modifier.size(24.dp)
                )
                Text(
                    text = "ECORA",
                    style = TextStyle(
                        fontFamily = FontFamily.Serif,
                        fontWeight = FontWeight.Bold,
                        fontSize = 19.sp,
                        letterSpacing = 4.sp,
                        color = PremiumGold
                    )
                )
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Box(modifier = Modifier.size(24.dp)) {
                    Icon(
                        imageVector = Icons.Default.Notifications,
                        contentDescription = "Notifications",
                        tint = TextSecondary,
                        modifier = Modifier.size(24.dp)
                    )
                    Box(
                        modifier = Modifier
                            .size(7.dp)
                            .background(PremiumGold, CircleShape)
                            .border(1.5.dp, SlateSurface, CircleShape)
                            .align(Alignment.TopEnd)
                    )
                }
                
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(PremiumGold.copy(alpha = 0.1f))
                        .border(1.dp, PremiumGold.copy(alpha = 0.5f), CircleShape)
                ) {
                    Icon(
                        imageVector = Icons.Default.Person,
                        contentDescription = "Avatar placeholder",
                        tint = PremiumGold,
                        modifier = Modifier.size(20.dp).align(Alignment.Center)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // --- SUB-HEADER: TRENDING TABLES & VIEW SWITCHER ---
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = "Trending Tables",
                style = TextStyle(
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.2.sp,
                    color = TextSecondary
                )
            )

            Row(
                modifier = Modifier
                    .background(SlateSurface, RoundedCornerShape(24.dp))
                    .border(BorderStroke(1.dp, Color.White.copy(alpha = 0.05f)), RoundedCornerShape(24.dp))
                    .padding(2.dp)
            ) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(if (!isMapView) PremiumGold else Color.Transparent)
                        .clickable { isMapView = false }
                        .padding(horizontal = 14.dp, vertical = 6.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "List",
                        style = TextStyle(
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (!isMapView) MatteDark else TextSecondary
                        )
                    )
                }

                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(if (isMapView) PremiumGold else Color.Transparent)
                        .clickable { isMapView = true }
                        .padding(horizontal = 14.dp, vertical = 6.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "Map",
                        style = TextStyle(
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (isMapView) MatteDark else TextSecondary
                        )
                    )
                }
            }
        }

        // --- DISTANCE FILTER SLIDER ---
        Card(
            colors = CardDefaults.cardColors(containerColor = SlateSurface),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 12.dp)
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(
                            checked = isRadiusActive,
                            onCheckedChange = { isRadiusActive = it },
                            colors = CheckboxDefaults.colors(checkedColor = PremiumGold, checkmarkColor = MatteDark)
                        )
                        Text(
                            text = "Filter by Location",
                            style = TextStyle(fontSize = 13.sp, color = TextPrimary, fontWeight = FontWeight.Bold)
                        )
                    }
                    if (isRadiusActive) {
                        Text(
                            text = "${radiusKm.toInt()} km",
                            style = TextStyle(color = PremiumGold, fontWeight = FontWeight.Bold, fontSize = 13.sp)
                        )
                    } else {
                        Text(
                            text = "Florence (All)",
                            style = TextStyle(color = TextSecondary, fontSize = 12.sp)
                        )
                    }
                }

                if (isRadiusActive) {
                    Slider(
                        value = radiusKm,
                        onValueChange = { radiusKm = it },
                        valueRange = 1f..50f,
                        colors = SliderDefaults.colors(
                            thumbColor = PremiumGold,
                            activeTrackColor = PremiumGold,
                            inactiveTrackColor = Color(0xFF424242)
                        ),
                        modifier = Modifier.padding(horizontal = 4.dp)
                    )
                }
            }
        }

        // --- MAIN DISCOVER VIEW SWITCHER ---
        if (filteredAndSortedEvents.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        imageVector = Icons.Default.CloudQueue,
                        contentDescription = "No events",
                        tint = TextSecondary,
                        modifier = Modifier.size(48.dp)
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = "No discreet events within radius",
                        color = TextSecondary,
                        fontSize = 14.sp
                    )
                }
            }
        } else if (!isMapView) {
            // --- FEED LIST (URGENCY ORDER) ---
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                item {
                    // --- UNIQUE PRIVACY NOTE BANNER ---
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(PremiumGold.copy(alpha = 0.05f), RoundedCornerShape(16.dp))
                            .border(BorderStroke(1.dp, PremiumGold.copy(alpha = 0.15f)), RoundedCornerShape(16.dp))
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.Top
                    ) {
                        Icon(
                            imageVector = Icons.Default.PrivacyTip,
                            contentDescription = "Privacy tip",
                            tint = PremiumGold,
                            modifier = Modifier.size(20.dp)
                        )
                        Column {
                            Text(
                                text = "PRECISE PRIVACY LOCK",
                                style = TextStyle(
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Bold,
                                    letterSpacing = 1.sp,
                                    color = PremiumGold
                                )
                            )
                            Spacer(modifier = Modifier.height(3.dp))
                            Text(
                                text = "Precise GPS and host details are locked until your profile is approved by the event organizer. Ecora prioritizes your anonymity.",
                                style = TextStyle(
                                    fontSize = 11.sp,
                                    color = TextSecondary,
                                    lineHeight = 15.sp
                                )
                            )
                        }
                    }
                }

                items(filteredAndSortedEvents) { event ->
                    EventFeedCard(
                        event = event,
                        requests = requests,
                        userId = userId,
                        onClick = { onSelectEvent(event) }
                    )
                }
            }
        } else {
            // --- MAP VIEW (STRICT MONOCHROME DARK STYLE) ---
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .background(Color(0xFF0F0F0F))
            ) {
                var selectedPointEvent by remember { mutableStateOf<SupabaseEvent?>(null) }

                // Dynamic vector canvas representation of Streets and Arno River map of Florence
                Canvas(
                    modifier = Modifier
                        .fillMaxSize()
                        .pointerInput(filteredAndSortedEvents) {
                            detectTapGestures { offset ->
                                // Tap detection: find nearest point within 40dp radius
                                var found: SupabaseEvent? = null
                                var minDistance = 2000f
                                filteredAndSortedEvents.forEachIndexed { idx, ev ->
                                    val screenPoint = mapCoordsToScreen(ev.latitude, ev.longitude, fallbackLat, fallbackLng, size.width.toFloat(), size.height.toFloat())
                                    val dist = (offset - screenPoint).getDistance()
                                    if (dist < 40f && dist < minDistance) {
                                        minDistance = dist
                                        found = ev
                                    }
                                }
                                selectedPointEvent = found
                            }
                        }
                ) {
                    val width = size.width
                    val height = size.height

                    // 1. Draw River Arno (Blue-grey matte river line cutting through Florence)
                    val riverPath = android.graphics.Path().apply {
                        moveTo(0f, height * 0.45f)
                        cubicTo(width * 0.3f, height * 0.42f, width * 0.7f, height * 0.52f, width, height * 0.48f)
                    }
                    drawContext.canvas.nativeCanvas.drawPath(
                        riverPath,
                        android.graphics.Paint().apply {
                            color = android.graphics.Color.parseColor("#1A2B2D")
                            strokeWidth = 36f
                            style = android.graphics.Paint.Style.STROKE
                            isAntiAlias = true
                        }
                    )

                    // 2. Draw CartoDB-style high density grid lines (street wireframe)
                    val gridPaint = android.graphics.Paint().apply {
                        color = android.graphics.Color.parseColor("#222222")
                        strokeWidth = 3f
                        style = android.graphics.Paint.Style.STROKE
                        isAntiAlias = true
                    }
                    // Radial rings representing distance bounds
                    for (radiusRing in 1..4) {
                        drawCircle(
                            color = Color(0xFF1E1E1E),
                            radius = (width * 0.15f * radiusRing),
                            center = Offset(width / 2, height / 2),
                            style = Stroke(width = 2f)
                        )
                    }

                    // Florence Streets wireframe paths
                    drawLine(Color(0xFF222222), Offset(0f, height * 0.2f), Offset(width, height * 0.35f), strokeWidth = 3f)
                    drawLine(Color(0xFF222222), Offset(0f, height * 0.75f), Offset(width, height * 0.65f), strokeWidth = 3f)
                    drawLine(Color(0xFF222222), Offset(width * 0.25f, 0f), Offset(width * 0.35f, height), strokeWidth = 3f)
                    drawLine(Color(0xFF222222), Offset(width * 0.75f, 0f), Offset(width * 0.60f, height), strokeWidth = 3f)

                    // 3. Draw Event Pin Targets (glowing gold rings for unrevealed, emerald core for approved)
                    filteredAndSortedEvents.forEach { ev ->
                        val screenPt = mapCoordsToScreen(ev.latitude, ev.longitude, fallbackLat, fallbackLng, width, height)
                        val userReq = requests.find { it.userId == userId && it.eventId == ev.id }
                        val isApproved = userReq?.status == "approved"

                        // Pulse gold halo glow
                        drawCircle(
                            color = if (isApproved) Color(0x334CAF50) else PremiumGold.copy(alpha = 0.25f),
                            radius = 28f,
                            center = screenPt
                        )

                        // Core point
                        drawCircle(
                            color = if (isApproved) Color(0xFF4CAF50) else PremiumGold,
                            radius = 12f,
                            center = screenPt
                        )

                        // Fine ring border
                        drawCircle(
                            color = Color.White,
                            radius = 12f,
                            center = screenPt,
                            style = Stroke(width = 2f)
                        )
                    }
                }

                // Instructions Overlay
                Box(
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(12.dp)
                        .background(Color(0xCC1A1A1A), RoundedCornerShape(20.dp))
                        .padding(horizontal = 14.dp, vertical = 6.dp)
                ) {
                    Text(
                        text = "CartoDB Dark Mod Map — Tap glowing nodes for details",
                        color = TextSecondary,
                        fontSize = 11.sp
                    )
                }

                // Dynamic detail drawer if tapping point
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .padding(16.dp)
                ) {
                    androidx.compose.animation.AnimatedVisibility(
                        visible = selectedPointEvent != null,
                        enter = slideInVertically(initialOffsetY = { it / 2 }) + fadeIn(),
                        exit = slideOutVertically(targetOffsetY = { it / 2 }) + fadeOut()
                    ) {
                        selectedPointEvent?.let { ev ->
                        val hasApplied = requests.any { it.userId == userId && it.eventId == ev.id }

                        Card(
                            colors = CardDefaults.cardColors(containerColor = SlateSurface),
                            border = BorderStroke(1.dp, PremiumGold.copy(alpha = 0.5f)),
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onSelectEvent(ev) }
                        ) {
                            Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                                AsyncImage(
                                    model = ev.imageUrl,
                                    contentDescription = ev.title,
                                    modifier = Modifier
                                        .size(64.dp)
                                        .clip(RoundedCornerShape(8.dp)),
                                    contentScale = ContentScale.Crop
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = ev.title,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 15.sp,
                                        color = TextPrimary
                                    )
                                    Text(
                                        text = "Table ${(ev.tableCompletionPercentage * 100).toInt()}% Reserved",
                                        fontWeight = FontWeight.SemiBold,
                                        fontSize = 12.sp,
                                        color = PremiumGold
                                    )
                                    Text(
                                        text = if (hasApplied) "Request Active — Details pending" else "Florence South — Tap to request access",
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                        fontSize = 11.sp,
                                        color = TextSecondary
                                    )
                                }
                                Icon(
                                    imageVector = Icons.Default.ChevronRight,
                                    contentDescription = "Details",
                                    tint = PremiumGold
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
}

// Map Coordinate conversion to Screen Pixels helper
private fun mapCoordsToScreen(
    lat: Double, lng: Double,
    centerLat: Double, centerLng: Double,
    canvasWidth: Float, canvasHeight: Float
): Offset {
    val scale = 6000f // Scaling factor for Florence close bounds
    val x = canvasWidth / 2f + ((lng - centerLng) * scale * 0.70).toFloat()
    val y = canvasHeight / 2f - ((lat - centerLat) * scale).toFloat() // Flip coordinates for screen top
    return Offset(
        x = x.coerceIn(40f, canvasWidth - 40f),
        y = y.coerceIn(40f, canvasHeight - 40f)
    )
}

@Composable
fun EventFeedCard(
    event: SupabaseEvent,
    requests: List<SupabaseParticipationRequest>,
    userId: String,
    onClick: () -> Unit
) {
    val request = requests.find { it.userId == userId && it.eventId == event.id }
    val statusText = when (request?.status) {
        "pending" -> "PENDING ACCESS"
        "approved" -> "INVITATION APPROVED"
        "rejected" -> "ACCESS DENIED"
        else -> "REQUEST INVITATION"
    }
    val statusColor = when (request?.status) {
        "approved" -> Color(0xFF4CAF50)
        "pending" -> PremiumGold
        "rejected" -> Color(0xFFCF6679)
        else -> TextSecondary
    }

    Card(
        colors = CardDefaults.cardColors(containerColor = SlateSurface),
        shape = RoundedCornerShape(24.dp),
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.05f)),
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
    ) {
        Column {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp)
                    .clip(RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp))
            ) {
                AsyncImage(
                    model = event.imageUrl,
                    contentDescription = event.title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop
                )

                // Fog shading overlay
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(Color.Transparent, Color.Black.copy(alpha = 0.8f))
                            )
                        )
                )

                // TABLE COMPLETION URGENCY METER (Visual Progress Circle or Pill)
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(12.dp)
                        .background(PremiumGold, RoundedCornerShape(topStart = 4.dp, bottomStart = 12.dp, bottomEnd = 4.dp, topEnd = 12.dp))
                        .padding(horizontal = 10.dp, vertical = 5.dp)
                ) {
                    Text(
                        text = "URGENT: ${(event.tableCompletionPercentage * 100).toInt()}% FILLED",
                        style = TextStyle(
                            fontFamily = FontFamily.SansSerif,
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 9.sp,
                            color = MatteDark,
                            letterSpacing = 0.5.sp
                        )
                    )
                }

                // Status overlay
                Row(
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .padding(12.dp)
                        .background(Color(0xE61A1A1A), RoundedCornerShape(8.dp))
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(6.dp)
                            .background(statusColor, CircleShape)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = statusText,
                        style = TextStyle(fontWeight = FontWeight.Bold, fontSize = 10.sp, color = statusColor, letterSpacing = 1.sp)
                    )
                }
            }

            Column(modifier = Modifier.padding(18.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = event.title.uppercase(),
                        style = TextStyle(
                            fontFamily = FontFamily.SansSerif,
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 17.sp,
                            color = TextPrimary,
                            letterSpacing = 0.5.sp
                        ),
                        modifier = Modifier.weight(1f)
                    )
                    
                    // High Trust verified badge matching HTML layout
                    Row(
                        modifier = Modifier
                            .background(Color(0x22D4AF37), RoundedCornerShape(6.dp))
                            .border(BorderStroke(0.5.dp, PremiumGold.copy(alpha = 0.3f)), RoundedCornerShape(6.dp))
                            .padding(horizontal = 6.dp, vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.VerifiedUser,
                            contentDescription = "Verified Host",
                            tint = PremiumGold,
                            modifier = Modifier.size(10.dp)
                        )
                        Spacer(modifier = Modifier.width(3.dp))
                        Text(
                            text = "High Trust",
                            style = TextStyle(
                                fontSize = 8.sp,
                                fontWeight = FontWeight.Bold,
                                color = PremiumGold
                            )
                        )
                    }
                }

                Spacer(modifier = Modifier.height(4.dp))

                // Location on map representation: discreet and secure
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(bottom = 8.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = "Location lock status",
                        tint = PremiumGold,
                        modifier = Modifier.size(14.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = "South Hills District, Florence (Approved Only)",
                        style = TextStyle(
                            fontSize = 11.sp,
                            color = TextSecondary,
                            fontWeight = FontWeight.Normal
                        )
                    )
                }

                Text(
                    text = event.description,
                    style = TextStyle(fontSize = 12.sp, color = TextSecondary),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    lineHeight = 17.sp
                )

                Spacer(modifier = Modifier.height(14.dp))

                // Table progress line
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "${event.currentApprovedCount} of ${event.maxParticipants} couples confirmed",
                        style = TextStyle(fontSize = 11.sp, color = PremiumGold, fontWeight = FontWeight.SemiBold)
                    )
                    Text(
                        text = "${(event.tableCompletionPercentage * 100).toInt()}% spots taken",
                        style = TextStyle(fontSize = 10.sp, color = TextSecondary)
                    )
                }
                Spacer(modifier = Modifier.height(6.dp))
                LinearProgressIndicator(
                    progress = event.tableCompletionPercentage,
                    trackColor = Color(0xFF323232),
                    color = PremiumGold,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(4.dp)
                        .clip(CircleShape)
                )
            }
        }
    }
}

// --- TAB 2: NOTIFICATIONS SCREEN (SWIPE-TO-DELETE LOGIC) ---

@Composable
fun NotificationsScreen(
    notifications: List<SupabaseClient.NotificationItem>,
    onDeleteNotification: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MatteDark)
            .padding(16.dp)
    ) {
        Text(
            text = "NOTIFICATIONS",
            style = TextStyle(
                fontWeight = FontWeight.ExtraBold,
                fontSize = 16.sp,
                letterSpacing = 1.5.sp,
                color = PremiumGold
            ),
            modifier = Modifier.padding(bottom = 16.dp)
        )

        if (notifications.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        imageVector = Icons.Default.MailOutline,
                        contentDescription = "Inbox empty",
                        tint = TextSecondary,
                        modifier = Modifier.size(48.dp)
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = "Your private invitations feed is empty.",
                        style = TextStyle(fontSize = 13.sp, color = TextSecondary)
                    )
                }
            }
        } else {
            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.fillMaxSize()
            ) {
                items(notifications, key = { it.id }) { item ->
                    SwipeToDeleteNotificationRow(
                        item = item,
                        onDelete = { onDeleteNotification(item.id) }
                    )
                }
            }
        }
    }
}

@Composable
fun SwipeToDeleteNotificationRow(
    item: SupabaseClient.NotificationItem,
    onDelete: () -> Unit
) {
    var isRevealed by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
    ) {
        // Underlay Trash Delete Action revealed on swipe
        Row(
            modifier = Modifier
                .matchParentSize()
                .background(Color(0xFFC62828))
                .clickable { onDelete() }
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Delete,
                contentDescription = "Delete Item",
                tint = Color.White
            )
        }

        // Main Card Sliding Row (Toggling offset state as simplified, perfectly robust Swipe-to-Delete)
        Card(
            colors = CardDefaults.cardColors(containerColor = SlateSurface),
            modifier = Modifier
                .fillMaxWidth()
                .offset(x = if (isRevealed) (-70).dp else 0.dp)
                .clickable { isRevealed = !isRevealed }
        ) {
            Row(
                modifier = Modifier.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .background(
                            if (item.status == "approved") Color(0x334CAF50) else Color(0x33C62828),
                            CircleShape
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = if (item.status == "approved") Icons.Default.CheckCircle else Icons.Default.Cancel,
                        contentDescription = item.status,
                        tint = if (item.status == "approved") Color(0xFF4CAF50) else Color(0xFFEF5350)
                    )
                }

                Spacer(modifier = Modifier.width(12.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (item.status == "approved") "Invitation Cleared" else "Request Refused",
                        style = TextStyle(fontWeight = FontWeight.Bold, fontSize = 13.sp, color = TextPrimary)
                    )
                    Text(
                        text = if (item.status == "approved") {
                            "Status approved for ${item.eventTitle}. Live GPS Coordinates unlocked."
                        } else {
                            "Your application for ${item.eventTitle} was discreetly returned."
                        },
                        style = TextStyle(fontSize = 12.sp, color = TextSecondary, lineHeight = 16.sp)
                    )
                    Text(
                        text = item.timestamp,
                        style = TextStyle(fontSize = 10.sp, color = PremiumGold),
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }

                IconButton(onClick = { isRevealed = !isRevealed }) {
                    Icon(
                        imageVector = if (isRevealed) Icons.Default.ArrowForwardIos else Icons.Default.ArrowBackIos,
                        contentDescription = "Reveal Delete Action",
                        tint = TextSecondary,
                        modifier = Modifier.size(14.dp)
                    )
                }
            }
        }
    }
}

// --- TAB 3: MESSAGES SCREEN (PLACEHOLDER CHAT) ---

@Composable
fun MessagesScreen() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MatteDark)
            .padding(16.dp)
    ) {
        Text(
            text = "PRIVATE CHAT LOUNGES",
            style = TextStyle(
                fontWeight = FontWeight.ExtraBold,
                fontSize = 16.sp,
                letterSpacing = 1.5.sp,
                color = PremiumGold
            ),
            modifier = Modifier.padding(bottom = 16.dp)
        )

        Card(
            colors = CardDefaults.cardColors(containerColor = SlateSurface),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = Icons.Default.Forum,
                    contentDescription = "Lounges Locked",
                    tint = PremiumGold,
                    modifier = Modifier.size(48.dp)
                )
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "Discreet Conversations",
                    style = TextStyle(fontWeight = FontWeight.Bold, fontSize = 16.sp, color = TextPrimary)
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Chat circles lock automatically in 'Tablo' custom privacy loops. You can communicate with other couples strictly after both invitations to a shared table are approved by the host.",
                    style = TextStyle(fontSize = 12.sp, color = TextSecondary, lineHeight = 18.sp),
                    textAlign = TextAlign.Center
                )
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        Text(
            text = "ACTIVE CHAT LOOPS (0)",
            style = TextStyle(fontSize = 12.sp, color = TextSecondary, letterSpacing = 1.sp)
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Simulated chat lock card
        Card(
            colors = CardDefaults.cardColors(containerColor = SlateSurface.copy(alpha = 0.5f)),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .background(Color(0xFF333333), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(imageVector = Icons.Default.Lock, contentDescription = "Locked", tint = TextSecondary, modifier = Modifier.size(16.dp))
                }
                Spacer(modifier = Modifier.width(16.dp))
                Column {
                    Text("Noble Villa Gathering Group", fontWeight = FontWeight.Bold, color = TextSecondary, fontSize = 14.sp)
                    Text("Chat locked until table acceptance", color = Color(0x80FFA0A0), fontSize = 11.sp)
                }
            }
        }
    }
}
